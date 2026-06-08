defmodule Pdf.Table.CellTest do
  use Pdf.Case, async: true

  alias Pdf.Table.Cell

  test "new/1" do
    cell = Cell.new("Test", colspan: 2, align: :center)
    assert cell.data == "Test"
    assert cell.colspan == 2
    assert cell.align == :center
  end

  test "merge_options/1" do
    cell = Cell.new("Test", colspan: 1)
    cell = Cell.merge_options(cell, colspan: 2)
    assert cell.colspan == 2
  end
end
