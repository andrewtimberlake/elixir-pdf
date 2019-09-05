defmodule Pdf.Color.RGBTest do
  use ExUnit.Case

  alias Pdf.Color.RGB

  test "new/3" do
    assert RGB.new(0, 0, 0) == %RGB{r: 0, g: 0, b: 0, opacity: 100.0}
    assert RGB.new(192, 191, 0) == %RGB{r: 0.753, g: 0.750, b: 0, opacity: 100.0}
  end

  test "new/4" do
    assert RGB.new(0, 0, 0, 50.0) == %RGB{r: 0, g: 0, b: 0, opacity: 50.0}
  end

  test "aqua/0" do
    assert RGB.aqua() === RGB.new(0, 255, 255, 100)
    assert RGB.aqua() === %RGB{r: 0.0, g: 1.0, b: 1.0, opacity: 100.0}
  end

  test "to_iolist/1" do
    assert RGB.to_iolist(RGB.aqua()) == ["0.0", " ", "1.0", " ", "1.0"]
  end

  test "size" do
    assert RGB.size(RGB.aqua()) == 11
    assert RGB.size(RGB.darkcyan()) == 15
  end
end
