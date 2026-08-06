defmodule Pdf.TableDeprecated do
  @moduledoc false
  alias Pdf.{Page, Text}

  def table!(page, xy, wh, data, opts \\ [])

  def table!(page, xy, wh, data, opts) do
    case table(page, xy, wh, data, opts) do
      {page, :complete} -> page
      _ -> raise(RuntimeError, "The supplied data did not fit within the supplied boundary")
    end
  end

  def table(page, xy, wh, data, opts \\ [])

  def table(page, {x, :cursor}, wh, data, opts),
    do: table(page, {x, Page.cursor(page)}, wh, data, opts)

  def table(page, _xy, _wh, [], _opts), do: {page, []}

  def table(page, {x, y}, {w, h}, {:continue, data}, opts) do
    case draw_table(page, {x, y}, {w, h}, data, opts) do
      {page, []} ->
        {page, :complete}

      {page, remaining} ->
        repeat_rows = Keyword.get(opts, :repeat_header, 0)
        {page, {:continue, Enum.take(data, repeat_rows) ++ remaining}}
    end
  end

  def table(page, {x, y}, {w, h}, data, opts) do
    [first_row | _] = data
    num_cols = length(first_row)

    {opts, col_opts} = fix_column_options(num_cols, opts)

    data =
      data
      |> chunk_data(page, opts, Keyword.get(opts, :rows, %{}))
      |> set_col_dimensions({x, y}, {w, h}, col_opts)

    table(page, {x, y}, {w, h}, {:continue, data}, opts)
  end

  defp normalize_tuple({all}), do: {all, all, all, all}
  defp normalize_tuple({tb, lr}), do: {tb, lr, tb, lr}
  defp normalize_tuple({t, lr, b}), do: {t, lr, b, lr}
  defp normalize_tuple({t, r, b, l}), do: {t, r, b, l}
  defp normalize_tuple(all), do: {all, all, all, all}

  def merge_tuples({nil, r, b, l}, {t, _r, _b, _l} = parent),
    do: merge_tuples({t, r, b, l}, parent)

  def merge_tuples({t, nil, b, l}, {_t, r, _b, _l} = parent),
    do: merge_tuples({t, r, b, l}, parent)

  def merge_tuples({t, r, nil, l}, {_t, _r, b, _l} = parent),
    do: merge_tuples({t, r, b, l}, parent)

  def merge_tuples({t, r, b, nil}, {_t, _r, _b, l} = parent),
    do: merge_tuples({t, r, b, l}, parent)

  def merge_tuples(child, _parent), do: child

  defp set_col_dimensions(data, {x, _y}, {width, _height}, col_opts) do
    widths =
      data
      |> calculate_widths()
      |> Enum.zip(Enum.map(col_opts, &Keyword.get(&1, :width)))
      |> Enum.zip(col_opts)
      |> Enum.map(fn
        {{flex_width, width}, col_opts} ->
          min_width = Keyword.get(col_opts, :min_width)
          max_width = Keyword.get(col_opts, :max_width)
          {flex_width, width, min_width, max_width}
      end)
      # First pass makes min/max width adjustments
      |> calculate_dimensions(width)
      # Second pass resizes cols without min/max widths
      |> calculate_dimensions(width)
      |> Enum.map(fn
        {width, nil, _, _} -> width
        {_, width, _, _} -> width
      end)

    # Make sure the total width distribution matches the expected width
    total_calculated = Enum.reduce(widths, 0, &(&1 + &2))

    widths =
      if total_calculated != width do
        Enum.map(widths, &(&1 / total_calculated * width))
      else
        widths
      end

    data
    |> set_widths(widths, x)
    |> set_spanning()
  end

  defp set_spanning([]), do: []

  defp set_spanning([row | rows]) do
    [span_cols(row) | set_spanning(rows)]
  end

  defp span_cols([]), do: []

  defp span_cols([{_content, col_opts} | _] = cols) do
    case Enum.split(cols, Keyword.get(col_opts, :colspan, 1)) do
      {[col], cols} ->
        [col | span_cols(cols)]

      {[{content, col_opts} | _tail] = spanned, cols} ->
        spanned_width =
          Enum.reduce(spanned, 0, fn {_, col_opts}, acc ->
            Keyword.get(col_opts, :width, 0) + acc
          end)

        [{content, Keyword.put(col_opts, :width, spanned_width)} | span_cols(cols)]
    end
  end

  defp calculate_dimensions(widths, width) do
    total_fixed =
      Enum.reduce(widths, 0, fn
        {_, nil, _, _}, acc -> acc
        {_, width, _, _}, acc -> width + acc
      end)

    available_width = width - total_fixed

    total_flexible =
      Enum.reduce(widths, 0, fn
        {width, nil, _, _}, acc -> width + acc
        _, acc -> acc
      end)

    widths
    |> Enum.map(fn
      {width, nil, min_width, max_width} ->
        calculated_width = width / total_flexible * available_width

        adjusted_width =
          if min_width && min_width > calculated_width, do: min_width, else: calculated_width

        adjusted_width =
          if max_width && max_width < adjusted_width, do: max_width, else: adjusted_width

        if adjusted_width != calculated_width do
          {width, adjusted_width, min_width, max_width}
        else
          {calculated_width, nil, nil, nil}
        end

      width ->
        width
    end)
  end

  defp set_widths([], _widths, _x), do: []

  defp set_widths([row | rows], widths, x) do
    {row, _} =
      row
      |> Enum.zip(widths)
      |> Enum.map_reduce(x, fn {{col, col_opts}, width}, x ->
        {{col, Keyword.merge(col_opts, width: width, x: x)}, x + width}
      end)

    [row | set_widths(rows, widths, x)]
  end

  defp chunk_data(data, page, opts, row_opts) do
    row_count = length(data)

    row_opts =
      Enum.map(row_opts, fn
        {neg_idx, opts} when neg_idx < 0 -> {row_count + neg_idx, opts}
        {idx, opts} -> {idx, opts}
      end)
      |> Map.new()

    chunk_rows(data, 0, page, opts, row_opts)
  end

  defp chunk_rows([], _row_index, _page, _opts, _row_opts), do: []

  defp chunk_rows([row | rows], row_index, page, opts, row_opts) do
    row_even_odd_style = Map.get(row_opts, if(rem(row_index, 2) == 0, do: :even, else: :odd), [])
    row_index_style = Map.get(row_opts, row_index, [])
    row_style = Keyword.merge(row_even_odd_style, row_index_style)

    row = merge_col_opts(row, Keyword.get(opts, :cols, []), opts, row_style)

    [chunk_cols(row, page) | chunk_rows(rows, row_index + 1, page, opts, row_opts)]
  end

  defp chunk_cols([], _page), do: []

  defp chunk_cols([col | cols], page) do
    [chunk_col(col, page) | chunk_cols(cols, page)]
  end

  defp chunk_col({content, col_opts}, page) do
    chunked =
      content
      |> Page.annotate_attributed_text(page, col_opts)
      |> Text.chunk_attributed_text(col_opts)

    {chunked, col_opts}
  end

  defp fix_column_options(num_cols, opts) do
    col_opts = Keyword.get(opts, :cols, [])
    num_col_opts = length(col_opts)

    col_opts =
      if num_col_opts >= num_cols do
        col_opts
      else
        col_opts ++ Enum.map(1..(num_cols - num_col_opts), fn _ -> [] end)
      end

    {Keyword.put(opts, :cols, col_opts), col_opts}
  end

  defp merge_col_opts(cols, col_opts, opts, row_opts) do
    {row_opts, row_col_opts} = fix_column_options(length(cols), row_opts)

    row_opts = Keyword.drop(row_opts, [:cols])

    [cols, col_opts, row_col_opts]
    |> Enum.zip()
    |> Enum.map(fn {col, col_opts, row_col_opts} ->
      col_opts =
        opts
        |> Keyword.drop([:cols, :rows])
        |> Keyword.merge(col_opts)
        |> Keyword.merge(row_opts)
        |> Keyword.merge(row_col_opts)

      {col, col_opts}
    end)
  end

  defp calculate_widths(data) do
    data
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn
        {[], _col_opts} ->
          0

        {col, _col_opts} ->
          col
          |> Enum.map(fn {_, width, col_opts} ->
            {_, pr, _, pl} = padding(col_opts)
            width + pr + pl
          end)
          |> Enum.max()
      end)
    end)
    |> Enum.zip()
    # TODO: I don't know how efficient it is to work with tuples and back to lists
    #   It may be good to do a zip/1 that returns a list of lists again
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(&Enum.max/1)
  end

  defp draw_table(page, _xy, _wh, [], _opts), do: {page, []}

  defp draw_table(page, {x, y}, {w, h}, [head | tail], opts) do
    {row, overflow} =
      head
      |> Enum.map(fn {col, col_opts} ->
        {_, pr, _, pl} = padding(col_opts)
        width = Keyword.get(col_opts, :width) - pr - pl

        lines = Text.wrap_all_chunks(col, width)

        {lines, overflow} =
          if Keyword.get(opts, :allow_row_overflow, false) do
            overflow_lines(lines, h)
          else
            {lines, []}
          end

        height =
          Enum.reduce(lines, 0, fn {:line, line}, acc ->
            line_height = Enum.max(Enum.map(line, &Keyword.get(elem(&1, 2), :height)))
            line_height + acc
          end)

        {{lines, Keyword.put(col_opts, :height, height)}, {overflow, col_opts}}
      end)
      |> Enum.unzip()

    row_height = Enum.map(row, &col_height/1) |> Enum.max(&>=/2, fn -> 0 end)

    cond do
      # We have an overflow
      !Enum.all?(overflow, &Enum.empty?(elem(&1, 0))) ->
        page =
          page
          |> draw_row(y - row_height, row_height, row)
          |> Page.set_cursor(y - row_height)

        {page, [overflow | tail]}

      # No space for this row so we need to bail with {:continue, data}
      row_height > h ->
        {page, [head | tail]}

      true ->
        page =
          page
          |> draw_row(y - row_height, row_height, row)
          |> Page.set_cursor(y - row_height)

        draw_table(page, {x, y - row_height}, {w, h - row_height}, tail, opts)
    end
  end

  defp overflow_lines(lines, max_height) do
    filtered = filter_empty_lines(lines)

    {lines, overflow} =
      filtered
      |> Enum.map_reduce(0, fn {:line, line}, acc ->
        line_height = Enum.max(Enum.map(line, &Keyword.get(elem(&1, 2), :height)))
        {{:line, line, line_height + acc}, line_height + acc}
      end)
      |> elem(0)
      |> Enum.split_while(fn {:line, _line, height} -> height < max_height end)

    {
      Enum.map(lines, fn {:line, line, _} -> {:line, line} end),
      Enum.flat_map(overflow, fn {:line, line, _} -> line end)
    }
  end

  # Filter out empty lines
  defp filter_empty_lines(lines) do
    Enum.filter(lines, fn
      {:line, line} -> length(line) > 0
      _ -> false
    end)
  end

  defp draw_row(page, _y, _row_height, []), do: page

  defp draw_row(page, y, row_height, [{lines, col_opts} | tail]) do
    {pt, pr, pb, pl} = padding(col_opts)
    width = Keyword.get(col_opts, :width)
    x = Keyword.get(col_opts, :x)
    content_height = Keyword.get(col_opts, :height, 0)
    offset = valign_offset(valign(col_opts), row_height - pt - pb, content_height)

    {page, :complete} =
      page
      |> draw_background(lines, {x, y}, {width, row_height}, background(col_opts))
      |> Page.save_state()
      |> clip({x + pl, y + pb}, {width - pl - pr, row_height - pt - pb})
      |> Page.text_wrap(
        {x + pl, y + row_height - pt - offset},
        {width - pl - pr, row_height},
        lines,
        col_opts
      )

    border_color = Keyword.get(col_opts, :border_color)

    page
    |> Page.restore_state()
    |> draw_border({x, y}, {width, row_height}, border(col_opts), border_color)
    |> draw_row(y, row_height, tail)
  end

  defp draw_background(page, _lines, _xy, _wh, nil), do: page

  defp draw_background(page, _lines, {x, y}, {w, h}, color) do
    page
    |> Page.save_state()
    |> Page.rectangle({x, y}, {w, h})
    |> Page.set_fill_color(color)
    |> Page.fill()
    |> Page.restore_state()
  end

  defp clip(page, {x, y}, {w, h}) do
    page
    |> Page.rectangle({x, y}, {w, h})
    |> Page.clip()
  end

  defp draw_border(page, xy, wh, border, nil) do
    draw_border(page, xy, wh, border)
  end

  defp draw_border(page, xy, wh, border, border_color) do
    page
    |> Page.save_state()
    |> Page.set_stroke_color(border_color)
    |> draw_border(xy, wh, border)
    |> Page.restore_state()
  end

  defp draw_border(page, {x, y}, {w, h}, {bt, br, bb, bl} = border) do
    page
    |> draw_border_side({x, y}, {w, h}, :top, bt)
    |> draw_border_side({x, y}, {w, h}, :right, br)
    |> draw_border_side({x, y}, {w, h}, :bottom, bb)
    |> draw_border_side({x, y}, {w, h}, :left, bl)
    |> stroke_border(border)
  end

  defp stroke_border(page, {0, 0, 0, 0}), do: page
  defp stroke_border(page, _border), do: Page.stroke(page)

  defp draw_border_side(page, _xy, _wh, _side, 0), do: page

  defp draw_border_side(page, {x, y}, {w, h}, :top, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x + w, y + h})
  end

  defp draw_border_side(page, {x, y}, {w, h}, :right, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x + w, y + h}, {x + w, y})
  end

  defp draw_border_side(page, {x, y}, {w, _h}, :bottom, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y}, {x + w, y})
  end

  defp draw_border_side(page, {x, y}, {_w, h}, :left, width) do
    page
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x, y})
  end

  defp col_height({_, col_opts}), do: col_height_from_opts(col_opts)
  defp col_height({_, _, col_opts}), do: col_height_from_opts(col_opts)

  defp col_height_from_opts(col_opts) do
    {pt, _pr, pb, _pl} = padding(col_opts)
    height = Keyword.get(col_opts, :height)
    height + pt + pb
  end

  # Convert padding/border values to 4-tuples for use in calculations
  # This is used after merging, so nil values should be replaced with 0
  defp padding(nil), do: {0, 0, 0, 0}
  defp padding(opts) when is_list(opts), do: padding(Keyword.get(opts, :padding, 0))

  defp padding(value) do
    normalize_tuple(value)
  end

  defp border(nil), do: {0, 0, 0, 0}
  defp border(opts) when is_list(opts), do: border(Keyword.get(opts, :border, 0))
  defp border(value), do: normalize_tuple(value)

  defp background(opts) when is_list(opts), do: Keyword.get(opts, :background)

  defp valign(opts) when is_list(opts), do: Keyword.get(opts, :valign) || :top

  defp valign_offset(:top, _available_height, _content_height), do: 0

  defp valign_offset(:middle, available_height, content_height),
    do: max(available_height - content_height, 0) / 2

  defp valign_offset(:bottom, available_height, content_height),
    do: max(available_height - content_height, 0)

  defp valign_offset(valign, _available_height, _content_height) do
    raise(ArgumentError, "invalid :valign #{inspect(valign)}, expected :top, :middle or :bottom")
  end
end
