defmodule Pdf.Image do
  @moduledoc false

  alias __MODULE__

  defstruct name: nil,
            width: 0,
            height: 0

  def new(image_ref) do
    %Image{
      name: image_ref.name,
      width: Pdf.pixels_to_points(image_ref.width),
      height: Pdf.pixels_to_points(image_ref.height)
    }
  end

  def relative_height(image, width) do
    IO.inspect(width / image.width * image.height,
      label: "#{width} / #{image.width} * #{image.height}"
    )

    width / image.width * image.height
  end

  def relative_width(image, height) do
    height / image.height * image.width
  end
end
