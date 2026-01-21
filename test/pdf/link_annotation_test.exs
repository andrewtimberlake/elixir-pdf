defmodule Pdf.LinkAnnotationTest do
  use Pdf.Case, async: true

  test "pdf.link/4 emits a Link annotation with correct rect and uri" do
    # pdf: build a simple, uncompressed PDF so output is readable
    pdf_bytes =
      Pdf.build([size: :a4, compress: false], fn pdf ->
        pdf
        |> Pdf.link({10, 20}, {30, 40}, "https://example.com")
        |> Pdf.export()
      end)

    assert is_binary(pdf_bytes)

    assert pdf_bytes =~ "/Annots"
    assert pdf_bytes =~ "/Subtype /Link"
    assert pdf_bytes =~ "/S /URI"
    assert pdf_bytes =~ "/URI (https://example.com)"
    assert pdf_bytes =~ "/Border [ 0 0 0 ]"
    assert pdf_bytes =~ "/Rect [ 10 20 40 60 ]"
  end

  test "pdf.link_to_page/4 emits a Link annotation with GoTo action" do
    pdf_bytes =
      Pdf.build([size: :a4, compress: false], fn pdf ->
        pdf
        |> Pdf.link_to_page({50, 100}, {40, 20}, 1)
        |> Pdf.export()
      end)

    assert is_binary(pdf_bytes)

    assert pdf_bytes =~ "/Annots"
    assert pdf_bytes =~ "/Subtype /Link"
    assert pdf_bytes =~ "/S /GoTo"
    assert pdf_bytes =~ "/D"
    assert pdf_bytes =~ "/Rect [ 50 100 90 120 ]"
  end

  test "pdf.link_to_page/4 drops link if page doesn't exist" do
    pdf_bytes =
      Pdf.build([size: :a4, compress: false], fn pdf ->
        pdf
        |> Pdf.link_to_page({10, 20}, {30, 40}, 999)
        |> Pdf.export()
      end)

    assert is_binary(pdf_bytes)
    # Should not have any annotations since page 999 doesn't exist
    refute pdf_bytes =~ "/Annots"
  end

  test "link: option in annotated text creates link annotation" do
    pdf_bytes =
      Pdf.build([size: :a4, compress: false], fn pdf ->
        pdf
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text_at(
          {100, 200},
          [
            "Visit ",
            {"HexDocs", link: "https://hexdocs.pm/pdf", color: :blue},
            " for docs."
          ]
        )
        |> Pdf.export()
      end)

    assert is_binary(pdf_bytes)
    assert pdf_bytes =~ "/Annots"
    assert pdf_bytes =~ "/Subtype /Link"
    assert pdf_bytes =~ "/S /URI"
    assert pdf_bytes =~ "/URI (https://hexdocs.pm/pdf)"
  end

  test "link: option in text_wrap creates link annotation" do
    pdf_bytes =
      Pdf.build([size: :a4, compress: false], fn pdf ->
        pdf
        |> Pdf.set_font("Helvetica", 12)
        |> Pdf.text_wrap(
          {50, 500},
          {200, 100},
          [
            "Lorem ipsum ",
            {"dolor sit amet", link: "https://example.com", color: :blue},
            " consectetur adipiscing."
          ]
        )
        |> elem(0)
        |> Pdf.export()
      end)

    assert is_binary(pdf_bytes)
    assert pdf_bytes =~ "/Annots"
    assert pdf_bytes =~ "/Subtype /Link"
    assert pdf_bytes =~ "/S /URI"
    assert pdf_bytes =~ "/URI (https://example.com)"
  end
end
