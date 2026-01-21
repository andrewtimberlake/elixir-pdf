defmodule Pdf.TableTest do
  use Pdf.Case, async: true

  alias Pdf.Table
  alias Pdf.Table.Row
  alias Pdf.Table.Cell
  alias Pdf.Table.Column
  alias Pdf.{Page, ObjectCollection, Fonts}

  describe "new/1" do
    test "build from a list of lists" do
      table =
        Table.new([
          ["Description", "Quantity", "Unit Price", "Amount"],
          ["Item 1", "1", "10.00", "10.00"],
          ["Item 2", "2", "20.00", "40.00"],
          ["Item 3", "3", "30.00", "90.00"]
        ])

      # Rows and cells are stored in reverse order to facilitate adding rows and cells to the end of the list
      # Rows and cells are reordered during Table.prepare/3 to facilitate rendering
      assert table.rows == [
               %Row{
                 cells: [
                   %Cell{data: "90.00"},
                   %Cell{data: "30.00"},
                   %Cell{data: "3"},
                   %Cell{data: "Item 3"}
                 ]
               },
               %Row{
                 cells: [
                   %Cell{data: "40.00"},
                   %Cell{data: "20.00"},
                   %Cell{data: "2"},
                   %Cell{data: "Item 2"}
                 ]
               },
               %Row{
                 cells: [
                   %Cell{data: "10.00"},
                   %Cell{data: "10.00"},
                   %Cell{data: "1"},
                   %Cell{data: "Item 1"}
                 ]
               },
               %Row{
                 cells: [
                   %Cell{data: "Amount"},
                   %Cell{data: "Unit Price"},
                   %Cell{data: "Quantity"},
                   %Cell{data: "Description"}
                 ]
               }
             ]
    end

    test "build up a table structure" do
      table =
        Table.new(
          [
            %Column{},
            %Column{width: 40},
            %Column{min_width: 50, align: :right},
            %Column{min_width: 80, align: :right}
          ],
          padding: 2,
          background: :gainsboro,
          border: 0.5,
          repeat_header: 1
        )

      table =
        Table.add_row(
          table,
          Row.new(["Description", "Quantity", "Unit Price", "Amount"],
            bold: true,
            align: :center,
            kerning: true,
            border: {0, 0, 1, 0}
          )
        )

      data = [
        ["Item 1", "1", "10.00", "10.00"],
        ["Item 2", "2", "20.00", "40.00"],
        ["Item 3", "3", "30.00", "90.00"]
      ]

      table =
        Enum.reduce(data, table, fn cells, table ->
          Table.add_row(table, Row.new(cells))
        end)

      table =
        Table.add_row(
          table,
          Row.new([Cell.new("Subtotal", colspan: 3, align: :right), Cell.new("140.00")],
            bold: true
          )
        )

      table =
        Table.add_row(
          table,
          Row.new([Cell.new("Tax (10%)", colspan: 3, align: :right), Cell.new("14.00")],
            bold: true
          )
        )

      table =
        Table.add_row(
          table,
          Row.new([Cell.new("Total", colspan: 3, align: :right), Cell.new("154.00")],
            bold: true
          )
        )

      assert %{rows: [%Row{cells: [%Cell{data: "154.00"} | _]} | _]} = table
    end
  end

  describe "prepare/3" do
    setup do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      page = Page.new(fonts: fonts, compress: false)

      # Preload fonts so the internal names are fixed (but don't save the resulting stream)
      page =
        page
        |> Page.set_font("Helvetica", 12)

      {:ok, page: page}
    end

    test "column widths can be percentages", %{page: page} do
      table =
        Table.new(
          [
            ["Description", "Quantity", "Unit Price", "Amount"],
            ["Item 1", "1", "10.00", "10.00"],
            ["Item 2", "2", "20.00", "40.00"],
            ["Item 3", "3", "30.00", "90.00"]
          ],
          columns: [
            %Column{width: 0.25},
            %Column{width: 0.25},
            %Column{width: 0.25},
            %Column{width: 0.25}
          ]
        )

      table = Pdf.Table.prepare(page, table, 400)

      # After prepare, percentage widths are converted to PDF points
      # 0.25 * 400 = 100.0 points
      assert [
               %Column{width: 100.0},
               %Column{width: 100.0},
               %Column{width: 100.0},
               %Column{width: 100.0}
             ] = table.columns
    end

    test "column widths will always be adjusted to fit the total width", %{page: page} do
      table =
        Table.new(
          [
            ["Description", "Quantity", "Unit Price", "Amount"],
            ["Item 1", "1", "10.00", "10.00"],
            ["Item 2", "2", "20.00", "40.00"],
            ["Item 3", "3", "30.00", "90.00"]
          ],
          columns: [
            %Column{min_width: 200},
            %Column{width: 0.25},
            %Column{width: 0.25},
            %Column{width: 0.25}
          ]
        )

      table = Pdf.Table.prepare(page, table, 400)

      # Column 1: min_width: 200 → gets 200
      # Columns 2-4: each 25% of total (400 * 0.25 = 100 each)
      # Total: 200 + 100 + 100 + 100 = 500, but we only have 400
      # So percentages need to be scaled down to fit
      # Remaining after min_width: 400 - 200 = 200
      # Percentages should be scaled: 200 / 300 = 0.6667
      # So each percentage column gets: 100 * 0.6667 = 66.67
      [col1, col2, col3, col4] = table.columns

      assert col1.width == 200
      # Percentages are scaled down to fit remaining space
      assert col2.width == 66.667
      assert col3.width == 66.667
      assert col4.width == 66.667
    end

    test "percentage width should be based on total width, not remaining space", %{page: page} do
      table =
        Table.new(
          [
            ["Description", "Quantity", "Unit Price", "Amount"]
            # ["This line is a lot longer than the others", "1", "10.00", "10.00"],
            # [Cell.new("test", colspan: 3), "10.00"]
          ],
          columns: [
            %Column{width: 0.8, padding: 4},
            %Column{min_width: 40, align: :right, padding: 4},
            %Column{min_width: 40, align: :right, padding: 4},
            %Column{min_width: 40, align: :right, padding: 4}
          ]
        )

      table = Pdf.Table.prepare(page, table, 500)

      # First column should be 80% of total width (500 * 0.8 = 400)
      # Remaining 100 should be distributed among the 3 min_width columns
      [col1, col2, col3, col4] = table.columns

      assert col2.width == 52.688
      assert col2.min_width == 40
      assert col3.width == 40
      assert col3.min_width == 40
      assert col4.width == 49.352
      assert col4.min_width == 40
      assert col1.width == 357.96
    end

    test "flexible columns should use content width as minimum when percentage column takes space",
         %{page: page} do
      # Table with first column 80% width, other 3 columns flexible
      # The flexible columns should not be squished below their content width
      table =
        Table.new(
          [],
          columns: [
            # 80% of total width
            %Column{width: 0.8},
            %Column{align: :right},
            %Column{align: :right},
            %Column{align: :right}
          ],
          padding: 4,
          border: 0,
          font_size: 10
        )
        |> Table.add_row(
          Row.new([
            Cell.new("Description"),
            Cell.new("Quantity"),
            Cell.new("Unit Price"),
            Cell.new("Amount ($)")
          ])
        )
        |> Table.add_row(
          Row.new([
            Cell.new("Widget A"),
            Cell.new("2"),
            Cell.new("25.00"),
            Cell.new("50.00")
          ])
        )
        |> Table.add_row(
          Row.new([
            Cell.new("Widget D"),
            Cell.new("100"),
            Cell.new("35.00"),
            # This is the widest content in last column
            Cell.new("3,500.00")
          ])
        )

      total_width = 400.0
      prepared = Pdf.Table.prepare(page, table, total_width)

      # Get the column widths
      col_widths = Enum.map(prepared.columns, & &1.width)

      # First column should be approximately 80% of total width (but may be adjusted if flexible columns need more)
      first_col_width = Enum.at(col_widths, 0)
      # With padding (4 on each side = 8 per column), flexible columns need more space
      # So the percentage column will be adjusted down to accommodate them
      # It should be at least 60% to allow adjustment for flexible columns with padding
      assert first_col_width >= total_width * 0.6

      # Last 3 columns should each be at least their content width
      # The last column has "3,500.00" which should be wider than "50.00"
      last_col_width = Enum.at(col_widths, 3)
      second_col_width = Enum.at(col_widths, 1)
      third_col_width = Enum.at(col_widths, 2)

      # All flexible columns should be at least their minimum content width
      # The last column with "3,500.00" should be wider than columns with shorter content
      assert last_col_width >= second_col_width
      assert last_col_width >= third_col_width

      # Verify all columns fit within total width
      total_used = Enum.sum(col_widths)
      # Small tolerance for rounding
      assert total_used <= total_width + 0.01

      # Verify the last column (with "3,500.00") is reasonably wide (at least 30 points)
      # This ensures content width is being used as minimum
      assert last_col_width >= 30.0
    end
  end

  describe "distribute_column_widths/2" do
    test "distributes percentage widths correctly" do
      columns = [
        %Column{width: 0.5, calculated_min_width: 0},
        %Column{width: 0.3, calculated_min_width: 0},
        %Column{width: 0.2, calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2, col3] = result
      assert col1.width == 500.0
      assert col2.width == 300.0
      assert col3.width == 200.0
    end

    test "distributes fixed widths correctly" do
      columns = [
        %Column{width: 300, calculated_min_width: 0},
        %Column{width: 200, calculated_min_width: 0},
        %Column{width: 100, calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 600)

      [col1, col2, col3] = result
      assert col1.width == 300.0
      assert col2.width == 200.0
      assert col3.width == 100.0
    end

    test "distributes flexible columns equally when no width suggestions" do
      columns = [
        %Column{calculated_min_width: 0},
        %Column{calculated_min_width: 0},
        %Column{calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 900)

      [col1, col2, col3] = result
      assert col1.width == 300.0
      assert col2.width == 300.0
      assert col3.width == 300.0
    end

    test "distributes remaining space to flexible columns after fixed/percentage columns" do
      columns = [
        # 50% = 500
        %Column{width: 0.5, calculated_min_width: 0},
        # flexible
        %Column{calculated_min_width: 0},
        # flexible
        %Column{calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2, col3] = result
      assert col1.width == 500.0
      # Remaining 500 split equally between 2 flexible columns
      assert col2.width == 250.0
      assert col3.width == 250.0
    end

    test "respects calculated_min_width as hard constraint" do
      columns = [
        %Column{width: 0.8, calculated_min_width: 100},
        %Column{calculated_min_width: 50},
        %Column{calculated_min_width: 50}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 500)

      [col1, col2, col3] = result
      # First column: 80% of 500 = 400, but min is 100, so 400 is fine
      assert col1.width >= 100.0
      # Other columns: must be at least 50 each
      assert col2.width == 50.0
      assert col3.width == 50.0
      # Total should be 500
      total = Enum.sum(Enum.map(result, & &1.width))
      assert total == 500.0
    end

    test "scales down when total exceeds available width" do
      columns = [
        # 60% of 1000 = 600
        %Column{width: 0.6, calculated_min_width: 0},
        # 50% of 1000 = 500
        %Column{width: 0.5, calculated_min_width: 0}
        # Total: 1100, but only 1000 available
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2] = result
      ratio = col1.width / col2.width
      assert_in_delta ratio, 600.0 / 500.0, 0.01

      assert col1.width == 545.455
      assert col2.width == 454.545

      assert Enum.sum(Enum.map(result, & &1.width)) == 1000.0
    end

    test "excludes columns at minimum from scaling" do
      columns = [
        # 50% of 1000 = 500, but min is 400
        %Column{width: 0.5, calculated_min_width: 400},
        # 50% of 1000 = 500
        %Column{width: 0.5, calculated_min_width: 0}
        # Total: 1000, but first column at min (400) + second (500) = 900, fits
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2] = result
      # First column should be at least its minimum
      assert col1.width == 500.0
      assert col2.width == 500.0
      # Total should fit
      assert Enum.sum(Enum.map(result, & &1.width)) == 1000.0
    end

    test "raises error when calculated_min_widths exceed total_width" do
      columns = [
        %Column{calculated_min_width: 400},
        %Column{calculated_min_width: 400},
        %Column{calculated_min_width: 300}
        # Total minimum: 1100, but only 1000 available
      ]

      assert_raise RuntimeError, ~r/Impossible constraint/, fn ->
        Pdf.Table.distribute_column_widths(columns, 1000)
      end
    end

    test "handles mixed percentage, fixed, and flexible columns" do
      columns = [
        # 40% = 400
        %Column{width: 0.4, calculated_min_width: 0},
        # fixed = 200
        %Column{width: 200, calculated_min_width: 0},
        # flexible gets remainder
        %Column{calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2, col3] = result
      assert col1.width == 400.0
      assert col2.width == 200.0
      # Remaining: 1000 - 400 - 200 = 400
      assert col3.width == 400.0

      assert Enum.sum(Enum.map(result, & &1.width)) == 1000.0
    end

    test "handles columns with calculated_min_width that exceeds suggestion" do
      columns = [
        # 30% of 1000 = 300, but min is 400
        %Column{width: 0.3, calculated_min_width: 400},
        # 70% of 1000 = 700
        %Column{width: 0.7, calculated_min_width: 0}
      ]

      result = Pdf.Table.distribute_column_widths(columns, 1000)

      [col1, col2] = result
      # First column must be at least 400 (its minimum)
      assert col1.width == 400.0
      # Second column gets remaining space
      assert col2.width == 600.0
      # Total should be 1000
      assert Enum.sum(Enum.map(result, & &1.width)) == 1000.0
    end
  end

  describe "render" do
    setup do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      page = Page.new(fonts: fonts, compress: false)

      # Preload fonts so the internal names are fixed (but don't save the resulting stream)
      page =
        page
        |> Page.set_font("Helvetica", 12)

      # |> Page.set_font("Helvetica", 12, bold: true)
      # |> Page.set_font("Helvetica", 12, italic: true)
      # |> Page.set_font("Helvetica", 12, bold: true, italic: true)

      {:ok, page: page}
    end

    test "it does nothing with an empty data list", %{page: page} do
      table = Table.new([])
      table = Pdf.Table.prepare(page, table, 500)
      {page, :complete} = Pdf.Table.render(page, {20, 600}, {500, 500}, table)

      assert export(page) == "\n"
    end

    test "basic table", %{page: page} do
      data = [
        ["Col 1,1", "Col 1,2", "Col 1,3"],
        ["Col 2,1", "Col 2,2", "Col 2,3"]
      ]

      table = Table.new(data)

      page = Page.set_font(page, "Helvetica", 12)
      table = Pdf.Table.prepare(page, table, 300)

      {page, :complete} =
        Pdf.Table.render(page, {20, 600}, {300, 500}, table)

      assert export(page) == """
             q
             20 588 100.0 12 re
             W n
             BT
             /F1 12 Tf
             20 590.934 Td
             (Col 1,1) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             q
             120.0 588 100.0 12 re
             W n
             BT
             /F1 12 Tf
             120.0 590.934 Td
             (Col 1,2) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             q
             220.0 588 100.0 12 re
             W n
             BT
             /F1 12 Tf
             220.0 590.934 Td
             (Col 1,3) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             q
             20 576 100.0 12 re
             W n
             BT
             /F1 12 Tf
             20 578.934 Td
             (Col 2,1) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             q
             120.0 576 100.0 12 re
             W n
             BT
             /F1 12 Tf
             120.0 578.934 Td
             (Col 2,2) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             q
             220.0 576 100.0 12 re
             W n
             BT
             /F1 12 Tf
             220.0 578.934 Td
             (Col 2,3) Tj
             0.0 0.0 0.0 rg
             ET
             Q
             """
    end

    test "row exceeds available space" do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      # Tiny paper so we run out of space quickly
      page = Page.new(size: [100, 100], fonts: fonts, compress: false)

      data = [
        ["Header 1", "Header 2", "Header 3"],
        [
          "Col 1",
          long_content("Test", 5),
          "Col 3"
        ]
      ]

      table = Table.new(data)
      page = Page.set_font(page, "Helvetica", 12)
      table = Pdf.Table.prepare(page, table, 120)

      result = Pdf.Table.render(page, {10, 90}, {80, 80}, table)

      assert {_page, {:continue, %Pdf.Table{rows: [%Pdf.Table.Row{cells: cells}]}}} = result

      # Verify we have 3 cells with chunks
      assert length(cells) == 3
      assert Enum.all?(cells, &(&1.chunks != nil && length(&1.chunks) > 0))
    end

    test "row exceeds available space but with partial row allowed" do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      # Tiny paper so we run out of space quickly
      page = Page.new(size: [100, 100], fonts: fonts, compress: false)

      data = [
        ["Header 1", "Header 2", "Header 3"],
        [
          "Col 1",
          long_content("Test", 5),
          "Col 3"
        ]
      ]

      table = Table.new(data, allow_row_overflow: true)
      page = Page.set_font(page, "Helvetica", 12)
      table = Pdf.Table.prepare(page, table, 120)

      result = Pdf.Table.render(page, {10, 90}, {80, 80}, table)

      assert {_page,
              {:continue, %Pdf.Table{rows: [%Pdf.Table.Row{cells: cells}]} = continued_table}} =
               result

      # Verify overflow cell has chunks (some cells might be nil)
      assert length(cells) == 3
      [cell1, cell2, cell3] = cells
      assert (cell1 != nil && (cell1.chunks == [] || length(cell1.chunks) == 0)) || cell1 == nil
      assert cell2 != nil && length(cell2.chunks) > 0
      assert (cell3 != nil && (cell3.chunks == [] || length(cell3.chunks) == 0)) || cell3 == nil

      {page, _} = result

      assert {_page, :complete} =
               Pdf.Table.render(page, {10, 90}, {80, 80}, continued_table)
    end

    test "handle empty row generated from trailing whitespace" do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      # Tiny paper so we run out of space quickly
      page = Page.new(size: [100, 100], fonts: fonts, compress: false)

      data = [
        ["Header 1", "Header 2", "Header 3"],
        [
          "Col 1",
          "Col 2",
          #    ↓ the error
          "mmmm "
        ]
      ]

      table = Table.new(data, allow_row_overflow: true)
      page = Page.set_font(page, "Helvetica", 12)
      table = Pdf.Table.prepare(page, table, 120)

      assert {_page, :complete} =
               Pdf.Table.render(page, {10, 90}, {80, 80}, table)
    end

    test "Handle empty row error" do
      {:ok, collection} = ObjectCollection.start_link()
      {:ok, fonts} = Fonts.start_link(collection)
      page = Page.new(size: :a4, fonts: fonts, compress: false)

      data = [
        []
      ]

      table = Table.new(data, allow_row_overflow: true)
      page = Page.set_font(page, "Helvetica", 12)
      table = Pdf.Table.prepare(page, table, 80)

      assert {_page, :complete} =
               Pdf.Table.render(page, {10, 90}, {80, 80}, table)
    end

    defp long_content(string, repeats) do
      1..repeats
      |> Enum.map(fn _ -> string end)
      |> Enum.join(" ")
    end
  end
end
