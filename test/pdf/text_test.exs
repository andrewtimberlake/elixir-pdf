defmodule Pdf.TextTest do
  use ExUnit.Case, async: true

  alias Pdf.Text

  setup do
    font = Pdf.Fonts.get_internal_font("Helvetica")
    font_size = 10
    {:ok, font: font, font_size: font_size}
  end

  describe "chunk_text/4" do
    test "it breaks on a space", %{font: font, font_size: font_size} do
      string = "Hello world"

      assert Text.chunk_text(string, font, font_size) == [
               {"Hello", 22.78, []},
               {" ", 2.78, []},
               {"world", 23.89, []}
             ]

      assert Text.chunk_text(string, font, font_size, kerning: true) == [
               {"Hello", 22.78, [kerning: true]},
               {" ", 2.78, [kerning: true]},
               {"world", 23.94, [kerning: true]}
             ]
    end
  end

  describe "wrap_chunks/2" do
    test "It doesn't include the wrapped space" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 23.0) == {[{"Hello", 22.78, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, color: :blue},
        {"world", 26.11, color: :red}
      ]

      assert Text.wrap_chunks(chunks, 23.0) ==
               {[{"Hello", 22.78, size: 10}], [{"world", 26.11, color: :red}]}
    end

    test "it doesn't include a zero-width space" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u200B", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 23.0) == {[{"Hello", 22.78, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, color: :blue},
        {"\u200B", 0.00, []},
        {"world", 26.11, size: 10}
      ]

      assert Text.wrap_chunks(chunks, 23.0) ==
               {[{"Hello", 22.78, color: :blue}], [{"world", 26.11, size: 10}]}
    end

    test "it removes unused soft-hyphens" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u00AD", 3.33, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 50.0) == {[{"Hello", 22.78, []}, {"world", 26.11, []}], []}

      chunks = [
        {"Hello", 22.78, color: :red},
        {"\u00AD", 3.33, color: :green},
        {"world", 26.11, color: :blue}
      ]

      assert Text.wrap_chunks(chunks, 50.0) ==
               {[{"Hello", 22.78, color: :red}, {"world", 26.11, color: :blue}], []}
    end

    test "it wraps on a soft-hyphen" do
      chunks = [
        {"Hello", 22.78, []},
        {"\u00AD", 3.33, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 30.0) ==
               {[{"Hello", 22.78, []}, {"\u00AD", 3.33, []}], [{"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {"\u00AD", 3.33, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 30.0) ==
               {[{"Hello", 22.78, size: 10}, {"\u00AD", 3.33, size: 11}],
                [{"world", 26.11, size: 12}]}
    end

    test "it wraps on a carriage return" do
      chunks = [
        {"Hello", 22.78, []},
        {"\n", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, []}], [{"", 0.0, []}, {"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {"\n", 0.00, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, size: 10}], [{"", 0.0, [size: 11]}, {"world", 26.11, size: 12}]}
    end

    test "it wraps on a carriage return even if the carriage return is first" do
      chunks = [
        {"\n", 0.00, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) == {[], [{"", 0.0, []}, {"world", 26.11, []}]}

      chunks = [
        {"\n", 0.00, size: 10},
        {"world", 26.11, size: 11}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[], [{"", 0.0, [size: 10]}, {"world", 26.11, size: 11}]}
    end

    test "it returns an empty array if the next chunk doesn't fit" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 20.0) ==
               {[], [{"Hello", 22.78, []}, {" ", 2.78, []}, {"world", 26.11, []}]}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 20.0) ==
               {[],
                [{"Hello", 22.78, size: 10}, {" ", 2.78, size: 11}, {"world", 26.11, size: 12}]}
    end

    test "it returns all chunks if they fit" do
      chunks = [
        {"Hello", 22.78, []},
        {" ", 2.78, []},
        {"world", 26.11, []}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, []}, {" ", 2.78, []}, {"world", 26.11, []}], []}

      chunks = [
        {"Hello", 22.78, size: 10},
        {" ", 2.78, size: 11},
        {"world", 26.11, size: 12}
      ]

      assert Text.wrap_chunks(chunks, 60.0) ==
               {[{"Hello", 22.78, size: 10}, {" ", 2.78, size: 11}, {"world", 26.11, size: 12}],
                []}
    end
  end
end
