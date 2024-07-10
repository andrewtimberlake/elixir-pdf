defmodule Pdf.DocumentTest do
  use ExUnit.Case, async: true
  import Pdf.Utils

  alias Pdf.{Document, ObjectCollection, Dictionary}

  describe "new/1" do
    test "it creates a default info dictionary" do
      document = Document.new()

      assert get_info(document) == %{"Creator" => "Elixir", "Producer" => "Elixir-PDF"}
    end
  end

  describe "put_info/2" do
    test "it sets info by key" do
      document =
        Document.new()
        |> Document.put_info(title: "Test Title", producer: "Test Producer")

      assert get_info(document) == %{
               "Creator" => "Elixir",
               "Producer" => "Test Producer",
               "Title" => "Test Title"
             }
    end

    test "it handles an invalid key" do
      assert_raise ArgumentError, fn ->
        Document.new()
        |> Document.put_info(title: "Test Title", producers: "Test Producer")
      end
    end
  end

  defp get_info(document) do
    document.objects |> ObjectCollection.get_object(document.info) |> Dictionary.to_map()
  end

  test "autoprint/0" do
    document = Document.autoprint(Document.new())
    assert {:object, _, _} = ref = document.action

    assert %Dictionary{
             entries: %{
               {:name, "S"} => {:name, "Named"},
               {:name, "Type"} => {:name, "Action"},
               {:name, "N"} => {:name, "Print"}
             }
           } = Document.get_object(document, ref)
  end
end
