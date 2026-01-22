defmodule Pdf.Table.Row do
  @moduledoc false

  alias Pdf.Table.Cell
  alias __MODULE__

  @text_styling_options [:color, :font_size, :bold, :italic, :kerning]

  @derive {Inspect,
           optional: [
             :cells,
             :background,
             :border,
             :border_color,
             :padding
             | @text_styling_options
           ]}
  defstruct [
              :cells,
              # Styling
              :background,
              :border,
              :border_color,
              :padding,
              :keep_with_previous
            ] ++ @text_styling_options

  @type t :: %Row{
          cells: list(Cell.t()),
          background: atom() | tuple() | nil,
          border:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          border_color: atom() | tuple() | nil,
          color: atom() | tuple() | nil,
          padding:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          font_size: number() | nil,
          bold: boolean() | nil,
          italic: boolean() | nil,
          kerning: boolean() | nil,
          keep_with_previous: boolean() | nil
        }

  def new(row_or_cells, options \\ [])
  def new(%Row{} = row, options), do: merge_options(row, options)

  def new(cells, options) do
    cells = cells |> Enum.reduce([], fn cell, acc -> [Cell.new(cell) | acc] end)
    %Row{cells: cells} |> merge_options(options)
  end

  def merge_options(%Row{} = row, options) do
    options
    |> Enum.reduce(row, fn {key, value}, row ->
      case row do
        %{^key => _} -> %{row | key => value}
        _ -> row
      end
    end)
  end

  def put_background(%Row{} = row, background), do: %{row | background: background}
  def put_border(%Row{} = row, border), do: %{row | border: border}
  def put_border_color(%Row{} = row, border_color), do: %{row | border_color: border_color}
  def put_color(%Row{} = row, color), do: %{row | color: color}
  def put_padding(%Row{} = row, padding), do: %{row | padding: padding}
  def put_font_size(%Row{} = row, font_size), do: %{row | font_size: font_size}
  def put_bold(%Row{} = row, bold), do: %{row | bold: bold}
  def put_italic(%Row{} = row, italic), do: %{row | italic: italic}
  def put_kerning(%Row{} = row, kerning), do: %{row | kerning: kerning}

  def update_cells(%Row{} = row, cells), do: %{row | cells: cells}

  def add_cell(%Row{} = row, %Cell{} = cell) do
    %{row | cells: [cell | row.cells]}
  end

  def add_cell(%Row{} = row, cell) when is_tuple(cell) do
    # For backward compatibility during migration
    {chunks, options} = cell
    add_cell(row, Cell.new(chunks, options))
  end

  def length(%Row{cells: cells}), do: Kernel.length(cells)

  def empty?(%Row{cells: []}), do: true
  def empty?(%Row{}), do: false
end
