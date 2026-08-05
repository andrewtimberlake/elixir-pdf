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

  describe "vertical alignment" do
    @valign_data [["Short", "This description wraps onto three separate lines here"]]

    test "defaults to :top, leaving every cell against the top of the row", %{page: page} do
      assert valign_positions(page, []) == [{20, 590.934}, {80, 590.934}]
      assert valign_positions(page, valign: :top) == valign_positions(page, [])
    end

    test "a nil :valign is treated as absent", %{page: page} do
      assert valign_positions(page, valign: nil) == valign_positions(page, [])

      assert valign_positions(page, cols: [[width: 60, valign: nil], [width: 140]]) ==
               valign_positions(page, [])
    end

    test ":middle centres a short cell within the row", %{page: page} do
      assert valign_positions(page, valign: :middle) == [{20, 578.934}, {80, 590.934}]
    end

    test ":bottom pushes a short cell to the bottom of the row", %{page: page} do
      assert valign_positions(page, valign: :bottom) == [{20, 566.934}, {80, 590.934}]
    end

    test "a cell option overrides the column, which overrides the table", %{page: page} do
      assert valign_positions(page, valign: :bottom, cols: [[width: 60, valign: :top], []]) ==
               [{20, 590.934}, {80, 590.934}]

      assert valign_positions(page,
               valign: :bottom,
               cols: [[width: 60, valign: :top], []],
               rows: %{0 => [cols: [[valign: :middle], []]]}
             ) == [{20, 578.934}, {80, 590.934}]
    end

    test "a row option overrides the column", %{page: page} do
      assert valign_positions(page,
               cols: [[width: 60, valign: :top], []],
               rows: %{0 => [valign: :bottom]}
             ) == [{20, 566.934}, {80, 590.934}]
    end

    test "an unknown :valign raises instead of silently aligning to the top", %{page: page} do
      assert_raise ArgumentError, ~r/invalid :valign :centre/, fn ->
        valign_positions(page, valign: :centre)
      end
    end
  end

  defp long_content(string, repeats) do
    1..repeats
    |> Enum.map(fn _ -> string end)
    |> Enum.join(" ")
  end

  defp valign_positions(page, opts) do
    opts = Keyword.merge([padding: 0, cols: [[width: 60], [width: 140]]], opts)

    {page, :complete} =
      page
      |> Page.set_font("Helvetica", 12)
      |> Page.table({20, 600}, {200, 500}, @valign_data, opts)

    page
    |> export()
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case String.split(line, " ") do
        [x, y, "Td"] -> [{parse_number(x), parse_number(y)}]
        _ -> []
      end
    end)
    |> Enum.reject(&match?({0, _}, &1))
  end

  defp parse_number(string) do
    case Integer.parse(string) do
      {integer, ""} -> integer
      _ -> String.to_float(string)
    end
  end
end
