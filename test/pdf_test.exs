defmodule PdfTest do
  use Pdf.Case, async: true
  doctest Pdf

  @open false
  test "new/1" do
    file_path = output("qtest.pdf")
    assert_unchanged(file_path, fn ->
      {:ok, pdf} = Pdf.new(size: :a4)
      pdf
      |> Pdf.set_author("Test Author")
      |> Pdf.set_creator("Test Creator")
      |> Pdf.set_keywords("word word word")
      |> Pdf.set_producer("Test producer")
      |> Pdf.set_subject("Test Subject")
      |> Pdf.set_title("Test Document")
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.text_at({10, 400}, "Hello World")
      |> Pdf.text_lines({10, 300}, [
        "First line",
        "Second line",
        "Third line"
        ])
      |> Pdf.add_image({25, 50}, fixture("rgb.jpg"))
      |> Pdf.add_image({175, 50}, fixture("cmyk.jpg"))
      |> Pdf.add_image({325, 50}, fixture("grayscale.jpg"))
      |> Pdf.write_to(file_path)
      |> Pdf.delete
    end)

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "open/2" do
    Pdf.open(fn(pdf) ->
      pdf
    end)
  end
end
