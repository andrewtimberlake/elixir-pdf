defmodule Pdf.Color do
  @moduledoc """
  This module contains helper functions to generate the correct color info
  for use in the PDF.
  """

  defstruct command: "rg", color: nil

  alias Pdf.Color.RGB

  @doc """
  Create a new color
  """
  def new(command, color) do
    %__MODULE__{
      command: command,
      color: color
    }
  end

  @doc """
  Generate a RGB color value
  """
  def rgb(r, g, b) do
    RGB.new(r, g, b)
  end

  @doc """
  Generate a RGBa color value
  """
  def rgba(r, g, b, opacity) do
    RGB.new(r, g, b, opacity)
  end

  def size(color) do
    color
    |> to_iolist()
    |> :binary.list_to_bin()
    |> byte_size()
  end

  def to_iolist(color) do
    [
      Pdf.Export.to_iolist(color.color),
      " ",
      color.command
    ]
  end

  defimpl Pdf.Size do
    def size_of(%Pdf.Color{} = color), do: Pdf.Color.size(color)
  end

  defimpl Pdf.Export do
    def to_iolist(%Pdf.Color{} = color), do: Pdf.Color.to_iolist(color)
  end
end
