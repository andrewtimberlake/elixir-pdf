defmodule Pdf.MarginBox do
  @moduledoc """
  A margin box is a rectangle that defines the margins of a page.

  Use it to position content on a page within defined margins.
  """
  defstruct top: 0, right: 0, bottom: 0, left: 0, width: 0, height: 0

  @doc """
  Create a new margin box.

  The margins are specified as a tuple of the form `{top, right, bottom, left}`.
  Simiar to HTML, you can use shorthand notations for the margins.
  - MarginBox.new(pdf, 1) - all four margins are set to 1
  - MarginBox.new(pdf, {1, 2}) - top and bottom are set to 1, left and right are set to 2
  - MarginBox.new(pdf, {1, 2, 3}) - top is set to 1, left and right are set to 2, bottom is set to 3
  - MarginBox.new(pdf, {1, 2, 3, 4}) - top is set to 1, right is set to 2, bottom is set to 3, left is set to 4

  The margin box has all the coordinates of the rectangle that defines the margins.
  - top: the top of the margin box
  - left: the left of the margin box
  - right: the right of the margin box
  - bottom: the bottom of the margin box
  - width: the width of the margin box
  - height: the height of the margin box

  ## Examples

  ```elixir
  margin_box = Pdf.MarginBox.new(pdf, {10, 20, 30, 40})
  ```
  """
  def new(pdf, margins) do
    %{width: page_width, height: page_height} = Pdf.size(pdf)

    {mt, mr, mb, ml} =
      Pdf.Table.Cell.normalize_perimeter_tuple(margins)

    top = page_height - mt
    left = ml
    right = page_width - mr
    bottom = mb
    width = page_width - ml - mr
    height = page_height - mt - mb

    Pdf.set_cursor(pdf, top)
    %__MODULE__{top: top, right: right, bottom: bottom, left: left, width: width, height: height}
  end
end
