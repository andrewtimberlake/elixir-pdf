defmodule Pdf.Font do
  @moduledoc false

  import Pdf.Utils
  alias Pdf.Font.Metrics
  alias Pdf.{Array, Dictionary, Font}

  font_metrics =
    Path.join(__DIR__, "../../fonts/*.afm")
    |> Path.wildcard()
    |> Enum.map(fn afm_file ->
      afm_file
      |> File.stream!()
      |> Enum.reduce(%Metrics{}, fn line, metrics ->
        Metrics.process_line(String.replace_suffix(line, "\n", ""), metrics)
      end)
    end)

  font_metrics
  |> Enum.each(fn metrics ->
    font_module = String.to_atom("Elixir.Pdf.Font.#{String.replace(metrics.name, "-", "")}")

    defmodule font_module do
      @moduledoc false
      @doc "The name of the font"
      def name, do: unquote(metrics.name)
      @doc "The full name of the font"
      def full_name, do: unquote(metrics.full_name)
      @doc "The font family of the font"
      def family_name, do: unquote(metrics.family_name)
      @doc "The font weight"
      def weight, do: unquote(metrics.weight)
      @doc "The font italic angle"
      def italic_angle, do: unquote(metrics.italic_angle)
      @doc "The font encoding"
      def encoding, do: unquote(metrics.encoding)
      @doc "The first character defined in `widths/0`"
      def first_char, do: unquote(metrics.first_char)
      @doc "The last character defined in `widths/0`"
      def last_char, do: unquote(metrics.last_char)
      @doc "The font ascender"
      def ascender, do: unquote(metrics.ascender || 0)
      @doc "The font descender"
      def descender, do: unquote(metrics.descender || 0)
      @doc "The font cap height"
      def cap_height, do: unquote(metrics.cap_height)
      @doc "The font x-height"
      def x_height, do: unquote(metrics.x_height)
      @doc "The font bbox"
      def bbox, do: unquote(Macro.escape(metrics.bbox))

      @doc """
      Returns the character widths of characters beginning from `first_char/0`
      """
      def widths, do: unquote(Metrics.widths(metrics))

      @doc """
      Returns the width of the specific character

      Examples:

          iex> #{inspect(__MODULE__)}.width("A")
          123
      """
      def width(char_code)

      Pdf.Encoding.WinAnsi.characters()
      |> Enum.each(fn {char_code, _, name} ->
        case metrics.glyphs[name] do
          nil ->
            def width(unquote(char_code)), do: 0

          %{width: width} ->
            def width(unquote(char_code)), do: unquote(width)
        end
      end)

      def kern_text([]), do: []

      metrics.kern_pairs
      |> Enum.each(fn {first, second, amount} ->
        def kern_text([unquote(first), unquote(second) | tail]) do
          [<<unquote(first)>>, unquote(-amount) | kern_text([unquote(second) | tail])]
        end
      end)

      def kern_text([first, second | tail]) do
        [<<head::binary>> | tail] = kern_text([second | tail])
        [<<first, head::binary>> | tail]
      end

      def kern_text([char]), do: [<<char>>]
    end
  end)

  @doc ~S"""
  Returns the font module for the named font

  # Example:

  iex> Pdf.Font.lookup("Helvetica-BoldOblique")
  Pdf.Font.HelveticaBoldOblique
  """
  def lookup(name, opts \\ [])

  font_metrics
  |> Enum.each(fn metrics ->
    font_module = String.to_atom("Elixir.Pdf.Font.#{String.replace(metrics.name, "-", "")}")

    if metrics.weight == :bold and metrics.italic_angle == 0 do
      def lookup(unquote(metrics.family_name), bold: true), do: unquote(font_module)

      def lookup(unquote(metrics.family_name), bold: true, italic: false),
        do: unquote(font_module)

      def lookup(unquote(metrics.family_name), italic: false, bold: true),
        do: unquote(font_module)
    end

    if metrics.weight == :bold and metrics.italic_angle != 0 do
      def lookup(unquote(metrics.family_name), bold: true, italic: true), do: unquote(font_module)
      def lookup(unquote(metrics.family_name), italic: true, bold: true), do: unquote(font_module)
    end

    if metrics.weight != :bold and metrics.italic_angle == 0 do
      def lookup(unquote(metrics.family_name), italic: false, bold: false),
        do: unquote(font_module)

      def lookup(unquote(metrics.family_name), bold: false, italic: false),
        do: unquote(font_module)

      def lookup(unquote(metrics.family_name), []),
        do: unquote(font_module)
    end

    if metrics.weight != :bold and metrics.italic_angle != 0 do
      def lookup(unquote(metrics.family_name), italic: true), do: unquote(font_module)

      def lookup(unquote(metrics.family_name), bold: false, italic: true),
        do: unquote(font_module)

      def lookup(unquote(metrics.family_name), italic: true, bold: false),
        do: unquote(font_module)
    end

    # def lookup(unquote(metrics.name), []), do: unquote(font_module)
  end)

  def lookup(_name, _opts), do: nil

  def to_dictionary(font, id) do
    Dictionary.new()
    |> Dictionary.put("Type", n("Font"))
    |> Dictionary.put("Subtype", n("Type1"))
    |> Dictionary.put("Name", n("F#{id}"))
    |> Dictionary.put("BaseFont", n(font.name))
    |> Dictionary.put("FirstChar", 32)
    |> Dictionary.put("LastChar", font.last_char)
    |> Dictionary.put("Widths", Array.new(Enum.drop(font.widths, 32)))
    |> Dictionary.put("Encoding", n("WinAnsiEncoding"))
  end

  @doc """
  Returns the width of the specific character

  Examples:

    iex> Font.width(font, "A")
    123
  """
  def width(%Pdf.ExternalFont{} = font, char_code) do
    Pdf.ExternalFont.width(font, char_code)
  end

  def width(font, char_code) do
    font.width(char_code)
  end

  @doc ~S"""
  Returns the width of the string in font units (1/1000 of font scale factor)
  """
  def text_width(font, string), do: text_width(font, string, [])

  def text_width(font, string, opts) when is_list(opts) do
    normalized_string = Pdf.Text.normalize_string(string)

    string_width =
      normalized_string
      |> Enum.reduce(0, &(&2 + Font.width(font, &1)))

    kerning_adjustments =
      if Keyword.get(opts, :kerning, false) do
        Font.kern_text(font, normalized_string)
        |> Enum.reject(&is_binary/1)
        |> Enum.reduce(0, &Kernel.+/2)
      else
        0
      end

    string_width - kerning_adjustments
  end

  @doc ~S"""
  Returns the width of a string in points (72 points = 1 inch)
  """
  def text_width(font, string, font_size) when is_number(font_size) do
    text_width(font, string, font_size, [])
  end

  def text_width(font, string, font_size, opts) when is_number(font_size) do
    width = text_width(font, string, opts)
    width * font_size / 1000
  end

  def kern_text(_font, []), do: []

  def kern_text(%Pdf.ExternalFont{} = font, text) do
    Pdf.ExternalFont.kern_text(font, text)
  end

  def kern_text(font, text) do
    font.kern_text(text)
  end
end
