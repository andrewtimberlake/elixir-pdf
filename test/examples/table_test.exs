defmodule Pdf.Examples.TableTest do
  use Pdf.Case, async: true

  @open true

  alias Pdf.Table
  alias Table.{Row, Cell, Column}

  test "" do
    data = [
      ["Header 1", "Header 2", "Header 3", "Header 4"],
      ["Col 1,1", "Col 1,2", "Col 1,3", "Col 1,4"],
      ["Col 2,1", "Column 2,2", "Col 2,3", "Col 2,4"],
      [nil, "mmmmmmmmmm", nil, "mmmmmmmmmmm"],
      ["Col 3,1", ["Column ", {"3,2", bold: true}], "Col 3,3", "Col 3,4"],
      ["Col 4,1 😅", "Column 4,2", "Col 4,3", "Col 4,4"],
      [nil, nil, "Col 5,3", "Col 5,4"]
    ]

    file_path = output("table.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    table_opts = [
      padding: 2,
      encoding_replacement_character: "?",
      background: :gainsboro,
      repeat_header: 1,
      italic: true,
      cols: [
        [width: 100, font_size: 8],
        [],
        [min_width: 30, background: :dark_gray, color: :white],
        [width: 80, align: :right, padding: {2, 4}]
      ],
      rows: %{
        :odd => [
          background: :yellow
        ],
        :even => [
          background: :pink
        ],
        0 => [
          background: :silver,
          bold: true,
          align: :center,
          kerning: true,
          cols: [
            [colspan: 2]
          ]
        ],
        2 => [background: :silver, cols: [[], [], [background: :dark_green]]],
        -1 => [
          bold: true,
          border: {0.5, 0, 0, 0},
          cols: [
            [background: nil],
            [background: nil],
            [border: {0, 0.5, 0.5, 0.5}],
            [border: {0, 0.5, 0.5, 0.5}, color: :red]
          ]
        ]
      },
      border: 0.5
    ]

    pdf
    |> Pdf.set_font("Helvetica", 12)
    |> Pdf.set_fill_color(:black)
    |> Pdf.set_line_cap(:square)
    |> Pdf.set_line_join(:miter)

    {pdf, remaining} =
      pdf
      |> Pdf.table({100, 800}, {400, 80}, data, table_opts)

    cursor = Pdf.cursor(pdf)

    {pdf, :complete} =
      pdf
      |> Pdf.table({100, cursor - 20}, {400, 200}, remaining, table_opts)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "table with colspan" do
    table =
      Table.new(
        [
          Row.new([
            Cell.new("Col 1,1 (span 2)", colspan: 2, bold: true, align: :center, padding: 2),
            Cell.new("Col 1,3", bold: true)
          ]),
          Row.new([
            Cell.new("Col 2,1"),
            Cell.new("Col 2,2"),
            Cell.new("Col 2,3")
          ]),
          Row.new([
            Cell.new("Col 3,1 (span 3)", colspan: 3, align: :center)
          ]),
          Row.new([
            Cell.new("Col 1,1", bold: true),
            Cell.new("Col 1,2 (span 2)", colspan: 2, align: :center)
          ])
        ],
        columns: [
          %Column{border: 0.5, padding: 4},
          %Column{border: 0.5, padding: 4},
          %Column{border: 0.5, padding: 4}
        ]
      )

    file_path = output("table_with_colspan.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    pdf = Pdf.text_at(pdf, {50, 760}, "Table with colspans", bold: true)

    {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 600}, table)

    # Create a copy of the table with discount and tax columns hidden
    [col1, col2, col3] = table.columns
    hidden_table = %{table | columns: [col1, %{col2 | hide: true}, col3]}

    pdf = Pdf.text_at(pdf, {50, 510}, "Table with colspans (hidden middle column)", bold: true)
    {pdf, :complete} = Pdf.render_table(pdf, {50, 500}, {500, 600}, hidden_table)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "generate invoice table" do
    table =
      Table.new(
        [
          %Column{padding: 4},
          %Column{width: 80, align: :right, padding: 4},
          %Column{width: 100, align: :right, padding: 4},
          %Column{width: 100, align: :right, padding: 4}
        ],
        border: 0
      )
      # Header row
      |> Table.add_row(
        Row.new(["Description", "Quantity", "Unit Price", "Amount"],
          bold: true,
          align: :left,
          background: :gainsboro,
          border: 1
        )
      )
      # Line items
      |> Table.add_rows(
        _line_items = [
          ["Widget A", "2", "25.00", "$50.00"],
          ["Widget B", "1", "30.00", "$30.00"],
          ["Service Fee", "1", "15.00", "$15.00"]
        ],
        border: {0, 1, 0.5},
        border_color: {nil, :black, :light_gray}
      )
      # Subtotal row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Subtotal", colspan: 3, align: :right),
            Cell.new("$95.00", border: 0)
          ],
          border: {1, 0, 0}
        )
      )
      # Tax row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Tax (10%)", colspan: 3, align: :right),
            Cell.new("9.50")
          ],
          border: 0
        )
      )
      # Total row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Total", colspan: 3, align: :right),
            Cell.new("$104.50",
              border: {1, 0, 0, 0},
              background: :light_gray
            )
          ],
          bold: true,
          border: 0
        )
      )

    file_path = output("invoice.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 600}, table)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "generate invoice table style 2" do
    table =
      Table.new(
        [
          Row.new(
            [
              Cell.new("Description", align: :left),
              "Quantity",
              "Unit#{Pdf.Text.non_breaking_space()}Price",
              "Amount#{Pdf.Text.non_breaking_space()}($)"
            ],
            bold: true,
            font_size: 9,
            border: {0, 0, 1, 0}
          )
        ],
        columns: [
          %Column{padding: {6, 4, 4}, width: 0.8},
          %Column{align: :right, padding: {6, 4, 6, 15}},
          %Column{align: :right, padding: {6, 4, 6, 15}, min_width: 57},
          %Column{align: :right, padding: {6, 4, 6, 15}}
        ],
        border: 0,
        font_size: 10
      )
      # Line items
      |> Table.add_rows(
        _line_items = [
          ["Widget A", "2", "25.00", "50.00"],
          ["Widget B", "1", "30.00", "30.00"],
          ["Widget C", "5", "90.00", "450.00"],
          ["Widget D", "100", "35.00", "3,500.00"],
          ["Service Fee", "1", "15.00", "15.00"]
        ],
        border: {0, 0, 0.5, 0},
        border_color: :light_gray
      )
      # Subtotal row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Subtotal", colspan: 3, align: :right),
            Cell.new("4,005.00")
          ],
          border: {0.75, 0, 0, 0}
        )
      )
      # Tax row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Tax (10%)", colspan: 3, align: :right, padding: {2, nil, nil}),
            Cell.new("360.45", padding: {2, nil, nil})
          ],
          border: 0
        )
      )
      # Total row
      |> Table.add_row(
        Row.new(
          [
            nil,
            nil,
            Cell.new("Total", align: :right, border: {1, 0, 0, 0}),
            Cell.new("$4,365.45", border: {1, 0, 0, 0})
          ],
          bold: true,
          font_size: 12,
          border: 0,
          padding: {6, nil}
        )
      )

    file_path = output("invoice2.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 12)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 600}, table)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "table with many rows - page overflow" do
    # Create a table with many rows that will overflow to a new page
    # Using a smaller height to force page breaks
    table =
      Table.new(
        [
          Row.new(
            [
              "Item #",
              "Description",
              "Quantity",
              "Unit Price",
              "Total"
            ],
            bold: true,
            background: :gainsboro,
            border: {0, 0, 1, 0}
          )
        ],
        columns: [
          %Column{padding: 4, border: 0.5, width: 60, align: :center},
          %Column{padding: 4, border: 0.5, width: 200},
          %Column{padding: 4, border: 0.5, width: 80, align: :right},
          %Column{padding: 4, border: 0.5, width: 100, align: :right},
          %Column{padding: 4, border: 0.5, width: 100, align: :right}
        ],
        repeat_header: 1,
        border: 1
      )
      # Add many rows to force overflow
      |> Table.add_rows(
        Enum.map(1..50, fn i ->
          [
            "#{i}",
            "Product #{i} - This is a longer description that might wrap",
            "#{i * 2}",
            "$#{i * 10}.00",
            "$#{i * i * 20}.00"
          ]
        end)
      )
      # Add a footer row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Total", colspan: 4, align: :right),
            Cell.new("$1,275,000.00")
          ],
          background: :light_gray,
          bold: true,
          border: {1, 0, 0, 0}
        )
      )

    file_path = output("table_many_rows.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    # First page - render with limited height to force overflow
    {pdf, remaining} = Pdf.render_table(pdf, {50, 750}, {500, 400}, table)

    # Continue rendering on new page(s) until complete
    pdf =
      case remaining do
        :complete ->
          pdf

        {:continue, _continued_table} ->
          # Add a new page and continue (re-set font and styles)
          pdf =
            pdf
            |> Pdf.add_page(:a4)
            |> Pdf.set_font("Helvetica", 10)
            |> Pdf.set_fill_color(:black)
            |> Pdf.set_line_cap(:square)
            |> Pdf.set_line_join(:miter)

          {pdf, remaining2} = Pdf.render_table(pdf, {50, 750}, {500, 700}, remaining)

          case remaining2 do
            :complete ->
              pdf

            {:continue, _continued_table2} ->
              # Add another page if needed (re-set font and styles)
              pdf =
                pdf
                |> Pdf.add_page(:a4)
                |> Pdf.set_font("Helvetica", 10)
                |> Pdf.set_fill_color(:black)
                |> Pdf.set_line_cap(:square)
                |> Pdf.set_line_join(:miter)

              {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 700}, remaining2)
              pdf
          end
      end

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "table with many rows - page overflow (keep with previous)" do
    # Create a table with many rows that will overflow to a new page
    # Using a smaller height to force page breaks
    table =
      Table.new(
        [
          Row.new(
            [
              "Item #",
              "Description",
              "Quantity",
              "Unit Price",
              "Total"
            ],
            bold: true,
            background: :gainsboro,
            border: {0, 0, 1, 0}
          )
        ],
        columns: [
          %Column{padding: 4, border: 0.5, width: 60, align: :center},
          %Column{padding: 4, border: 0.5, width: 200},
          %Column{padding: 4, border: 0.5, width: 80, align: :right},
          %Column{padding: 4, border: 0.5, width: 100, align: :right},
          %Column{padding: 4, border: 0.5, width: 100, align: :right}
        ],
        repeat_header: 1,
        border: 1
      )
      # Add many rows to force overflow
      |> Table.add_rows(
        Enum.map(1..24, fn i ->
          [
            "#{i}",
            "Product #{i} - This is a longer description that might wrap",
            "#{i * 2}",
            "$#{i * 10}.00",
            "$#{i * i * 20}.00"
          ]
        end)
      )
      # Add a footer row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Total", colspan: 4, align: :right),
            Cell.new("$1,275,000.00")
          ],
          background: :light_gray,
          bold: true,
          border: {1, 0, 0, 0},
          keep_with_previous: true
        )
      )

    file_path = output("table_keep_with_previous.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    # First page - render with limited height to force overflow
    {pdf, remaining} = Pdf.render_table(pdf, {50, 750}, {500, 700}, table)

    # Continue rendering on new page(s) until complete
    pdf =
      case remaining do
        :complete ->
          pdf

        {:continue, _continued_table} ->
          # Add a new page and continue (re-set font and styles)
          pdf =
            pdf
            |> Pdf.add_page(:a4)
            |> Pdf.set_font("Helvetica", 10)
            |> Pdf.set_fill_color(:black)
            |> Pdf.set_line_cap(:square)
            |> Pdf.set_line_join(:miter)

          {pdf, remaining2} = Pdf.render_table(pdf, {50, 750}, {500, 700}, remaining)

          case remaining2 do
            :complete ->
              pdf

            {:continue, _continued_table2} ->
              # Add another page if needed (re-set font and styles)
              pdf =
                pdf
                |> Pdf.add_page(:a4)
                |> Pdf.set_font("Helvetica", 10)
                |> Pdf.set_fill_color(:black)
                |> Pdf.set_line_cap(:square)
                |> Pdf.set_line_join(:miter)

              {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 700}, remaining2)
              pdf
          end
      end

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", [file_path])
  end

  test "invoice with hideable tax and discount columns" do
    # Create invoice table with tax and discount columns that can be hidden
    base_table =
      Table.new(
        [
          Row.new(
            [
              "Description",
              "Quantity",
              "Unit Price",
              "Discount",
              "Tax",
              "Total"
            ],
            bold: true,
            background: :gainsboro,
            border: {0, 0, 1, 0}
          )
        ],
        columns: [
          # Description column
          %Column{padding: 4, border: 0.5, width: 200},
          # Quantity column
          %Column{padding: 4, border: 0.5, width: 80, align: :right, max_width: 50},
          # Unit Price column
          %Column{padding: 4, border: 0.5, width: 100, align: :right},
          # Discount column
          %Column{padding: 4, border: 0.5, width: 80, align: :right},
          # Tax column
          %Column{padding: 4, border: 0.5, width: 80, align: :right},
          # Total column
          %Column{padding: 4, border: 0.5, width: 100, align: :right}
        ],
        border: 1,
        repeat_header: 1
      )
      # Add line items
      |> Table.add_rows(
        Enum.map(1..10, fn i ->
          [
            "Product #{i}",
            "#{i}",
            "$#{:erlang.float_to_binary(i * 10.0, decimals: 2)}",
            "$#{:erlang.float_to_binary(i * 0.5, decimals: 2)}",
            "$#{:erlang.float_to_binary(i * 1.2, decimals: 2)}",
            "$#{:erlang.float_to_binary(i * 10.7, decimals: 2)}"
          ]
        end)
      )
      # Add subtotal row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Subtotal", colspan: 5, align: :right),
            # Subtotal
            "$535.00"
          ],
          border: {0.75, 0, 0, 0}
        )
      )
      # Add tax row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Tax (10%)", colspan: 5, align: :right),
            Cell.new("$53.50")
          ],
          border: {0.75, 0, 0, 0}
        )
      )
      # Add total row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Total", colspan: 5, align: :right),
            Cell.new("$535.00", bold: true)
          ],
          background: :light_gray,
          border: {1, 0, 0, 0}
        )
      )

    file_path = output("invoice_hideable_columns.pdf")

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 10)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    # First page - show all columns
    {pdf, :complete} = Pdf.render_table(pdf, {50, 750}, {500, 600}, base_table)

    [col1, col2, col3, col4, col5, col6] = base_table.columns

    # Create a copy of the table with discount and tax columns hidden
    hidden_table = %{
      base_table
      | columns: [col1, col2, col3, %{col4 | hide: true}, %{col5 | hide: true}, col6]
    }

    {pdf, :complete} = Pdf.render_table(pdf, {50, 400}, {500, 600}, hidden_table)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  test "full_width false shrinks table to content" do
    rows = [
      Row.new(["Item", "Qty", "Price"], bold: true, background: :silver),
      Row.new(["Widget A", "2", "$50.00"]),
      Row.new(["Widget B", "1", "$30.00"])
    ]

    table_full =
      Table.new(rows,
        padding: 4,
        border: 0.5
      )

    table_narrow =
      Table.new(rows,
        full_width: false,
        padding: 4,
        border: 0.5
      )

    file_path = output("table_full_width.pdf")
    bounds = {50, 750}
    box = {500, 120}

    {:ok, pdf} = Pdf.new(size: :a4, compress: false)

    pdf =
      pdf
      |> Pdf.set_font("Helvetica", 11)
      |> Pdf.set_fill_color(:black)
      |> Pdf.set_line_cap(:square)
      |> Pdf.set_line_join(:miter)

    pdf =
      pdf
      |> Pdf.text_at({50, 770}, "full_width: true (default) — table fills the gray box",
        bold: true
      )
      |> draw_table_bounds(bounds, box)
      |> then(fn pdf ->
        {x, top_y} = bounds
        {pdf, :complete} = Pdf.render_table(pdf, {x, top_y}, box, table_full)
        pdf
      end)

    pdf =
      pdf
      |> Pdf.text_at({50, 580}, "full_width: false — table only as wide as content", bold: true)
      |> draw_table_bounds({50, 560}, box)
      |> then(fn pdf ->
        {pdf, :complete} = Pdf.render_table(pdf, {50, 560}, box, table_narrow)
        pdf
      end)

    pdf
    |> Pdf.write_to(file_path)
    |> Pdf.cleanup()

    if @open, do: System.cmd("open", ["-g", file_path])
  end

  defp draw_table_bounds(pdf, {x, top_y}, {w, h}) do
    pdf
    |> Pdf.set_line_width(0.5)
    |> Pdf.set_stroke_color(:light_gray)
    |> Pdf.rectangle({x, top_y - h}, {w, h})
    |> Pdf.stroke()
  end
end
