defmodule Pdf.Table.Cell do
  @moduledoc false

  alias __MODULE__
  alias Pdf.Table
  alias Pdf.Table.Column

  @text_styling_options [:color, :font_size, :bold, :italic, :kerning]

  @derive {Inspect,
           except: [:chunks],
           optional: [
             :data,
             :colspan,
             :padding,
             :border,
             :border_color,
             :background,
             :align,
             :valign,
             :encoding_replacement_character
             | @text_styling_options
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
              :align,
              :valign,
              :encoding_replacement_character
            ] ++ @text_styling_options

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
          valign: :top | :middle | :bottom | nil,
          kerning: boolean() | nil,
          encoding_replacement_character: String.t() | nil
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

  def inherit_options(%Cell{} = cell, %Column{} = column) do
    cell
    |> inherit_text_options(column)
    |> inherit_column_options(column)
    |> inherit_perimeter_options(column)
  end

  def inherit_options(%Cell{} = cell, parent) do
    cell
    |> inherit_text_options(parent)
    |> inherit_valign(parent)
    |> inherit_encoding(parent)
    |> inherit_perimeter_options(parent)
  end

  defp inherit_encoding(%Cell{encoding_replacement_character: nil} = cell, %{
         encoding_replacement_character: value
       }) do
    %{cell | encoding_replacement_character: value}
  end

  defp inherit_encoding(cell, _parent), do: cell

  defp inherit_text_options(%Cell{} = cell, parent) do
    Enum.reduce(@text_styling_options, cell, fn option, cell ->
      case cell do
        %{^option => nil} ->
          %{^option => inherited_option} = parent
          %{cell | option => inherited_option}

        _ ->
          cell
      end
    end)
  end

  defp inherit_valign(%Cell{valign: nil} = cell, parent) do
    %{valign: inherited_valign} = parent
    %{cell | valign: inherited_valign}
  end

  defp inherit_valign(%Cell{} = cell, _parent), do: cell

  defp inherit_column_options(%Cell{} = cell, %Column{} = parent) do
    Enum.reduce(
      [
        :width,
        :max_width,
        :min_width,
        :align,
        :valign,
        :background
      ],
      cell,
      fn option, cell ->
        case cell do
          %{^option => nil} ->
            %{^option => inherited_option} = parent
            %{cell | option => inherited_option}

          _ ->
            cell
        end
      end
    )
  end

  # Table-level :border is the outer frame (drawn around the table).
  # Only :padding is a cell default from the table.
  defp inherit_perimeter_options(%Cell{} = cell, %Table{} = parent) do
    inherit_perimeter_options(cell, parent, [{:padding, nil}])
  end

  defp inherit_perimeter_options(%Cell{} = cell, parent) when is_map(parent) do
    inherit_perimeter_options(cell, parent, [
      {:padding, nil},
      {:border, nil},
      {:border_color, nil}
    ])
  end

  defp inherit_perimeter_options(%Cell{} = cell, parent, options) do
    Enum.reduce(options, cell, fn {option, default}, cell ->
      if Map.has_key?(parent, option) do
        %{^option => cell_value} = cell
        normalized_cell_value = normalize_perimeter_tuple(cell_value, nil)
        %{^option => parent_value} = parent
        normalized_parent_value = normalize_perimeter_tuple(parent_value, default)
        merged_value = merge_tuples(normalized_cell_value, normalized_parent_value)
        %{cell | option => merged_value}
      else
        cell
      end
    end)
  end

  def finalize_perimeter(%Cell{} = cell) do
    %{
      cell
      | padding: normalize_perimeter_tuple(cell.padding, 0),
        border: normalize_perimeter_tuple(cell.border, 0)
    }
  end

  def normalize_perimeter_tuple(value, default \\ 0)
  def normalize_perimeter_tuple(nil, default), do: {default, default, default, default}
  def normalize_perimeter_tuple({nil}, default), do: {default, default, default, default}
  def normalize_perimeter_tuple({all}, _default), do: {all, all, all, all}
  def normalize_perimeter_tuple({tb, lr}, default), do: {tb || default, lr || default, tb || default, lr || default}
  def normalize_perimeter_tuple({t, lr, b}, default), do: {t || default, lr || default, b || default, lr || default}
  def normalize_perimeter_tuple({t, r, b, l}, default), do: {t || default, r || default, b || default, l || default}
  def normalize_perimeter_tuple(all, _default), do: {all, all, all, all}

  def merge_tuples({t, r, b, l}, {pt, pr, pb, pl}),
    do: {t || pt, r || pr, b || pb, l || pl}

  def text_opts(%Cell{} = cell) do
    (@text_styling_options ++ [:encoding_replacement_character])
    |> Enum.map(fn option ->
      %{^option => value} = cell
      {option, value}
    end)
    |> Enum.reject(fn {_option, value} -> value == nil end)
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
  def put_valign(%Cell{} = cell, valign), do: %{cell | valign: valign}
  def put_kerning(%Cell{} = cell, kerning), do: %{cell | kerning: kerning}

  def put_encoding_replacement_character(%Cell{} = cell, encoding_replacement_character),
    do: %{cell | encoding_replacement_character: encoding_replacement_character}
end
