defmodule Pdf.Table do
  @moduledoc false
  alias Pdf.{Page, Text}
  alias Pdf.Table.{Table, Row, Cell, Column}

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

  @doc """
  Prepares a table for rendering.
  During preparation:
    - the table data is chunked into attributed text
    - inherited options are merged
    - column widths are calculated and distributed

  ## Parameters
  - `page`: The page to prepare the table for
  - `table`: The table to prepare
  - `width`: The width of the table in points

  """
  def prepare(page, %Table{} = table, width) do
    # Generate or use existing columns
    columns = determine_columns(table)

    # Chunk cell data and merge options
    prepared_rows =
      table.rows
      # We are now reversing rows so they are the correct order for rendering
      |> Enum.reduce([], fn row, acc ->
        [prepare_row(page, row, table, columns) | acc]
      end)

    # Calculate column widths
    columns = calculate_column_widths(prepared_rows, columns, width, table)

    %{table | rows: prepared_rows, columns: columns}
  end

  @doc """
  Renders a prepared table.

  ## Parameters
  - `page`: The page to render the table on
  - `{x, y}`: The position of the table on the page in points
  - `{w, h}`: The allowed width and height of the table in points
  - `%Table{} = table`: The prepared table to render

  ## Returns
  - `{page, :complete}`: The table was fully rendered
  - `{page, {:continue, %Table{}}}`: The table was partially rendered, and the table struct is updated with the remaining table data.
  """
  def render(page, {x, :cursor}, {w, h}, %Table{} = table) do
    render(page, {x, Page.cursor(page)}, {w, h}, table)
  end

  def render(page, {x, :cursor}, {w, h}, {:continue, %Table{} = table}) do
    render(page, {x, Page.cursor(page)}, {w, h}, table)
  end

  def render(page, {x, y}, {w, h}, %Table{} = table) do
    if Enum.empty?(table.rows) do
      {page, []}
    else
      do_render(page, {x, y}, {w, h}, table)
    end
  end

  defp do_render(page, {x, y}, {w, h}, %Table{rows: rows, columns: columns} = table) do
    case render_rows(page, {x, y}, {w, h}, rows, table, columns, []) do
      {page, []} ->
        {page, :complete}

      {page, remaining} ->
        repeat_rows = table.repeat_header || 0
        header_rows = Enum.take(rows, repeat_rows)
        remaining_table = %{table | rows: header_rows ++ remaining}
        {page, {:continue, remaining_table}}
    end
  end

  defp render_rows(page, _xy, _wh, [], _table, _columns, _acc), do: {page, []}

  defp render_rows(page, {x, y}, {w, h}, [row | tail], table, columns, acc) do
    {page, row_height, overflow_row} = render_row(page, {x, y}, {w, h}, row, table, columns)

    cond do
      # Row doesn't fit in remaining height
      row_height > h ->
        {page, [row | tail] ++ acc}

      # We have overflow
      overflow_row != nil ->
        {page, [overflow_row | tail] ++ acc}

      true ->
        render_rows(page, {x, y - row_height}, {w, h - row_height}, tail, table, columns, acc)
    end
  end

  defp render_row(page, {x, y}, {w, h}, %Row{cells: cells}, table, columns) do
    # Filter out nil cells (from overflow)
    cells = Enum.reject(cells, &is_nil/1)

    # Calculate row height and overflow first
    {cell_heights, overflow_cells} =
      calculate_row_metrics(page, h, cells, table, columns)

    row_height = Enum.max(cell_heights, fn -> 0 end)
    # Draw at y - row_height (top of row, like existing code)
    draw_y = y - row_height

    # Now draw cells at correct position (only non-nil cells)
    page = draw_row(page, {x, draw_y}, {w, h}, cells, table, columns, row_height)

    page = Page.set_cursor(page, draw_y)

    # Reconstruct overflow row (overflow_cells are already in correct order)
    overflow_row =
      if Enum.any?(overflow_cells, &(&1 != nil)),
        do: %Row{cells: Enum.reverse(overflow_cells)},
        else: nil

    {page, row_height, overflow_row}
  end

  defp calculate_row_metrics(_page, height, cells, table, columns) do
    {heights, overflows, _idx} =
      Enum.reduce(cells, {[], [], 0}, fn cell, {heights_acc, overflow_acc, col_idx} ->
        colspan = cell.colspan || 1
        {pt, pr, pb, pl} = cell.padding
        cell_width = calculate_cell_width(columns, col_idx, colspan)
        text_width = cell_width - pr - pl

        # Wrap text and handle overflow
        {lines, overflow} = wrap_cell_text(cell.chunks || [], text_width, table, height)

        # Calculate content height
        content_height = calculate_content_height(lines)

        # Cell height includes padding
        cell_height = content_height + pt + pb

        overflow_cell = if Enum.empty?(overflow), do: nil, else: %{cell | chunks: overflow}

        {[cell_height | heights_acc], [overflow_cell | overflow_acc], col_idx + colspan}
      end)

    {Enum.reverse(heights), overflows}
  end

  defp draw_row(page, {x, y}, {_w, h}, cells, table, columns, row_height) do
    Enum.reduce(cells, {page, 0}, fn cell, {page_acc, col_idx} ->
      colspan = cell.colspan || 1

      cell_x = calculate_cell_x(columns, col_idx, x)
      cell_width = calculate_cell_width(columns, col_idx, colspan)
      {_pt, pr, _pb, pl} = cell.padding
      text_width = cell_width - pr - pl

      # Wrap text and handle overflow (same logic as calculate_row_metrics)
      {lines, _overflow} = wrap_cell_text(cell.chunks || [], text_width, table, h)

      # Row height already includes padding from calculate_row_metrics
      page = draw_cell(page_acc, {cell_x, y}, cell_width, row_height, cell, lines)

      {page, col_idx + colspan}
    end)
    |> elem(0)
  end

  defp draw_cell(page, {x, y}, width, height, cell, lines) do
    {pt, pr, pb, pl} = cell.padding
    bg_color = cell.background
    border_val = cell.border
    border_color = cell.border_color

    page =
      page
      |> draw_background(lines, {x, y}, {width, height}, bg_color)
      |> Page.save_state()
      |> clip({x + pl, y + pb}, {width - pl - pr, height - pt - pb})

    {page, _} =
      if Enum.empty?(lines) do
        {page, :complete}
      else
        non_empty_lines = filter_empty_lines(lines)

        if Enum.empty?(non_empty_lines) do
          {page, :complete}
        else
          Page.text_wrap(
            page,
            {x + pl, y + height - pt},
            {width - pl - pr, height},
            non_empty_lines,
            extract_text_opts(cell)
          )
        end
      end

    page
    |> Page.restore_state()
    |> draw_border({x, y}, {width, height}, border_val, border_color)
  end

  defp extract_text_opts(%Cell{} = cell) do
    [
      font_size: cell.font_size,
      bold: cell.bold,
      italic: cell.italic,
      align: cell.align,
      kerning: cell.kerning,
      color: cell.color
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  # Wrap cell text and handle overflow
  defp wrap_cell_text(chunks, text_width, table, max_height) do
    lines = Text.wrap_all_chunks(chunks, text_width)
    filtered = filter_empty_lines(lines)

    if table.allow_row_overflow do
      overflow_lines(filtered, max_height)
    else
      {filtered, []}
    end
  end

  # Filter out empty lines
  defp filter_empty_lines(lines) do
    Enum.filter(lines, fn
      {:line, line} -> length(line) > 0
      _ -> false
    end)
  end

  # Calculate content height from lines
  defp calculate_content_height(lines) do
    if Enum.empty?(lines) do
      0
    else
      Enum.reduce(lines, 0, fn {:line, line}, acc ->
        if Enum.empty?(line) do
          acc
        else
          line_height = Enum.max(Enum.map(line, &Keyword.get(elem(&1, 2), :height, 0)))
          line_height + acc
        end
      end)
    end
  end

  defp calculate_cell_x(columns, col_idx, base_x) do
    columns
    |> Enum.slice(0, col_idx)
    |> Enum.reduce(base_x, fn col, acc -> acc + (col.width || 0) end)
  end

  defp calculate_cell_width(columns, col_idx, colspan) do
    columns
    |> Enum.slice(col_idx, colspan)
    |> Enum.reduce(0, fn col, acc -> acc + (col.width || 0) end)
  end

  defp merge_cell_options_for_prepare(
         %Table{} = table,
         %Row{} = row,
         %Cell{} = cell,
         columns,
         col_idx
       ) do
    default_opts = [padding: {0, 0, 0, 0}, border: {0, 0, 0, 0}]
    # Start with table options
    table_opts = struct_to_opts(table) |> Keyword.drop([:rows, :columns])

    # Merge row options
    row_opts = struct_to_opts(row) |> Keyword.drop([:cells])

    # Merge column options
    column = Enum.at(columns, col_idx, %Column{})
    column_opts = struct_to_opts(column)

    # Merge cell options
    cell_opts =
      struct_to_opts(cell)
      |> Keyword.drop([:data, :chunks, :colspan])

    # Merge with inheritance: Cell > Row > Column > Table priority
    # Merge order: Table -> Column -> Row -> Cell
    default_opts
    |> merge_with_inheritance(table_opts)
    |> merge_with_inheritance(column_opts)
    |> merge_with_inheritance(row_opts)
    |> merge_with_inheritance(cell_opts)
  end

  defp merge_with_inheritance(parent, child) do
    # Child values override parent values, but nil values don't override
    # This allows inheritance: if child has nil, keep parent value
    # Special handling for :border - 0 values explicitly override parent
    # Special handling for :padding - nil values inherit from parent
    Enum.reduce(child, parent, fn {key, value}, acc ->
      cond do
        key == :border ->
          # Special border merging: nil inherits, 0 explicitly overrides
          merged_border = merge_borders(Keyword.get(acc, :border), value)
          Keyword.put(acc, key, merged_border)

        key == :padding ->
          # Special padding merging: nil values inherit from parent
          merged_padding = merge_padding(Keyword.get(acc, :padding), value)
          Keyword.put(acc, key, merged_padding)

        is_nil(value) ->
          acc

        true ->
          Keyword.put(acc, key, value)
      end
    end)
  end

  defp merge_borders(parent, child) do
    # Both are tuples - merge element by element
    merge_border_tuples(parent, child)
  end

  defp merge_border_tuples(parent, child) do
    # Normalize both to 4-tuples
    parent_norm = normalize_tuple(parent)
    child_norm = normalize_tuple(child)

    # Merge: child values (including 0) override parent
    merge_tuples(child_norm, parent_norm)
  end

  defp merge_padding(parent, child) do
    # Both are tuples - merge element by element
    merge_padding_tuples(parent, child)
  end

  defp merge_padding_tuples(parent, child) do
    # Normalize both to 4-tuples (allow nil for padding)
    parent_norm = normalize_tuple(parent)
    child_norm = normalize_tuple(child)

    # Merge: child values override parent, but nil in child inherits from parent
    merge_tuples(child_norm, parent_norm)
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

  defp struct_to_opts(struct) do
    struct
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Keyword.new()
  end

  defp determine_columns(%Table{columns: nil} = table) do
    num_cols =
      table.rows
      |> Enum.map(fn %Row{cells: cells} ->
        Enum.reduce(cells, 0, fn cell, acc -> acc + (cell.colspan || 1) end)
      end)
      |> Enum.max(fn -> 0 end)

    Enum.map(1..num_cols, fn _ -> Column.new() end)
  end

  defp determine_columns(%Table{columns: columns}), do: columns

  defp prepare_row(page, %Row{cells: cells} = row, table, columns) do
    prepared_cells =
      cells
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.map(fn {cell, col_idx} ->
        prepare_cell(page, cell, table, row, columns, col_idx)
      end)

    %{row | cells: prepared_cells}
  end

  # Only prepare cells that don't have chunks yet
  defp prepare_cell(page, %Cell{data: data, chunks: nil} = cell, table, row, columns, col_idx) do
    # Merge options for chunking
    merged_opts = merge_cell_options_for_prepare(table, row, cell, columns, col_idx)

    chunks =
      data
      |> Page.annotate_attributed_text(page, merged_opts)
      |> Text.chunk_attributed_text(merged_opts)

    # Store merged options in cell struct fields for consistent use during render
    cell = Cell.new(cell, merged_opts)
    %{cell | chunks: chunks}
  end

  defp prepare_cell(_page, %Cell{} = cell, _table, _row, _columns, _col_idx), do: cell

  defp calculate_column_widths(rows, columns, total_width, table) do
    # Calculate content widths for each column
    # For each row, create a list of column widths (handling colspan)
    # We need table context for padding inheritance
    column_width_lists =
      rows
      |> Enum.map(fn %Row{} = row ->
        calculate_row_column_widths(row, table, columns, 0) |> List.flatten()
      end)

    min_content_widths =
      column_width_lists
      |> Enum.zip()
      |> Enum.map(fn tuple -> tuple |> Tuple.to_list() |> Enum.max() end)

    columns =
      columns
      |> Enum.zip(min_content_widths)
      |> Enum.map(fn {column, width} ->
        %{column | calculated_min_width: Enum.max([width, column.min_width || 0])}
      end)

    # Use new width distribution algorithm
    # calculated_min_width is already set on columns
    # This treats width (percentage/fixed) as suggestions and calculated_min_width as hard constraint
    distribute_column_widths(columns, total_width)
  end

  defp calculate_row_column_widths(%Row{cells: []}, _table, _columns, _col_idx), do: []

  defp calculate_row_column_widths(%Row{cells: [cell | tail]} = row, table, columns, col_idx) do
    colspan = cell.colspan || 1

    # Use padding from cell struct (already merged during prepare)
    {_, pr, _, pl} = cell.padding

    # Calculate width for this cell's content
    cell_content_width =
      if cell.chunks do
        cell.chunks
        |> Enum.flat_map(fn
          {:line, line} -> line
          chunk when is_tuple(chunk) and tuple_size(chunk) == 3 -> [chunk]
          _ -> []
        end)
        |> Enum.map(fn {_, width, _} -> width + pr + pl end)
        |> Enum.max(fn -> 0 end)
      else
        0
      end

    widths =
      Enum.reduce(1..(colspan - 1)//1, [cell_content_width], fn _i, acc ->
        [0 | acc]
      end)

    [
      widths
      | calculate_row_column_widths(
          %Row{row | cells: tail},
          table,
          columns,
          col_idx + colspan
        )
    ]
  end

  # New width distribution algorithm
  # Treats width (percentage/fixed) as suggestions and calculated_min_width as hard constraint
  def distribute_column_widths(columns, total_width) do
    # Phase 1: Calculate initial widths from suggestions
    widths =
      Enum.map(columns, fn column ->
        case column.width do
          pct when is_float(pct) and pct > 0 and pct <= 1 ->
            # Percentage width: multiply by total_width
            pct * total_width

          fixed when is_number(fixed) and fixed > 1 ->
            # Fixed width: use as-is
            fixed

          _ ->
            # No suggestion: mark as nil for equal distribution
            nil
        end
      end)

    # For columns with nil width (no suggestion), distribute remaining space equally
    # This gives flexible columns a fair starting point
    {suggested_total, nil_count} =
      Enum.reduce(widths, {0, 0}, fn width, {total, nil_count} ->
        if is_nil(width) do
          {total, nil_count + 1}
        else
          {total + width, nil_count}
        end
      end)

    # Distribute remaining space equally among nil-width columns
    # But only if we have space remaining (suggested_total might exceed total_width, which will be handled by scaling)
    widths =
      if nil_count > 0 do
        remaining = max(0, total_width - suggested_total)
        equal_width = if remaining > 0, do: remaining / nil_count, else: 0

        Enum.map(widths, fn width ->
          if is_nil(width), do: equal_width, else: width
        end)
      else
        widths
      end

    # Phase 2: Iterative proportional scaling
    # Keep scaling until total <= total_width, excluding columns at minimum
    final_widths = scale_to_fit(widths, columns, total_width)

    columns
    |> Enum.zip(final_widths)
    |> Enum.map(fn {column, width} ->
      # Round to 3 decimal places for consistency
      rounded_width = if is_float(width), do: Float.round(width, 3), else: width
      %{column | width: rounded_width}
    end)
  end

  defp scale_to_fit(widths, columns, total_width) do
    scale_to_fit_iter(widths, columns, total_width, 0)
  end

  defp scale_to_fit_iter(widths, columns, total_width, iteration) do
    # Prevent infinite recursion (max 10 iterations should be enough)
    if iteration >= 10 do
      widths
    else
      # Ensure all columns meet calculated_min_width first
      widths =
        Enum.zip_with([widths, columns], fn [width, col] ->
          min_width = col.calculated_min_width || 0
          max(width, min_width)
        end)

      total = Enum.sum(widths)

      if total <= total_width do
        # Already fits
        widths
      else
        # Scale down proportionally, excluding columns at minimum
        # Build a list of {index, width, column} tuples to track positions
        indexed = Enum.with_index(Enum.zip(widths, columns))

        # Separate scalable and fixed columns
        {scalable, fixed_map} =
          Enum.reduce(indexed, {[], %{}}, fn {{width, col}, idx}, {scalable_acc, fixed_acc} ->
            min_width = col.calculated_min_width || 0
            # Add small epsilon to avoid floating point issues
            if width > min_width + 0.01 do
              {[{idx, width, col} | scalable_acc], fixed_acc}
            else
              {scalable_acc, Map.put(fixed_acc, idx, width)}
            end
          end)

        if length(scalable) == 0 do
          # All at minimum - check if exceeds total (error case)
          min_total = Enum.sum(widths)

          if min_total > total_width do
            raise "Impossible constraint: sum of calculated_min_widths (#{min_total}) exceeds total_width (#{total_width})"
          end

          widths
        else
          # Calculate how much we need to shrink
          fixed_total = Enum.reduce(fixed_map, 0, fn {_idx, width}, acc -> acc + width end)
          available_for_scalable = total_width - fixed_total

          if available_for_scalable <= 0 do
            # No space available for scalable columns - set them all to minimum
            Enum.map(0..(length(widths) - 1), fn idx ->
              if Map.has_key?(fixed_map, idx) do
                Map.get(fixed_map, idx)
              else
                col = Enum.at(columns, idx)
                col.calculated_min_width || 0
              end
            end)
          else
            scalable_total =
              Enum.reduce(scalable, 0, fn {_idx, width, _col}, acc -> acc + width end)

            scale_factor = available_for_scalable / scalable_total

            # Apply scaling to scalable columns
            scaled_map =
              Enum.reduce(scalable, %{}, fn {idx, width, _col}, acc ->
                scaled = width * scale_factor
                # Ensure scaled width doesn't go below minimum
                col = Enum.at(columns, idx)
                min_width = col.calculated_min_width || 0
                Map.put(acc, idx, max(scaled, min_width))
              end)

            # Rebuild widths list in original order
            new_widths =
              Enum.map(0..(length(widths) - 1), fn idx ->
                cond do
                  Map.has_key?(fixed_map, idx) -> Map.get(fixed_map, idx)
                  Map.has_key?(scaled_map, idx) -> Map.get(scaled_map, idx)
                  true -> Enum.at(widths, idx)
                end
              end)

            # Recursively check if we need another iteration
            scale_to_fit_iter(new_widths, columns, total_width, iteration + 1)
          end
        end
      end
    end
  end

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

  defp draw_row(page, _y, _row_height, []), do: page

  defp draw_row(page, y, row_height, [{lines, col_opts} | tail]) do
    {pt, pr, pb, pl} = padding(col_opts)
    width = Keyword.get(col_opts, :width)
    x = Keyword.get(col_opts, :x)

    {page, :complete} =
      page
      |> draw_background(lines, {x, y}, {width, row_height}, background(col_opts))
      |> Page.save_state()
      |> clip({x + pl, y + pb}, {width - pl - pr, row_height - pt - pb})
      |> Page.text_wrap(
        {x + pl, y + row_height - pt},
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
end
