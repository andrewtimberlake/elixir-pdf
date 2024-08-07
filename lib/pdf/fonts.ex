defmodule Pdf.Fonts do
  @moduledoc false
  import Pdf.Utils

  alias Pdf.{Font, ExternalFont, ObjectCollection}

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
      case Font.lookup(name, opts) do
        nil ->
          lookup_font(state, name)

        font_module ->
          lookup_font(state, font_module)
      end
    end

    defp lookup_font(%{fonts: fonts} = state, %ExternalFont{family_name: family_name}, opts) do
      bold = Keyword.get(opts, :bold, false)
      italic = Keyword.get(opts, :italic, false)

      Enum.find(fonts, fn {_, %{module: font}} ->
        if font.family_name == family_name do
          cond do
            bold && !italic && font.weight == :bold && font.italic_angle == 0 -> true
            bold && italic && font.weight == :bold && font.italic_angle != 0 -> true
            !bold && !italic && font.weight != :bold && font.italic_angle == 0 -> true
            !bold && italic && font.weight != :bold && font.italic_angle != 0 -> true
            true -> false
          end
        else
          false
        end
      end)
      |> case do
        nil -> {state, nil}
        {_, f} -> {state, f}
      end
    end

    defp lookup_font(state, font, opts) do
      lookup_font(state, font.family_name, opts)
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
