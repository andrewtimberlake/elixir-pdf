defmodule Pdf.ColorTest do
  use ExUnit.Case

  alias Pdf.Color

  test "rgb/3" do
    assert %Color.RGB{} = Color.rgb(0, 0, 0)
  end

  test "rgba/4" do
    assert %Color.RGB{} = Color.rgba(0, 0, 0, 0)
  end
end
