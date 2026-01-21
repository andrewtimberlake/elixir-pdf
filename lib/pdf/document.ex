defmodule Pdf.Document do
  @moduledoc false
  defstruct objects: nil,
            info: nil,
            fonts: nil,
            current_page: nil,
            pages: [],
            opts: [],
            action: nil,
            images: %{}

  import Pdf.Utils

  alias Pdf.{
    Dictionary,
    Fonts,
    RefTable,
    Trailer,
    Array,
    ObjectCollection,
    Page,
    Paper,
    ImageRef,
    Image,
    Text
  }

  @version Application.compile_env(:pdf, :version, "1.7")
  # 7.5.2 the header line shall be immediately followed by a comment line containing
  # at least four binary characters-that is, characters whose codes are 128 or greater.
  @header <<"%PDF-#{@version}\n%", 0xE2, 0xE3, 0xCF, 0xD3, "\r\n">>
  @header_size byte_size(@header)

  def new(opts \\ []) do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)

    info =
      ObjectCollection.create_object(
        collection,
        Dictionary.new(%{"Creator" => "Elixir", "Producer" => "Elixir-PDF"})
      )

    document = %__MODULE__{objects: collection, fonts: fonts, info: info, opts: opts}
    add_page(document, opts)
  end

  def autoprint(document) do
    action =
      ObjectCollection.create_object(
        document.objects,
        Dictionary.new(%{
          "S" => n("Named"),
          "Type" => n("Action"),
          "N" => n("Print")
        })
      )

    put_in(document.action, action)
  end

  def get_object(document, ref) do
    ObjectCollection.get_object(document.objects, ref)
  end

  @info_map %{
    title: "Title",
    producer: "Producer",
    creator: "Creator",
    created: "CreationDate",
    modified: "ModDate",
    keywords: "Keywords",
    author: "Author",
    subject: "Subject"
  }

  def put_info(document, info_list) when is_list(info_list) do
    info = ObjectCollection.get_object(document.objects, document.info)

    info =
      info_list
      |> Enum.reduce(info, fn {key, value}, info ->
        case @info_map[key] do
          nil ->
            raise ArgumentError, "Invalid info key #{inspect(key)}"

          info_key ->
            Dictionary.put(info, info_key, Text.escape(value))
        end
      end)

    ObjectCollection.update_object(document.objects, document.info, info)
    document
  end

  @info_map
  |> Enum.each(fn {key, _value} ->
    def put_info(document, unquote(key), value), do: put_info(document, [{unquote(key), value}])
  end)

  # Pass-through functions that update the current page
  [
    {:set_fill_color, quote(do: [color])},
    {:set_stroke_color, quote(do: [color])},
    {:set_line_width, quote(do: [width])},
    {:set_line_cap, quote(do: [style])},
    {:set_line_join, quote(do: [style])},
    {:rectangle, quote(do: [{x, y}, {w, h}])},
    {:link, quote(do: [{x, y}, {w, h}, uri])},
    {:link_to_page, quote(do: [{x, y}, {w, h}, page_number])},
    {:line, quote(do: [{x, y}, {x2, y2}])},
    {:move_to, quote(do: [{x, y}])},
    {:line_append, quote(do: [{x, y}])},
    {:set_font, quote(do: [name, size, opts])},
    {:set_font_size, quote(do: [size])},
    {:set_text_leading, quote(do: [leading])},
    {:text_at, quote(do: [{x, y}, text, opts])},
    {:text_wrap!, quote(do: [{x, y}, {w, h}, text, opts])},
    {:table!, quote(do: [{x, y}, {w, h}, data, opts])},
    {:text_lines, quote(do: [{x, y}, lines, opts])},
    {:stroke, []},
    {:fill, []},
    {:move_down, quote(do: [amount])},
    {:save_state, []},
    {:restore_state, []}
  ]
  |> Enum.map(fn {func_name, args} ->
    def unquote(func_name)(%__MODULE__{current_page: page} = document, unquote_splicing(args)) do
      page = Page.unquote(func_name)(page, unquote_splicing(args))
      %{document | current_page: page}
    end
  end)

  def text_at(document, xy, text), do: text_at(document, xy, text, [])

  def text_wrap!(document, xy, wh, text), do: text_wrap!(document, xy, wh, text, [])

  def text_wrap(document, xy, wh, text), do: text_wrap(document, xy, wh, text, [])

  def text_wrap(%__MODULE__{current_page: page} = document, xy, wh, text, opts) do
    {page, remaining} = Page.text_wrap(page, xy, wh, text, opts)
    {%{document | current_page: page}, remaining}
  end

  def render_table(
        %__MODULE__{current_page: page} = document,
        xy,
        wh,
        {:continue, %Pdf.Table{} = table}
      ) do
    {page, remaining} = Pdf.Table.render(page, xy, wh, table)
    {%{document | current_page: page}, remaining}
  end

  def render_table(
        %__MODULE__{current_page: page} = document,
        xy,
        {w, _h} = wh,
        %Pdf.Table{} = table
      ) do
    table = Pdf.Table.prepare(page, table, w)
    {page, remaining} = Pdf.Table.render(page, xy, wh, table)
    {%{document | current_page: page}, remaining}
  end

  def table!(document, xy, wh, data), do: table!(document, xy, wh, data, [])

  def table(document, xy, wh, data), do: table(document, xy, wh, data, [])

  def table(%__MODULE__{current_page: page} = document, xy, wh, data, opts) do
    {page, remaining} = Page.table(page, xy, wh, data, opts)
    {%{document | current_page: page}, remaining}
  end

  def text_lines(document, xy, lines), do: text_lines(document, xy, lines, [])

  def create_image(document, {:binary, image_data}) do
    md5 = :erlang.md5(image_data)
    get_or_create_image(document, md5, {:binary, image_data})
  end

  def create_image(document, image_path) do
    get_or_create_image(document, image_path, image_path)
  end

  defp get_or_create_image(document, image_key, image_data) do
    %{images: images} = document

    case Map.get(images, image_key) do
      nil ->
        image_ref = create_image_ref(document, image_data)
        image = Image.new(image_ref)
        {image, %{document | images: Map.put_new(images, image_key, image_ref)}}

      image_ref ->
        {Image.new(image_ref), document}
    end
  end

  def draw_image(document, xy, %Image{} = image, opts) do
    %{document | current_page: Page.draw_image(document.current_page, xy, image, opts)}
  end

  def add_image(document, xy, image, opts \\ [])

  def add_image(document, xy, %Image{} = image, opts) do
    %{document | current_page: Page.add_image(document.current_page, xy, image, opts)}
  end

  def add_image(document, {x, y}, {:binary, image_data}, opts) do
    md5 = :erlang.md5(image_data)
    {_image, document} = add_or_create_image(document, {x, y}, md5, {:binary, image_data}, opts)
    document
  end

  def add_image(document, {x, y}, image_path, opts) do
    {_image, document} = add_or_create_image(document, {x, y}, image_path, image_path, opts)
    document
  end

  defp add_or_create_image(
         %__MODULE__{current_page: page} = document,
         {x, y},
         image_key,
         image,
         opts
       ) do
    case Map.get(document.images, image_key) do
      nil ->
        image_ref = create_image_ref(document, image)
        image = Image.new(image_ref)

        document = %{
          document
          | current_page: Page.add_image(page, {x, y}, image_ref, opts),
            images: Map.put_new(document.images, image_key, image_ref)
        }

        {image, document}

      image ->
        {image, document}
    end
  end

  defp create_image_ref(%{objects: objects, images: images}, image_path) do
    image_ref = ImageRef.new(image_path, objects)
    object = ObjectCollection.create_object(objects, image_ref)
    name = n("I#{Kernel.map_size(images) + 1}")
    %{image_ref | name: name, object: object}
  end

  def add_external_font(%{fonts: fonts} = document, path) do
    Fonts.add_external_font(fonts, path)
    document
  end

  def add_page(
        %__MODULE__{current_page: current_page, fonts: fonts, opts: doc_opts} = document,
        opts \\ []
      ) do
    size =
      Keyword.get_lazy(opts, :size, fn ->
        if(current_page,
          do: size_tuple(Page.size(current_page)),
          else: default_page_size(document)
        )
      end)

    new_page = Page.new(Keyword.merge(Keyword.merge(doc_opts, opts), fonts: fonts, size: size))

    if current_page do
      %{current_font: font, current_font_size: font_size} = current_page
      pages = if(current_page, do: [current_page | document.pages], else: document.pages)
      document = %{document | current_page: new_page, pages: pages}
      set_font(document, font.module.name, font_size, [])
    else
      %{document | current_page: new_page}
    end
  end

  defp size_tuple(%{width: width, height: height}), do: {width, height}

  def page_number(%__MODULE__{pages: pages}), do: length(pages) + 1

  def size(%__MODULE__{current_page: current_page}) do
    Page.size(current_page)
  end

  def cursor(%__MODULE__{current_page: current_page}) do
    Page.cursor(current_page)
  end

  def set_cursor(%__MODULE__{current_page: current_page} = document, y) do
    %{document | current_page: Page.set_cursor(current_page, y)}
  end

  def to_iolist(document) do
    pages = Enum.reverse([document.current_page | document.pages])
    proc_set = [n("PDF"), n("Text")]

    proc_set =
      if Kernel.map_size(document.images) > 0,
        do: [n("ImageB"), n("ImageC"), n("ImageI") | proc_set],
        else: proc_set

    resources =
      Dictionary.new(%{
        "Font" => font_dictionary(document.fonts),
        "ProcSet" => Array.new(proc_set)
      })

    resources =
      if Kernel.map_size(document.images) > 0 do
        Dictionary.put(resources, "XObject", xobject_dictionary(document.images))
      else
        resources
      end

    page_collection =
      Dictionary.new(%{
        "Type" => n("Pages"),
        "Count" => length(pages),
        "MediaBox" => Array.new(Paper.size(default_page_size(document))),
        "Resources" => resources
      })

    master_page = ObjectCollection.create_object(document.objects, page_collection)
    page_objects = pages_to_objects(document, pages, master_page)
    ObjectCollection.call(document.objects, master_page, :put, ["Kids", Array.new(page_objects)])

    catalogue =
      ObjectCollection.create_object(
        document.objects,
        Dictionary.new(%{
          "Type" => n("Catalog"),
          "Pages" => master_page,
          "OpenAction" => document.action
        })
      )

    objects = Enum.sort_by(ObjectCollection.all(document.objects), &sort_objects/1)

    {ref_table, offset} = RefTable.to_iolist(objects, @header_size)

    Pdf.Export.to_iolist([
      @header,
      objects,
      ref_table,
      Trailer.new(objects, offset, catalogue, document.info)
    ])
  end

  defp sort_objects(%{generation: g, number: n}) do
    g = String.to_integer(g)
    n = String.to_integer(n)
    {g, n}
  end

  defp pages_to_objects(%__MODULE__{objects: objects} = document, pages, parent) do
    default_size = default_page_size(document)

    # First pass: create all page dictionaries and build page number -> page ref map
    {_page_dict_refs, page_ref_map} =
      pages
      |> Enum.with_index(1)
      |> Enum.map_reduce(%{}, fn {page, index}, acc ->
        page_dict_ref = Page.to_page_dictionary(page, objects, parent, default_size)
        {page_dict_ref, Map.put(acc, index, page_dict_ref)}
      end)

    # Second pass: add annotations to each page dictionary using the page ref map
    pages
    |> Enum.with_index(1)
    |> Enum.each(fn {page, index} ->
      annot_refs = Page.create_annotations(page, objects, page_ref_map)

      if annot_refs != [] do
        page_dict_ref = Map.get(page_ref_map, index)
        page_dict = ObjectCollection.get_object(objects, page_dict_ref)
        updated_dict = Dictionary.put(page_dict, "Annots", Array.new(annot_refs))
        ObjectCollection.update_object(objects, page_dict_ref, updated_dict)
      end
    end)

    Enum.map(1..length(pages), fn index -> Map.get(page_ref_map, index) end)
  end

  defp font_dictionary(fonts) do
    fonts
    |> Fonts.get_fonts()
    |> Enum.reduce(%{}, fn {_name, %{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp xobject_dictionary(images) do
    images
    |> Enum.reduce(%{}, fn {_image_key, %Pdf.ImageRef{name: name, object: reference}}, map ->
      Map.put(map, name, reference)
    end)
    |> Dictionary.new()
  end

  defp default_page_size(%__MODULE__{opts: opts}), do: Keyword.get(opts, :size, :a4)
end
