defmodule Pdf.Table do
  @moduledoc false
  alias Pdf.{Page, Text}
  alias __MODULE__
  alias Table.{Row, Cell, Column}

  @text_styling_options [:color, :font_size, :bold, :italic, :kerning]

  @derive {Inspect,
           optional: [
             :rows,
             :columns,
             :repeat_header,
             :allow_row_overflow,
             :full_width,
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
              :full_width,
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
          full_width: boolean() | nil,
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

  def new([{_key, _value} | _opts] = opts) do
    new([], opts)
  end

  def new(rows) do
    new(rows, [])
  end

  def new(rows, opts) do
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
      columns: columns,
      full_width: true
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
      {page, :complete}
    else
      do_render(page, {x, y}, {w, h}, table)
    end
  end

  defp do_render(page, {x, y}, {w, h}, %Table{rows: rows, columns: columns} = table) do
    x_starts = columns_to_x_starts(columns)

    # First pass: Calculate row heights and determine which rows fit
    {rows_to_render, remaining_rows, total_height} =
      calculate_rows_to_render(page, {w, h}, rows, table, x_starts)

    # Second pass: Collect consecutive rows that have keep_with_previous: true
    {rows_to_render, remaining_rows, total_height} =
      collect_keep_with_previous_rows(rows_to_render, remaining_rows, total_height)

    # Determine bottom of visible table area
    table_bottom_y = y - total_height

    render_width =
      if table.full_width == false,
        do: calculate_total_width(x_starts),
        else: w

    # Third pass: Render the rows using pre-calculated heights
    page =
      page
      |> render_rows({x, y}, rows_to_render, table, x_starts)
      |> draw_background_and_border(
        {x, table_bottom_y},
        {render_width, total_height},
        table.background,
        table.border,
        table.border_color
      )

    if Enum.empty?(remaining_rows) do
      {page, :complete}
    else
      repeat_rows = table.repeat_header || 0
      header_rows = Enum.take(rows, repeat_rows)
      remaining_table = %{table | rows: header_rows ++ remaining_rows}
      {page, {:continue, remaining_table}}
    end
  end

  defp collect_keep_with_previous_rows(
         rows_to_render,
         [%Row{keep_with_previous: true} | _] = remaining_rows,
         total_height
       ) do
    rows_to_render = Enum.reverse(rows_to_render)

    {keep_rows, [keep_one | rows_to_render]} =
      Enum.split_while(rows_to_render, fn row -> row.keep_with_previous end)

    keep_rows = Enum.reverse(keep_rows ++ [keep_one])
    rows_to_render = Enum.reverse(rows_to_render)

    total_height =
      Enum.reduce(keep_rows, total_height, fn row, acc ->
        acc - (row.calculated_height || 0)
      end)

    {rows_to_render, keep_rows ++ remaining_rows, total_height}
  end

  defp collect_keep_with_previous_rows(rows_to_render, remaining_rows, total_height) do
    {rows_to_render, remaining_rows, total_height}
  end

  # First pass: Calculate row heights and determine which rows fit
  defp calculate_rows_to_render(_page, {_w, h}, rows, table, x_starts) do
    calculate_rows_to_render_rec(rows, [], h, table, x_starts, 0)
  end

  defp calculate_rows_to_render_rec([], acc_rows, _remaining_h, _table, _x_starts, total_height) do
    {Enum.reverse(acc_rows), [], total_height}
  end

  defp calculate_rows_to_render_rec(
         [row | tail],
         acc_rows,
         remaining_h,
         table,
         x_starts,
         acc_height
       ) do
    # Filter out nil cells
    cells = Enum.reject(row.cells || [], &is_nil/1)

    # Calculate row height and overflow
    {cell_heights, overflow_cells} =
      calculate_row_metrics(nil, remaining_h, cells, table, x_starts)

    row_height = Enum.max(cell_heights, fn -> 0 end)

    cond do
      # Row doesn't fit - this row and all following rows are remaining
      row_height > remaining_h ->
        {Enum.reverse(acc_rows), [row | tail], acc_height}

      # We have overflow - this row is partially rendered
      Enum.any?(overflow_cells, &(&1 != nil)) ->
        # Store calculated height on the row
        row_with_height = Map.put(row, :calculated_height, row_height)
        overflow_row = %Row{cells: Enum.reverse(overflow_cells)}

        {Enum.reverse([row_with_height | acc_rows]), [overflow_row | tail],
         acc_height + row_height}

      true ->
        # Store calculated height on the row
        row_with_height = Map.put(row, :calculated_height, row_height)

        calculate_rows_to_render_rec(
          tail,
          [row_with_height | acc_rows],
          remaining_h - row_height,
          table,
          x_starts,
          acc_height + row_height
        )
    end
  end

  # Second pass: Render rows using pre-calculated heights
  defp render_rows(page, {x, y}, rows, table, x_starts) do
    {final_page, _final_y} =
      Enum.reduce(rows, {page, y}, fn row, {page_acc, current_y} ->
        row_height = Map.get(row, :calculated_height) || 0
        cells = Enum.reject(row.cells || [], &is_nil/1)
        draw_y = current_y - row_height

        # Draw the row using pre-calculated height
        # We need width for row background - calculate from x_starts
        total_width = calculate_total_width(x_starts)

        page =
          draw_row(
            page_acc,
            {x, draw_y},
            {total_width, row_height},
            row,
            cells,
            table,
            x_starts,
            row_height
          )

        page = Page.set_cursor(page, draw_y)

        {page, draw_y}
      end)

    final_page
  end

  defp calculate_total_width(x_starts) do
    tuple_size = tuple_size(x_starts)

    if tuple_size > 0 do
      elem(x_starts, tuple_size - 1)
    else
      0
    end
  end

  defp calculate_row_metrics(_page, height, cells, table, x_starts) do
    {heights, overflows, _idx} =
      Enum.reduce(cells, {[], [], 0}, fn cell, {heights_acc, overflow_acc, col_idx} ->
        colspan = cell.colspan || 1
        {pt, pr, pb, pl} = cell.padding
        cell_width = calculate_cell_width(x_starts, col_idx, colspan)
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

  defp draw_row(page, {x, y}, {w, h}, %Row{} = row, cells, table, x_starts, row_height) do
    # Draw row background and border (covering the entire row width)
    page =
      draw_background_and_border(
        page,
        {x, y},
        {w, row_height},
        row.background,
        row.border,
        row.border_color
      )

    # Draw cells
    Enum.reduce(cells, {page, 0}, fn cell, {page_acc, col_idx} ->
      colspan = cell.colspan || 1

      cell_x = calculate_cell_x(x_starts, col_idx, x)
      cell_width = calculate_cell_width(x_starts, col_idx, colspan)
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

    # Draw cell background and border
    page =
      draw_background_and_border(
        page,
        {x, y},
        {width, height},
        cell.background,
        cell.border,
        cell.border_color
      )

    page =
      page
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

  # x_starts: tuple of prefix sums [0, w0, w0+w1, ...] for O(1) cell position/width
  defp calculate_cell_x(x_starts, col_idx, base_x) do
    base_x + elem(x_starts, col_idx)
  end

  defp calculate_cell_width(x_starts, col_idx, colspan) do
    elem(x_starts, col_idx + colspan) - elem(x_starts, col_idx)
  end

  defp columns_to_x_starts(columns) do
    [0 | Enum.scan(Enum.map(columns, fn c -> c.width || 0 end), &+/2)]
    |> List.to_tuple()
  end

  defp determine_columns(%Table{columns: nil} = table) do
    num_cols =
      table.rows
      |> Enum.map(fn %Row{cells: cells} ->
        Enum.reduce(cells, 0, fn cell, acc -> acc + (cell.colspan || 1) end)
      end)
      |> Enum.max(fn -> 0 end)

    Enum.map(1..num_cols//1, fn _ -> Column.new() end)
  end

  defp determine_columns(%Table{columns: columns}), do: columns

  defp prepare_row(page, %Row{cells: cells} = row, table, columns) do
    prepared_cells =
      columns
      |> zip_with_cells(Enum.reverse(cells))
      |> Enum.map(fn {column, cell} ->
        prepare_cell(page, cell, table, row, column)
      end)

    %{row | cells: prepared_cells}
  end

  defp prepare_cell(page, %Cell{data: data} = cell, table, row, %Column{} = column) do
    cell =
      cell
      |> Cell.inherit_options(row)
      |> Cell.inherit_options(column)
      |> Cell.inherit_options(table)

    opts = Cell.text_opts(cell)

    chunks =
      data
      |> Page.annotate_attributed_text(page, opts)
      |> Text.chunk_attributed_text(opts)

    %{cell | chunks: chunks}
  end

  defp zip_with_cells([], []), do: []

  # Ignore hidden columns (with a single span or no colspan)
  defp zip_with_cells([%Column{hide: true} | columns], [%Cell{colspan: colspan} | cells])
       when is_nil(colspan) or colspan == 1 do
    zip_with_cells(columns, cells)
  end

  defp zip_with_cells([%Column{hide: true} | columns], [%Cell{colspan: colspan} | cells])
       when is_integer(colspan) and colspan > 1 do
    # We need to drop this cell and insert nil columns for the spans
    nil_cells = Enum.map(1..(colspan - 1)//1, fn _ -> Cell.new(nil) end)
    zip_with_cells(columns, nil_cells ++ cells)
  end

  # If there are more columns than cells, create cells with nil data
  defp zip_with_cells([%Column{} = column | columns], []) do
    [{column, Cell.new(nil)} | zip_with_cells(columns, [])]
  end

  # If the cell has a colspan, drop the columns that are covered by the colspan
  defp zip_with_cells([%Column{} = column | columns], [%Cell{colspan: colspan} = cell | cells])
       when is_integer(colspan) and colspan > 1 do
    {spanned_columns, columns} = Enum.split(columns, colspan - 1)
    hidden_count = Enum.count(spanned_columns, & &1.hide)
    cell = %{cell | colspan: colspan - hidden_count}
    [{column, cell} | zip_with_cells(columns, cells)]
  end

  defp zip_with_cells([%Column{} = column | columns], [%Cell{} = cell | cells]) do
    [{column, cell} | zip_with_cells(columns, cells)]
  end

  defp calculate_column_widths([], columns, _total_width, _table), do: columns
  defp calculate_column_widths(_rows, [], _total_width, _table), do: []

  defp calculate_column_widths(rows, columns, total_width, table) do
    # Calculate content widths for each column
    # For each row, create a list of column widths (handling colspan)
    # We need table context for padding inheritance
    column_width_lists =
      rows
      |> Enum.map(fn %Row{} = row ->
        calculate_row_column_widths(row, table, 0) |> List.flatten()
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
    full_width = table.full_width != false
    distribute_column_widths(columns, total_width, full_width)
  end

  defp calculate_row_column_widths(%Row{cells: []}, _table, _col_idx), do: []

  defp calculate_row_column_widths(%Row{cells: [cell | tail]} = row, table, col_idx) do
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
      | calculate_row_column_widths(%Row{row | cells: tail}, table, col_idx + colspan)
    ]
  end

  # Treats width (percentage/fixed) as suggestions and calculated_min_width and max_width as hard constraints.
  # Uses a combined spec (%{col, width, min, max}) through the pipeline to avoid zipping and index lookups.
  def distribute_column_widths(columns, total_width), do: distribute_column_widths(columns, total_width, true)

  def distribute_column_widths(columns, total_width, true) do
    # Phase 1: Build specs with initial width from column suggestions
    specs =
      Enum.map(columns, fn col ->
        width = initial_width_from_column(col, total_width)
        max_width = col.max_width || :infinity
        %{col: col, width: width, min: col.calculated_min_width || 0, max: max_width}
      end)

    # For columns with nil width (no suggestion), distribute remaining space equally
    {suggested_total, nil_count} =
      Enum.reduce(specs, {0, 0}, fn s, {total, cnt} ->
        if is_nil(s.width), do: {total, cnt + 1}, else: {total + s.width, cnt}
      end)

    specs =
      if nil_count > 0 do
        remaining = max(0, total_width - suggested_total)
        equal_width = if remaining > 0, do: remaining / nil_count, else: 0

        Enum.map(specs, fn s ->
          if is_nil(s.width), do: %{s | width: equal_width}, else: s
        end)
      else
        specs
      end

    # Phase 2: Iterative proportional scaling
    specs = scale_to_fit(specs, total_width)

    specs_to_columns(specs)
  end

  def distribute_column_widths(columns, total_width, false) do
    specs =
      Enum.map(columns, fn col ->
        suggested = initial_width_from_column(col, total_width)
        min = col.calculated_min_width || 0
        max_width = col.max_width || :infinity

        width =
          if is_nil(suggested) do
            min
          else
            max(suggested, min)
          end

        %{col: col, width: width, min: min, max: max_width}
      end)

    specs = scale_to_fit(specs, total_width, allow_grow: false)

    specs_to_columns(specs)
  end

  defp specs_to_columns(specs) do
    Enum.map(specs, fn s ->
      rounded_width = if is_float(s.width), do: Float.round(s.width, 3), else: s.width
      %{s.col | width: rounded_width}
    end)
  end

  defp initial_width_from_column(col, total_width) do
    case col.width do
      pct when is_float(pct) and pct > 0 and pct <= 1 -> pct * total_width
      fixed when is_number(fixed) and fixed > 1 -> fixed
      _ -> nil
    end
  end

  defp scale_to_fit(specs, total_width, opts \\ []) do
    allow_grow = Keyword.get(opts, :allow_grow, true)
    scale_to_fit_iter(specs, total_width, 0, allow_grow)
  end

  defp scale_to_fit_iter(specs, total_width, iteration, allow_grow) do
    if iteration >= 10 do
      specs
    else
      # Ensure each spec meets min width and doesn't exceed max width
      specs =
        Enum.map(specs, fn s ->
          constrained_width = max(s.width, s.min)

          max_val =
            if s.max == :infinity, do: constrained_width, else: min(constrained_width, s.max)

          %{s | width: max_val}
        end)

      total = Enum.sum(Enum.map(specs, & &1.width))

      cond do
        # Total matches exactly - we're done
        abs(total - total_width) < 0.01 ->
          specs

        # Total is less than target - scale up proportionally (unless shrink-only)
        total < total_width and allow_grow ->
          # Scale up proportionally, excluding columns at maximum width
          {scalable, fixed_map} =
            specs
            |> Enum.with_index()
            |> Enum.reduce({[], %{}}, fn {spec, idx}, {scal_acc, fix_acc} ->
              at_max = spec.max != :infinity and spec.width >= spec.max - 0.01

              if at_max do
                {scal_acc, Map.put(fix_acc, idx, spec.width)}
              else
                {[{spec, idx} | scal_acc], fix_acc}
              end
            end)

          if length(scalable) == 0 do
            # All columns are at max_width - can't scale up further
            specs
          else
            # Calculate how much we need to grow
            fixed_total = Enum.reduce(fixed_map, 0, fn {_idx, w}, acc -> acc + w end)
            available_for_scalable = total_width - fixed_total

            if available_for_scalable <= 0 do
              # No space to scale up - return as is
              specs
            else
              scalable_total =
                Enum.reduce(scalable, 0, fn {spec, _idx}, acc -> acc + spec.width end)

              scale_factor = available_for_scalable / scalable_total

              # Apply scaling to scalable columns
              scaled_map =
                Enum.reduce(scalable, %{}, fn {spec, idx}, acc ->
                  scaled = spec.width * scale_factor
                  constrained_width = max(scaled, spec.min)

                  max_val =
                    if spec.max == :infinity,
                      do: constrained_width,
                      else: min(constrained_width, spec.max)

                  Map.put(acc, idx, max_val)
                end)

              new_specs =
                Enum.map(Enum.with_index(specs), fn {spec, idx} ->
                  w =
                    cond do
                      Map.has_key?(fixed_map, idx) -> Map.get(fixed_map, idx)
                      Map.has_key?(scaled_map, idx) -> Map.get(scaled_map, idx)
                      true -> spec.width
                    end

                  %{spec | width: w}
                end)

              scale_to_fit_iter(new_specs, total_width, iteration + 1, allow_grow)
            end
          end

        total < total_width ->
          specs

        # Total is greater than target - scale down proportionally
        true ->
          # Scale down proportionally, excluding columns at minimum width or maximum width
          {scalable, fixed_map} =
            specs
            |> Enum.with_index()
            |> Enum.reduce({[], %{}}, fn {spec, idx}, {scal_acc, fix_acc} ->
              at_min = spec.width <= spec.min + 0.01
              at_max = spec.max != :infinity and spec.width >= spec.max - 0.01

              if at_min or at_max do
                {scal_acc, Map.put(fix_acc, idx, spec.width)}
              else
                {[{spec, idx} | scal_acc], fix_acc}
              end
            end)

          if length(scalable) == 0 do
            min_total = total

            if min_total > total_width do
              raise "Impossible constraint: sum of calculated_min_widths (#{min_total}) exceeds total_width (#{total_width})"
            end

            specs
          else
            # Calculate how much we need to shrink
            fixed_total = Enum.reduce(fixed_map, 0, fn {_idx, w}, acc -> acc + w end)
            available_for_scalable = total_width - fixed_total

            if available_for_scalable <= 0 do
              # No space for scalable columns - set them to minimum; return (no recurse)
              Enum.map(Enum.with_index(specs), fn {spec, idx} ->
                w = if Map.has_key?(fixed_map, idx), do: Map.get(fixed_map, idx), else: spec.min
                %{spec | width: w}
              end)
            else
              scalable_total =
                Enum.reduce(scalable, 0, fn {spec, _idx}, acc -> acc + spec.width end)

              scale_factor = available_for_scalable / scalable_total

              # Apply scaling to scalable columns
              scaled_map =
                Enum.reduce(scalable, %{}, fn {spec, idx}, acc ->
                  scaled = spec.width * scale_factor
                  constrained_width = max(scaled, spec.min)

                  max_val =
                    if spec.max == :infinity,
                      do: constrained_width,
                      else: min(constrained_width, spec.max)

                  Map.put(acc, idx, max_val)
                end)

              new_specs =
                Enum.map(Enum.with_index(specs), fn {spec, idx} ->
                  w =
                    cond do
                      Map.has_key?(fixed_map, idx) -> Map.get(fixed_map, idx)
                      Map.has_key?(scaled_map, idx) -> Map.get(scaled_map, idx)
                      true -> spec.width
                    end

                  %{spec | width: w}
                end)

              scale_to_fit_iter(new_specs, total_width, iteration + 1, allow_grow)
            end
          end
      end
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

  defp draw_border(page, _xy, _wh, 0, _border_color), do: page
  defp draw_border(page, _xy, _wh, {0, 0, 0, 0}, _border_color), do: page

  defp draw_border(page, xy, wh, border, border_color)
       when is_nil(border_color) or border_color == {nil, nil, nil, nil} do
    page
    |> draw_border_box(xy, wh, border, border_color)
  end

  defp draw_border(page, xy, wh, border, border_color) do
    page
    |> Page.save_state()
    |> draw_border_box(xy, wh, border, border_color)
    |> Page.restore_state()
  end

  defp draw_border_box(page, {x, y}, {w, h}, border, border_color) do
    {bt, br, bb, bl} = Cell.normalize_perimeter_tuple(border)
    {tc, tr, tb, tl} = Cell.normalize_perimeter_tuple(border_color, nil)

    page
    |> draw_border_side({x, y}, {w, h}, :top, bt, tc)
    |> draw_border_side({x, y}, {w, h}, :right, br, tr)
    |> draw_border_side({x, y}, {w, h}, :bottom, bb, tb)
    |> draw_border_side({x, y}, {w, h}, :left, bl, tl)
  end

  defp draw_border_side(page, _xy, _wh, _side, 0, _color), do: page

  defp draw_border_side(page, {x, y}, {w, h}, :top, width, color) do
    page
    |> set_stroke_color(color)
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x + w, y + h})
    |> Page.stroke()
  end

  defp draw_border_side(page, {x, y}, {w, h}, :right, width, color) do
    page
    |> set_stroke_color(color)
    |> Page.set_line_width(width)
    |> Page.line({x + w, y + h}, {x + w, y})
    |> Page.stroke()
  end

  defp draw_border_side(page, {x, y}, {w, _h}, :bottom, width, color) do
    page
    |> set_stroke_color(color)
    |> Page.set_line_width(width)
    |> Page.line({x, y}, {x + w, y})
    |> Page.stroke()
  end

  defp draw_border_side(page, {x, y}, {_w, h}, :left, width, color) do
    page
    |> set_stroke_color(color)
    |> Page.set_line_width(width)
    |> Page.line({x, y + h}, {x, y})
    |> Page.stroke()
  end

  defp set_stroke_color(page, nil), do: page

  defp set_stroke_color(page, color) do
    Page.set_stroke_color(page, color)
  end

  defp draw_background_and_border(page, {x, y}, {w, h}, background, border, border_color) do
    page
    |> draw_background(nil, {x, y}, {w, h}, background)
    |> draw_border({x, y}, {w, h}, border, border_color)
  end
end
