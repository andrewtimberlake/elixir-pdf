defmodule Pdf.Fonts do
  @moduledoc false
  import Pdf.Utils

  alias Pdf.{Font, ExternalFont, ObjectCollection}
  alias Pdf.Font.Metrics

  defmodule FontReference do
    @moduledoc false
    defstruct name: nil, module: nil, object: nil
  end

  def start_link(objects), do: GenServer.start_link(__MODULE__.Server, objects)

  def get_font(pid, name, opts) do
    GenServer.call(pid, {:get_font, name, opts})
  end

  def get_fonts(pid) do
    GenServer.call(pid, :get_fonts)
  end

  def add_external_font(pid, path) do
    GenServer.call(pid, {:add_external_font, path})
  end

  font_metrics =
    Path.join(__DIR__, "../../fonts/*.afm")
    |> Path.wildcard()
    |> Enum.map(fn afm_file ->
      afm_file
      |> File.stream!()
      |> Enum.reduce(%Pdf.Font.Metrics{}, fn line, metrics ->
        Pdf.Font.Metrics.process_line(String.replace_suffix(line, "\n", ""), metrics)
      end)
    end)

  @internal_fonts font_metrics
                  |> Enum.map(fn metrics ->
                    {metrics.name,
                     %Pdf.Font{
                       name: metrics.name,
                       full_name: metrics.full_name,
                       family_name: metrics.family_name,
                       weight: metrics.weight,
                       italic_angle: metrics.italic_angle,
                       encoding: metrics.encoding,
                       first_char: metrics.first_char,
                       last_char: metrics.last_char,
                       ascender: metrics.ascender,
                       descender: metrics.descender,
                       cap_height: metrics.cap_height,
                       x_height: metrics.x_height,
                       bbox: metrics.bbox,
                       widths: Metrics.widths(metrics),
                       glyph_widths: Metrics.map_widths(metrics),
                       glyphs: metrics.glyphs,
                       kern_pairs: metrics.kern_pairs
                     }}
                  end)
                  |> Map.new()
  def get_internal_font(name, opts \\ []) do
    @internal_fonts
    |> Enum.map(fn {_, font} -> font end)
    |> Enum.find(fn font ->
      font.family_name == name && Font.matches_attributes(font, opts)
    end)
  end

  defmodule Server do
    use GenServer

    defmodule State do
      @moduledoc false
      defstruct last_id: 0, fonts: %{}, objects: nil
    end

    @impl true
    def init(objects), do: {:ok, %State{objects: objects}}

    @impl true
    def handle_call({:get_font, name, opts}, _from, state) do
      {state, ref} = lookup_font(state, name, opts)

      {:reply, ref, state}
    end

    def handle_call(:get_fonts, _from, state) do
      {:reply, state.fonts, state}
    end

    def handle_call({:add_external_font, path}, _from, state) do
      %{last_id: last_id, fonts: fonts, objects: objects} = state
      font_module = ExternalFont.load(path)

      unless fonts[font_module.name] do
        id = last_id + 1
        font_object = ObjectCollection.create_object(objects, nil)

        descriptor_id = descriptor_object = ObjectCollection.create_object(objects, nil)

        font_file = ObjectCollection.create_object(objects, font_module)

        font_dict = ExternalFont.font_dictionary(font_module, id, descriptor_id)
        font_descriptor_dict = ExternalFont.font_descriptor_dictionary(font_module, font_file)

        ObjectCollection.update_object(objects, descriptor_object, font_descriptor_dict)
        ObjectCollection.update_object(objects, font_object, font_dict)

        reference = %FontReference{
          name: n("F#{id}"),
          module: font_module,
          object: font_object
        }

        fonts = Map.put(fonts, font_module.name, reference)
        {:reply, reference, %{state | last_id: id, fonts: fonts}}
      else
        {:reply, :already_exists, state}
      end
    end

    defp lookup_font(state, name, opts) when is_binary(name) do
      case Pdf.Fonts.get_internal_font(name, opts) do
        nil -> lookup_font(state, name)
        font -> lookup_font(state, font)
      end
    end

    defp lookup_font(state, %Font{family_name: family_name}, opts) do
      case Pdf.Fonts.get_internal_font(family_name, opts) do
        nil -> lookup_font(state, family_name)
        font -> lookup_font(state, font)
      end
    end

    defp lookup_font(%{fonts: fonts} = state, %ExternalFont{family_name: family_name}, opts) do
      Enum.find(fonts, fn {_, %{module: font}} ->
        font.family_name == family_name && Font.matches_attributes(font, opts)
      end)
      |> case do
        nil -> {state, nil}
        {_, f} -> {state, f}
      end
    end

    defp lookup_font(%{fonts: fonts} = state, name) when is_binary(name) do
      {state, fonts[name]}
    end

    defp lookup_font(fonts = state, name) when is_binary(name) do
      {state, fonts[name]}
    end

    defp lookup_font(%{fonts: fonts} = state, font_module) do
      case fonts[font_module.name] do
        nil -> load_font(state, font_module)
        font -> {state, font}
      end
    end

    defp load_font(%{fonts: fonts, last_id: last_id, objects: objects} = state, font_module) do
      id = last_id + 1
      font_object = ObjectCollection.create_object(objects, Font.to_dictionary(font_module, id))

      reference = %FontReference{
        name: n("F#{id}"),
        module: font_module,
        object: font_object
      }

      fonts = Map.put(fonts, font_module.name, reference)
      {%{state | last_id: id, fonts: fonts}, reference}
    end
  end
end
