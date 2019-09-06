defmodule PdfTest do
  use Pdf.Case, async: true
  doctest Pdf

  @open false
  test "new/1" do
    file_path = output("qtest.pdf")

    {:ok, pdf} = Pdf.new(size: :a4)

    pdf
    |> Pdf.set_info(
      title: "Test Document",
      producer: "Test producer",
      creator: "Test Creator",
      created: ~D"2018-05-22",
      modified: ~D"2018-05-22",
      keywords: "word word word",
      author: "Test Author",
      subject: "Test Subject"
    )
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.text_at({10, 400}, "Hello World")
    |> Pdf.text_lines({10, 300}, [
      "First line",
      "Second line",
      "Third line"
    ])
    |> Pdf.add_image({25, 50}, fixture("rgb.jpg"), width: 54.0, height: 54.0)
    |> Pdf.add_image({175, 50}, fixture("cmyk.jpg"))
    |> Pdf.add_image({325, 50}, fixture("grayscale.jpg"))
    |> Pdf.add_font("test/fonts/Verdana-Bold.afm")
    |> Pdf.set_font("Verdana-Bold", 28)
    |> Pdf.text_at({120.070, 762.653}, "External fonts work")
    |> Pdf.set_font("Helvetica", 28)
    |> Pdf.set_color(Pdf.Color.RGB.red())
    |> Pdf.text_at({200, 230}, "Back to Helvetica")
    |> Pdf.set_color(:nonstroke, Pdf.Color.RGB.silver())
    |> Pdf.set_line_width(0.5)
    |> Pdf.rectangle(50, 750, 450, 45)
    |> Pdf.stroke()
    |> Pdf.set_color(:nonstroke, Pdf.Color.RGB.darkred())
    |> Pdf.line(50, 750, 250, 250)
    |> Pdf.stroke()
    |> Pdf.write_to(file_path)
    |> Pdf.delete()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "open/2" do
    Pdf.open(fn pdf ->
      pdf
    end)
  end
end
