defmodule Pdf.Font do
  @moduledoc false

  import Pdf.Utils
  # alias Pdf.Font.Metrics
  alias Pdf.{Array, Dictionary, Font}

  @derive {Inspect, only: [:name, :family_name, :weight, :italic_angle]}
  defstruct name: nil,
            full_name: nil,
            family_name: nil,
            weight: nil,
            italic_angle: nil,
            encoding: nil,
            first_char: nil,
            last_char: nil,
            ascender: nil,
            descender: nil,
            cap_height: nil,
            x_height: nil,
            fixed_pitch: nil,
            bbox: nil,
            widths: nil,
            glyph_widths: nil,
            glyphs: nil,
            kern_pairs: nil

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
  def width(font, <<char_code::integer>> = str) when is_binary(str) do
    width(font, char_code)
  end

  def width(font, char_code) do
    font.glyph_widths[char_code] || 0
  end

  @doc ~S"""
  Returns the width of the string in font units (1/1000 of font scale factor)
  """
  def text_width(font, string), do: text_width(font, string, [])

  def text_width(font, string, opts) when is_list(opts) do
    normalized_string =
      Pdf.Text.normalize_string(
        string,
        Keyword.get(opts, :encoding_replacement_character, :raise)
      )

    string_width = calculate_string_width(font, normalized_string)

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

  defp calculate_string_width(_font, ""), do: 0

  defp calculate_string_width(font, <<char::integer, rest::binary>>) do
    Font.width(font, char) + calculate_string_width(font, rest)
  end

  def kern_text(_font, ""), do: [""]

  def kern_text(font, <<first::integer, second::integer, rest::binary>>) do
    font.kern_pairs
    |> Enum.find(fn {f, s, _amount} -> f == first && s == second end)
    |> case do
      {f, _s, amount} ->
        [<<f>>, -amount | kern_text(font, <<second::integer, rest::binary>>)]

      nil ->
        [head | tail] = kern_text(font, <<second::integer, rest::binary>>)
        [<<first::integer, head::binary>> | tail]
    end
  end

  def kern_text(_font, <<_::integer>> = char), do: [char]

  def kern_text(_font, ""), do: [""]

  def kern_text(%Pdf.ExternalFont{} = font, text) do
    Pdf.ExternalFont.kern_text(font, text)
  end

  def kern_text(font, text) do
    font.kern_text(text)
  end

  @doc """
  Lookup a font by family name and attributes [bold: true, italic: true]
  """
  def matches_attributes(font, attrs) do
    bold = Keyword.get(attrs, :bold, false)
    italic = Keyword.get(attrs, :italic, false)

    cond do
      bold && !italic && font.weight == :bold && font.italic_angle == 0 -> true
      bold && italic && font.weight == :bold && font.italic_angle != 0 -> true
      !bold && !italic && font.weight != :bold && font.italic_angle == 0 -> true
      !bold && italic && font.weight != :bold && font.italic_angle != 0 -> true
      true -> false
    end
  end
end
