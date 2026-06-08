defmodule Pdf.Table.Column do
  @moduledoc false

  alias __MODULE__
  @text_styling_options [:color, :font_size, :bold, :italic, :kerning]

  @derive {Inspect,
           optional: [
             :width,
             :max_width,
             :min_width,
             :align,
             :padding,
             :background,
             :border,
             :border_color,
             :hide
             | @text_styling_options
           ]}
  defstruct [
              :width,
              :max_width,
              :min_width,
              :calculated_min_width,
              :align,
              :padding,
              :background,
              :border,
              :border_color,
              :hide
            ] ++ @text_styling_options

  @type t :: %Column{
          width: number() | nil,
          max_width: number() | nil,
          min_width: number() | nil,
          calculated_min_width: number() | nil,
          align: :left | :center | :right | nil,
          padding:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          background: atom() | tuple() | nil,
          color: atom() | tuple() | nil,
          font_size: number() | nil,
          border:
            number()
            | {number()}
            | {number(), number()}
            | {number(), number(), number()}
            | {number(), number(), number(), number()}
            | nil,
          border_color: atom() | tuple() | nil,
          bold: boolean() | nil,
          italic: boolean() | nil,
          kerning: boolean() | nil,
          hide: boolean() | nil
        }

  def new(opts \\ [])
  def new(opts), do: merge_options(%Column{}, opts)

  def merge_options(%Column{} = column, opts) do
    opts
    |> Enum.reduce(column, fn {key, value}, column ->
      case column do
        %{^key => _} -> %{column | key => value}
        _ -> column
      end
    end)
  end

  def put_width(%Column{} = column, width), do: %{column | width: width}
  def put_max_width(%Column{} = column, max_width), do: %{column | max_width: max_width}
  def put_min_width(%Column{} = column, min_width), do: %{column | min_width: min_width}
  def put_align(%Column{} = column, align), do: %{column | align: align}
  def put_padding(%Column{} = column, padding), do: %{column | padding: padding}
  def put_background(%Column{} = column, background), do: %{column | background: background}
  def put_color(%Column{} = column, color), do: %{column | color: color}
  def put_font_size(%Column{} = column, font_size), do: %{column | font_size: font_size}
  def put_border(%Column{} = column, border), do: %{column | border: border}

  def put_border_color(%Column{} = column, border_color),
    do: %{column | border_color: border_color}

  def put_bold(%Column{} = column, bold), do: %{column | bold: bold}
  def put_italic(%Column{} = column, italic), do: %{column | italic: italic}
  def put_kerning(%Column{} = column, kerning), do: %{column | kerning: kerning}
  def put_hide(%Column{} = column, hide), do: %{column | hide: hide}
end
