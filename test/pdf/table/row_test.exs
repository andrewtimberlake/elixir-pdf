defmodule Pdf.Table.RowTest do
  use Pdf.Case, async: true

  alias Pdf.Table.Row
  alias Pdf.Table.Cell

  test "new/1" do
    row =
      Row.new(["Test", Cell.new("Test2", bold: true), "Test3"],
        background: :gainsboro,
        border: 0.5,
        color: :black,
        padding: 2,
        font_size: 12,
        bold: true,
        italic: true,
        align: :center,
        kerning: true
      )

    # Cells are stored in reverse order
    assert row.cells == [
             %Cell{data: "Test3"},
             %Cell{data: "Test2", bold: true},
             %Cell{data: "Test"}
           ]
  end

  test "add_cell/2" do
    row = Row.new(["Test"])
    row = Row.add_cell(row, Cell.new("Test2"))

    assert row.cells == [
             %Cell{data: "Test2"},
             %Cell{data: "Test"}
           ]
  end
end
