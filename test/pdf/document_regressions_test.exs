defmodule Pdf.DocumentRegressionsTest do
  use Pdf.Case, async: true

  defp streams(pdf) do
    ~r/stream\r?\n(.*?)\r?\n?endstream/s
    |> Regex.scan(Pdf.export(pdf), capture: :all_but_first)
    |> Enum.map(fn [stream] -> stream end)
  end

  defp new_pdf do
    {:ok, pdf} = Pdf.new(size: :a4, compress: false)
    pdf
  end

  test "add_image/4 draws an image on every page it is added to" do
    pdf = new_pdf() |> Pdf.set_font("Helvetica", 10)

    Enum.each(1..3, fn page ->
      if page > 1, do: Pdf.add_page(pdf, :a4)
      Pdf.add_image(pdf, {0, 700}, fixture("rgb.jpg"), width: 100, height: 50)
    end)

    draws =
      pdf
      |> streams()
      |> Enum.map(&length(Regex.scan(~r/\/I\d+ Do/, &1)))
      |> Enum.reject(&(&1 == 0))

    Pdf.cleanup(pdf)
    assert draws == [1, 1, 1]
  end

  test "add_page/2 works before any font has been set" do
    pdf = new_pdf()
    assert Pdf.add_page(pdf, :a4) == pdf
    Pdf.cleanup(pdf)
  end

  test "every cell of a coloured row sets its text colour" do
    pdf = new_pdf() |> Pdf.set_font("Helvetica", 10)
    data = [["A1", "A2", "A3"], ["B1", "B2", "B3"]]

    {^pdf, :complete} =
      pdf
      |> Pdf.render_table(
        {50, 700},
        {300, 200},
        Pdf.Table.new([
          Pdf.Table.Row.new(hd(data), color: :red),
          Pdf.Table.Row.new(List.last(data), color: :red)
        ])
      )

    [content] = streams(pdf)
    Pdf.cleanup(pdf)

    {red, _} =
      content
      |> String.split("\n")
      |> Enum.reduce({[], "0.0 0.0 0.0"}, fn line, {red, current} ->
        cond do
          String.ends_with?(line, " rg") -> {red, String.trim_trailing(line, " rg")}
          line == "Q" -> {red, "0.0 0.0 0.0"}
          String.ends_with?(line, " Tj") -> {[{line, current} | red], current}
          true -> {red, current}
        end
      end)

    assert Enum.all?(red, fn {_text, colour} -> colour == "1.0 0.0 0.0" end), inspect(red)
    assert length(red) == 6
  end
end
