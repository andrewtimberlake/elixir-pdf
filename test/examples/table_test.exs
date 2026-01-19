defmodule Pdf.Examples.TableTest do
  use Pdf.Case, async: true

  @open true

  alias Pdf.Table.{Table, Row, Cell, Column}

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
        border: 1,
        padding: 4
      )

    file_path = output("table_with_colspan.pdf")

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

  test "generate invoice table" do
    table =
      Table.new(
        [
          %Column{},
          %Column{width: 80, align: :right},
          %Column{width: 100, align: :right},
          %Column{width: 100, align: :right}
        ],
        padding: 4,
        border: 0.5
      )
      # Header row
      |> Table.add_row(
        Row.new(["Description", "Quantity", "Unit Price", "Amount"],
          bold: true,
          align: :left,
          background: :gainsboro,
          border: {0, 0, 1, 0}
        )
      )
      # Line items
      |> Table.add_rows(
        _line_items = [
          ["Widget A", "2", "25.00", "$50.00"],
          ["Widget B", "1", "30.00", "$30.00"],
          ["Service Fee", "1", "15.00", "$15.00"]
        ]
      )
      # Subtotal row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Subtotal", colspan: 3, align: :right),
            Cell.new("$95.00", border: 0)
          ],
          border: 0
        )
      )
      # Tax row
      |> Table.add_row(
        Row.new(
          [
            Cell.new("Tax (10%)", colspan: 3),
            Cell.new("9.50")
          ],
          align: :right,
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
    alias Pdf.Table.{Table, Row, Cell, Column}

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
          %Column{width: 0.8},
          %Column{align: :right, padding: {nil, nil, nil, 15}},
          %Column{align: :right, padding: {nil, nil, nil, 15}, min_width: 57},
          %Column{align: :right, padding: {nil, nil, nil, 15}}
        ],
        padding: {6, 4, 4},
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
            Cell.new("Tax (10%)", colspan: 3),
            Cell.new("360.45")
          ],
          align: :right,
          border: 0,
          padding: {2, nil, nil}
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
          %Column{width: 60, align: :center},
          %Column{width: 200},
          %Column{width: 80, align: :right},
          %Column{width: 100, align: :right},
          %Column{width: 100, align: :right}
        ],
        padding: 4,
        border: 0.5,
        repeat_header: 1
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
            Cell.new("$1,275,000.00", bold: true)
          ],
          background: :light_gray,
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

        {:continue, continued_table} ->
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

            {:continue, continued_table2} ->
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
end
