defmodule Pdf.PageTest do
  use Pdf.Case, async: true

  alias Pdf.{Page, Fonts, ObjectCollection, ImageRef}

  setup do
    {:ok, collection} = ObjectCollection.start_link()
    {:ok, fonts} = Fonts.start_link(collection)
    page = Page.new(fonts: fonts, compress: false)

    # Preload fonts so the internal names are fixed (but don't save the resulting stream)
    page
    |> Page.set_font("Helvetica", 12)
    |> Page.set_font("Helvetica", 12, bold: true)
    |> Page.set_font("Helvetica", 12, italic: true)
    |> Page.set_font("Helvetica", 12, bold: true, italic: true)

    {:ok, page: page}
  end

  describe "set_fill_color/2" do
    test "it sets the fill color", %{page: page} do
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end

    test "it doesn't log a repeat command", %{page: page} do
      page = Page.set_fill_color(page, :red)
      page = Page.set_fill_color(page, :red)
      assert page.fill_color == :red
      assert export(page) == "1.0 0.0 0.0 rg\n"
    end
  end

  describe "add_image/4" do
    setup do
      image_ref = %ImageRef{name: {:name, "I1"}, width: 100, height: 50}
      {:ok, image: image_ref}
    end

    test "it draws the image", %{page: page, image: image} do
      page = Page.add_image(page, {20, 20}, image)

      assert export(page) == """
             q
             100.0 0 0 50.0 20 20 cm
             /I1 Do
             Q
             """
    end

    test "it draws a scaled image based on a supplied width", %{page: page, image: image} do
      page = Page.add_image(page, {20, 20}, image, width: 200)

      assert export(page) == """
             q
             200 0 0 100.0 20 20 cm
             /I1 Do
             Q
             """
    end

    test "it draws a scaled image based on a supplied height", %{page: page, image: image} do
      page = Page.add_image(page, {20, 20}, image, height: 200)

      assert export(page) == """
             q
             400.0 0 0 200 20 20 cm
             /I1 Do
             Q
             """
    end

    test "it draws a distorted image", %{page: page, image: image} do
      page = Page.add_image(page, {20, 20}, image, width: 200, height: 50)

      assert export(page) == """
             q
             200 0 0 50 20 20 cm
             /I1 Do
             Q
             """
    end
  end

  describe "text operations" do
    test "automatically wrapping text commands within BT and ET", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               BT
               /F1 12 Tf
               10 20 Td
               (Hello world) Tj
               ET
               """
    end

    test "text is escaped", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello (world)")

      assert export(page) ==
               """
               BT
               /F1 12 Tf
               10 20 Td
               (Hello \\(world\\)) Tj
               ET
               """
    end

    test "text is normalized", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hellö wôrld")

      assert export(page) ==
               """
               BT
               /F1 12 Tf
               10 20 Td
               (Hell\xF6 w\xF4rld) Tj
               ET
               """
    end

    test "text is escaped when kerned", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello (world)", kerning: true)

      assert export(page) ==
               """
               BT
               /F1 12 Tf
               10 20 Td
               [ (Hello \\(w) 10 (or) -15 (ld\\)) ] TJ
               ET
               """
    end
  end

  describe "text_at/4" do
    test "accepts a string", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)
      page = Page.text_at(page, {10, 20}, "Hello world")

      assert export(page) ==
               """
               BT
               /F1 12 Tf
               10 20 Td
               (Hello world) Tj
               ET
               """
    end

    test "accepts attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      page =
        Page.text_at(page, {10, 20}, [
          "Hello ",
          {"world: ", color: :red, bold: true},
          {"foo, ", font_size: 14},
          {"bar, ", italic: true},
          {"baz"}
        ])

      assert export(page) == """
             BT
             /F1 12 Tf
             10 20 Td
             (Hello ) Tj
             /F2 12 Tf
             1.0 0.0 0.0 rg
             (world: ) Tj
             /F1 14 Tf
             0.0 0.0 0.0 rg
             (foo, ) Tj
             /F3 12 Tf
             (bar, ) Tj
             /F1 12 Tf
             (baz) Tj
             ET
             """
    end

    test "uses global opts for a string", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      page =
        Page.text_at(page, {10, 20}, "Hello world",
          bold: true,
          kerning: true,
          font_size: 14,
          color: :red
        )

      assert export(page) == """
             BT
             /F1 12 Tf
             10 20 Td
             /F2 14 Tf
             1.0 0.0 0.0 rg
             [ (Hello w) 20 (orld) ] TJ
             0.0 0.0 0.0 rg
             ET
             """
    end

    test "uses global opts for attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      page =
        Page.text_at(page, {10, 20}, [{"Hello world", color: :blue}],
          bold: true,
          kerning: true,
          font_size: 14,
          color: :red
        )

      assert export(page) == """
             BT
             /F1 12 Tf
             10 20 Td
             /F2 14 Tf
             0.0 0.0 1.0 rg
             [ (Hello w) 20 (orld) ] TJ
             0.0 0.0 0.0 rg
             ET
             """
    end
  end

  describe "text_wrap/5" do
    test "with text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)
      assert {page, :complete} = Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world")

      assert export(page) == """
             BT
             /F1 10 Tf
             10 12.445 Td
             (Hello world) Tj
             ET
             """
    end

    test "with text, aligned: right", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert {page, :complete} =
               Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world", align: :right)

      assert export(page) == """
             BT
             /F1 10 Tf
             160.55 12.445 Td
             (Hello world) Tj
             ET
             """
    end

    test "with text, aligned: center", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert {page, :complete} =
               Page.text_wrap(page, {10, 20}, {200, 100}, "Hello world", align: :center)

      assert export(page) == """
             BT
             /F1 10 Tf
             85.275 12.445 Td
             (Hello world) Tj
             ET
             """
    end

    test "it returns the text that didn't fit", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert {page, {:continue, _} = remaining} =
               Page.text_wrap(
                 page,
                 {10, 200},
                 {200, 10},
                 "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse elementum enim metus, quis posuere sem molestie interdum. Ut efficitur odio lectus, ut facilisis odio tempor quis."
               )

      assert {page, :complete} = Page.text_wrap(page, {10, 100}, {200, 100}, remaining)

      assert export(page) == """
             BT
             /F1 10 Tf
             10 192.445 Td
             (Lorem ipsum dolor sit amet, consectetur) Tj
             ET
             BT
             /F1 10 Tf
             10 92.445 Td
             (adipiscing elit. Suspendisse elementum enim) Tj
             0 -10 Td
             (metus, quis posuere sem molestie interdum.) Tj
             0 -10 Td
             (Ut efficitur odio lectus, ut facilisis odio) Tj
             0 -10 Td
             (tempor quis.) Tj
             ET
             """
    end

    test "with attributed text", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      attributed_text = [
        {"Lorem ipsum dolor ", font_size: 10},
        {"sit amet, ", italic: true},
        {"consectetur adipiscing elit. ", color: :blue},
        "Ut ut enim",
        {"commodo diam ", bold: true, italic: true, font_size: 10},
        {"lobortis efficitur. ", color: :red},
        {"Curabitur tempor aliquam nulla, vitae cursus purus iaculis vitae.", font_size: 8}
      ]

      assert {page, :complete} = Page.text_wrap(page, {10, 20}, {200, 100}, attributed_text)

      assert export(page) == """
             BT
             /F1 12 Tf
             10 10.934 Td
             /F1 10 Tf
             (Lorem ipsum dolor ) Tj
             /F3 12 Tf
             (sit amet, ) Tj
             /F1 12 Tf
             0.0 0.0 1.0 rg
             (consectetur) Tj
             0 -12 Td
             (adipiscing elit. ) Tj
             0.0 0.0 0.0 rg
             (Ut ut enim) Tj
             /F4 10 Tf
             (commodo) Tj
             0 -12 Td
             (diam ) Tj
             /F1 12 Tf
             1.0 0.0 0.0 rg
             (lobortis efficitur. ) Tj
             /F1 8 Tf
             0.0 0.0 0.0 rg
             (Curabitur tempor) Tj
             0 -12 Td
             (aliquam nulla, vitae cursus purus iaculis vitae.) Tj
             ET
             """
    end

    test "with ending blank lines", %{page: page} do
      page = Page.set_font(page, "Helvetica", 12)

      attributed_text = [
        "Hello world\n\n"
      ]

      assert {page, :complete} = Page.text_wrap(page, {10, 20}, {200, 100}, attributed_text)

      assert export(page) == """
             BT
             /F1 12 Tf
             10 10.934 Td
             (Hello world) Tj
             0 -12 Td
             () Tj
             0 -12 Td
             () Tj
             ET
             """
    end

    test "resetting attributed changes", %{page: page} do
      page =
        page
        |> Page.set_font("Helvetica", 12)
        |> Page.set_fill_color(:black)

      attributed_text = [
        {"foo", font_size: 10, bold: true, color: :red},
        {"bar", font_size: 10, italic: true, color: :red},
        {"baz", font_size: 10, italic: true, color: :blue}
      ]

      assert {page, :complete} = Page.text_wrap(page, {800, 20}, {400, 200}, attributed_text)
      assert {page, :complete} = Page.text_wrap(page, {400, 20}, {400, 200}, "Final text")

      assert export(page) == """
             BT
             /F1 12 Tf
             800 12.445 Td
             /F2 10 Tf
             1.0 0.0 0.0 rg
             (foo) Tj
             /F3 10 Tf
             (bar) Tj
             0.0 0.0 1.0 rg
             (baz) Tj
             0.0 0.0 0.0 rg
             ET
             BT
             /F1 12 Tf
             400 10.934 Td
             (Final text) Tj
             ET
             """
    end

    test "bug report #41", %{page: page} do
      page = Page.set_font(page, "Courier", 7)

      assert {page, :complete} =
               Page.text_wrap(page, {675, 497.8}, {114, 14}, "xxxxxxxxxxxxxxxxxxxxxxxxxxx  ")

      assert export(page) == """
             BT
             /F5 7 Tf
             675 492.648 Td
             (xxxxxxxxxxxxxxxxxxxxxxxxxxx) Tj
             ET
             """
    end
  end

  describe "text_wrap!/5" do
    test "when you know it will fit", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)
      assert page = Page.text_wrap!(page, {10, 20}, {200, 100}, "Hello world")

      assert export(page) == """
             BT
             /F1 10 Tf
             10 12.445 Td
             (Hello world) Tj
             ET
             """
    end

    test "it fails when it doesn't fit", %{page: page} do
      page = Page.set_font(page, "Helvetica", 10)

      assert_raise RuntimeError, fn ->
        Page.text_wrap!(page, {10, 20}, {200, 10}, "Hello\nworld")
      end
    end
  end

  describe "link/3" do
    test "it adds a link annotation to the page", %{page: page} do
      page = Page.link(page, {10, 20}, {200, 100}, "https://example.com")

      assert length(page.links) == 1
      [link] = page.links
      assert link == %{x: 10, y: 20, w: 200, h: 100, target: {:uri, "https://example.com"}}
    end

    test "it creates correct annotation dictionary for URI link", %{page: page} do
      {:ok, collection} = ObjectCollection.start_link()
      page = Page.link(page, {10, 20}, {200, 100}, "https://example.com")

      annot_refs = Page.create_annotations(page, collection, %{})
      assert length(annot_refs) == 1

      annot_dict = ObjectCollection.get_object(collection, hd(annot_refs))
      assert Map.get(annot_dict.entries, {:name, "Type"}) == {:name, "Annot"}
      assert Map.get(annot_dict.entries, {:name, "Subtype"}) == {:name, "Link"}

      assert Map.get(annot_dict.entries, {:name, "Rect"}) == %Pdf.Array{
               values: [10, 20, 210, 120]
             }

      assert Map.get(annot_dict.entries, {:name, "Border"}) == %Pdf.Array{values: [0, 0, 0]}

      action = Map.get(annot_dict.entries, {:name, "A"})
      assert Map.get(action.entries, {:name, "Type"}) == {:name, "Action"}
      assert Map.get(action.entries, {:name, "S"}) == {:name, "URI"}
      assert Map.get(action.entries, {:name, "URI"}) == {:string, "https://example.com"}
    end

    test "it creates correct annotation dictionary for page link", %{page: page} do
      {:ok, collection} = ObjectCollection.start_link()
      page_ref = ObjectCollection.create_object(collection, Pdf.Dictionary.new(%{}))
      page_ref_map = %{1 => page_ref}

      page = Page.link_to_page(page, {50, 100}, {40, 20}, 1)

      annot_refs = Page.create_annotations(page, collection, page_ref_map)
      assert length(annot_refs) == 1

      annot_dict = ObjectCollection.get_object(collection, hd(annot_refs))
      assert Map.get(annot_dict.entries, {:name, "Type"}) == {:name, "Annot"}
      assert Map.get(annot_dict.entries, {:name, "Subtype"}) == {:name, "Link"}

      assert Map.get(annot_dict.entries, {:name, "Rect"}) == %Pdf.Array{
               values: [50, 100, 90, 120]
             }

      action = Map.get(annot_dict.entries, {:name, "A"})
      assert Map.get(action.entries, {:name, "Type"}) == {:name, "Action"}
      assert Map.get(action.entries, {:name, "S"}) == {:name, "GoTo"}
      dest = Map.get(action.entries, {:name, "D"})
      assert dest.values == [page_ref, {:name, "Fit"}]
    end

    test "it drops page link annotation if target page doesn't exist", %{page: page} do
      {:ok, collection} = ObjectCollection.start_link()
      page = Page.link_to_page(page, {10, 20}, {200, 100}, 999)

      annot_refs = Page.create_annotations(page, collection, %{})
      assert annot_refs == []
    end

    test "it handles multiple links", %{page: page} do
      {:ok, collection} = ObjectCollection.start_link()

      page =
        page
        |> Page.link({10, 20}, {200, 100}, "https://example.com")
        |> Page.link({50, 100}, {150, 50}, "https://hexdocs.pm")

      assert length(page.links) == 2

      annot_refs = Page.create_annotations(page, collection, %{})
      assert length(annot_refs) == 2
    end

    test "it returns empty list when page has no links", %{page: page} do
      {:ok, collection} = ObjectCollection.start_link()
      assert Page.create_annotations(page, collection, %{}) == []
    end
  end
end
