defmodule Pdf.Examples.TextTruncationTest do
  use Pdf.Case, async: true

  @open true
  @leading 12

  test "truncated text stays inside the box" do
    file_path = output("text_truncation.pdf")

    Pdf.build([size: :a4, compress: false], fn pdf ->
      %{width: width, height: height} = Pdf.size(pdf)
      left = 40
      right = width / 2 + 10
      column = width / 2 - 50

      pdf
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_font("Helvetica", 16, bold: true)
      |> Pdf.text_at({left, height - 40}, "text_wrap! truncate: true")
      |> Pdf.set_font("Helvetica", 9)
      |> Pdf.set_fill_color(:dark_gray)
      |> Pdf.text_at(
        {left, height - 58},
        "Gray rectangles are the wrap boundaries. Overflow ends with an ellipsis."
      )
      |> box(
        {left, height - 100},
        {column, @leading * 2},
        "Fits — no ellipsis",
        "This text fits inside the box."
      )
      |> box(
        {right, height - 100},
        {column, @leading},
        "Second line dropped",
        "Visible line\nThis line is cut off"
      )
      |> box(
        {left, height - 190},
        {120, @leading * 3},
        "Narrow column",
        """
        Unit 4, The Old Warehouse, 123 Extremely Long Street Name
        Sandton Business Park, West Block
        Corner of West and Rivonia Roads
        Johannesburg
        Gauteng
        2196
        South Africa
        """
      )
      |> box(
        {right, height - 190},
        {column, @leading * 2},
        "Last line shortened",
        "Alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango"
      )
      |> box(
        {left, height - 300},
        {column, @leading},
        "Centered",
        "Centered first line\nCentered second line",
        align: :center
      )
      |> box(
        {right, height - 300},
        {column, @leading},
        "Right aligned",
        "Right aligned first line\nRight aligned second line",
        align: :right
      )
      |> box(
        {left, height - 380},
        {width - left * 2, @leading * 4},
        "Paragraph clipped to the box",
        """
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse elementum enim metus, quis posuere sem molestie interdum. Ut efficitur odio lectus, ut facilisis odio tempor quis. Ut ut risus quis tellus placerat tristique ut ultrices leo. Etiam ante lacus, pulvinar non aliquam luctus, efficitur vel velit. Aenean nec urna metus. Sed aliquam libero ligula, ac commodo turpis pulvinar sed. Aenean interdum elementum tempor. Cras tempus feugiat consequat. Mauris ut nulla et orci dapibus auctor a sit amet odio.
        """
      )
      |> Pdf.write_to(file_path)
    end)

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  defp box(pdf, {x, y}, {w, h}, label, text, opts \\ []) do
    pdf
    |> Pdf.set_font("Helvetica", 8)
    |> Pdf.set_fill_color(:dark_gray)
    |> Pdf.text_at({x, y + 6}, label)
    |> Pdf.set_stroke_color(:gray)
    |> Pdf.set_line_width(0.4)
    |> Pdf.rectangle({x, y - h}, {w, h})
    |> Pdf.stroke()
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_font("Helvetica", 10)
    |> Pdf.text_wrap!(
      {x, y},
      {w, h},
      String.trim(text),
      Keyword.merge([truncate: true, leading: @leading, kerning: true], opts)
    )
  end
end
