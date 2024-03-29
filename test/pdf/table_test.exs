defmodule Pdf.TableTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, ObjectCollection, Fonts}

  setup do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(fonts: fonts, compress: false)

    # Preload fonts so the internal names are fixed (but don't save the resulting stream)
    page
    |> Page.set_font("Helvetica", 12)
    |> Page.set_font("Helvetica", 12, bold: true)
    |> Page.set_font("Helvetica", 12, italic: true)
    |> Page.set_font("Helvetica", 12, bold: true, italic: true)

    {:ok, page: page}
  end

  test "it does nothing with an empty data list", %{page: page} do
    {page, []} = Page.table(page, {20, 600}, {500, 500}, [])

    assert export(page) == "\n"
  end

  test "basic table", %{page: page} do
    data = [
      ["Col 1,1", "Col 1,2", "Col 1,3"],
      ["Col 2,1", "Col 2,2", "Col 2,3"]
    ]

    {page, :complete} =
      page
      |> Page.set_font("Helvetica", 12)
      |> Page.table({20, 600}, {300, 500}, data)

    assert export(page) == """
           q
           20 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 590.934 Td
           (Col 1,1) Tj
           ET
           Q
           q
           120.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 590.934 Td
           (Col 1,2) Tj
           ET
           Q
           q
           220.0 588 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 590.934 Td
           (Col 1,3) Tj
           ET
           Q
           q
           20 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           20 578.934 Td
           (Col 2,1) Tj
           ET
           Q
           q
           120.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           120.0 578.934 Td
           (Col 2,2) Tj
           ET
           Q
           q
           220.0 576 100.0 12 re
           W n
           BT
           /F1 12 Tf
           220.0 578.934 Td
           (Col 2,3) Tj
           ET
           Q
           """
  end

  test "row exceeds available space" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {_page,
            {:continue,
             [
               [
                 {[{"Col", 18.0, [_ | _]}, {" ", 3.336, [_ | _]}, {"1", 6.672, [_ | _]}],
                  [width: 26.666666666666664, x: 10]},
                 {[
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]},
                    {" ", 3.336, [_ | _]},
                    {"Test", 23.34, [_ | _]}
                  ], [width: 26.666666666666664, x: 36.666666666666664]},
                 {[{"Col", 18.0, [_ | _]}, {" ", 3.336, [_ | _]}, {"3", 6.672, [_ | _]}],
                  [width: 26.666666666666664, x: 63.33333333333333]}
               ]
             ]}} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table({10, 90}, {80, 80}, [
               ["Header 1", "Header 2", "Header 3"],
               [
                 "Col 1",
                 long_content("Test", 5),
                 "Col 3"
               ]
             ])
  end

  test "row exceeds available space but with partial row allowed" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {page,
            {:continue,
             [
               [
                 {[], [_ | _]},
                 {[
                    {"Test", 23.34, [_ | _]}
                  ], [_ | _]},
                 {[], [_ | _]}
               ]
             ]} = continued_data} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 ["Header 1", "Header 2", "Header 3"],
                 [
                   "Col 1",
                   long_content("Test", 5),
                   "Col 3"
                 ]
               ],
               allow_row_overflow: true
             )

    assert {_page, :complete} =
             page |> Page.table({10, 90}, {80, 80}, continued_data, allow_row_overflow: true)
  end

  test "handle empty row generated from trailing whitespace" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    # Tiny paper so we run out of space quickly
    page = Page.new(size: [100, 100], fonts: fonts, compress: false)

    assert {_page, :complete} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 ["Header 1", "Header 2", "Header 3"],
                 [
                   "Col 1",
                   "Col 2",
                   #    ↓ the error
                   "mmmm "
                 ]
               ],
               allow_row_overflow: true
             )
  end

  test "Handle empty row error" do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(size: :a4, fonts: fonts, compress: false)

    assert {_page, :complete} =
             page
             |> Page.set_font("Helvetica", 12)
             |> Page.table(
               {10, 90},
               {80, 80},
               [
                 []
               ],
               allow_row_overflow: true
             )
  end

  defp long_content(string, repeats) do
    1..repeats
    |> Enum.map(fn _ -> string end)
    |> Enum.join(" ")
  end
end
