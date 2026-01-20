defmodule Pdf.Table.Table do
  @moduledoc false

  alias Pdf.Table.{Row, Column}
  alias __MODULE__

  @text_styling_options [:color, :font_size, :bold, :italic, :kerning]

  @derive {Inspect,
           optional: [
             :rows,
             :columns,
             :repeat_header,
             :allow_row_overflow,
             :encoding_replacement_character,
             :padding,
             :border,
             :border_color,
             :background
             | @text_styling_options
           ]}
  defstruct [
              :rows,
              :columns,
              # Table-specific opts
              :repeat_header,
              :allow_row_overflow,
              :encoding_replacement_character,
              # General styling opts (can apply to table, rows, and cells)
              :padding,
              :border,
              :border_color,
              :background
            ] ++ @text_styling_options

  @type t :: %Table{
          rows: list(Row.t()),
          columns: list(Column.t()) | nil,
          repeat_header: integer() | nil,
          allow_row_overflow: boolean() | nil,
          encoding_replacement_character: String.t() | nil,
          padding:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          border:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          border_color: atom() | tuple() | nil,
          background: atom() | tuple() | nil,
          color: atom() | tuple() | nil,
          font_size: number() | nil,
          bold: boolean() | nil,
          italic: boolean() | nil,
          kerning: boolean() | nil
        }

  def new(rows, opts \\ []) do
    # Check if first element is a Column (for columns option)
    {rows, columns} =
      if rows != [] and match?([%Column{} | _], rows) do
        {[], rows}
      else
        {rows |> Enum.reduce([], fn row, acc -> [Row.new(row) | acc] end), nil}
      end

    columns = columns || Keyword.get(opts, :columns)

    %Table{
      rows: rows,
      columns: columns
    }
    |> merge_options(opts)
  end

  def merge_options(%Table{} = table, opts) do
    opts
    |> Enum.reduce(table, fn {key, value}, table ->
      case table do
        %{^key => _} -> %{table | key => value}
        _ -> table
      end
    end)
  end

  def add_row(table, row, opts \\ [])
  def add_row(%Table{} = table, [], _opts), do: table

  def add_row(%Table{} = table, row, opts) do
    %{table | rows: [Row.new(row, opts) | table.rows]}
  end

  def add_rows(%Table{} = table, rows, opts \\ []) do
    rows = rows |> Enum.reduce(table.rows, fn row, acc -> [Row.new(row, opts) | acc] end)
    %{table | rows: rows}
  end
end
