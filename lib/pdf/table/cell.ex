defmodule Pdf.Table.Cell do
  @moduledoc false

  alias __MODULE__

  @derive {Inspect,
           except: [:chunks],
           optional: [
             :data,
             :colspan,
             :padding,
             :border,
             :border_color,
             :background,
             :color,
             :font_size,
             :bold,
             :italic,
             :align,
             :kerning
           ]}
  defstruct [
    # Content
    :data,
    :chunks,
    # Layout
    :colspan,
    # Styling
    :padding,
    :border,
    :border_color,
    :background,
    :color,
    # Text styling
    :font_size,
    :bold,
    :italic,
    :align,
    :kerning
  ]

  @type t :: %Cell{
          data: any(),
          chunks: list(),
          colspan: integer() | nil,
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
          align: :left | :center | :right | nil,
          kerning: boolean() | nil
        }

  def new(cell_or_data, opts \\ [])
  def new(%Cell{} = cell, opts), do: merge_options(cell, opts)

  def new(data, opts) do
    merge_options(%Cell{data: data}, opts)
  end

  def merge_options(%Cell{} = cell, opts) do
    opts
    |> Enum.reduce(cell, fn {key, value}, cell ->
      case cell do
        %{^key => _} -> %{cell | key => value}
        _ -> cell
      end
    end)
  end

  def put_colspan(%Cell{} = cell, colspan), do: %{cell | colspan: colspan}
  def put_padding(%Cell{} = cell, padding), do: %{cell | padding: padding}
  def put_border(%Cell{} = cell, border), do: %{cell | border: border}
  def put_border_color(%Cell{} = cell, border_color), do: %{cell | border_color: border_color}
  def put_background(%Cell{} = cell, background), do: %{cell | background: background}
  def put_color(%Cell{} = cell, color), do: %{cell | color: color}
  def put_font_size(%Cell{} = cell, font_size), do: %{cell | font_size: font_size}
  def put_bold(%Cell{} = cell, bold), do: %{cell | bold: bold}
  def put_italic(%Cell{} = cell, italic), do: %{cell | italic: italic}
  def put_align(%Cell{} = cell, align), do: %{cell | align: align}
  def put_kerning(%Cell{} = cell, kerning), do: %{cell | kerning: kerning}
end
