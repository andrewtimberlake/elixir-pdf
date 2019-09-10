defmodule Pdf.Util.Text do
  @moduledoc """
  Helper functions for text manipulation
  """

  alias Pdf.ExternalFont

  @doc """
  Calculate the width of a piece of text, given the font and size
  """
  def text_width(%ExternalFont{} = font, text, size) do
    ExternalFont.text_width(font, text, size)
  end

  def text_width(font, text, size) do
    apply(font, :text_width, [text, size])
  end
end
