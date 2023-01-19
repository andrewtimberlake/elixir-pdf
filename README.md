# Pdf

[![Build Status](https://travis-ci.org/andrewtimberlake/elixir-pdf.svg?branch=master)](https://travis-ci.org/andrewtimberlake/elixir-pdf)
[![Module Version](https://img.shields.io/hexpm/v/pdf.svg)](https://hex.pm/packages/pdf)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/pdf/)
[![Total Download](https://img.shields.io/hexpm/dt/pdf.svg)](https://hex.pm/packages/pdf)
[![License](https://img.shields.io/hexpm/l/pdf.svg)](https://github.com/andrewtimberlake/elixir-pdf/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/andrewtimberlake/elixir-pdf.svg)](https://github.com/andrewtimberlake/elixir-pdf/commits/master)

The missing PDF library for Elixir.

## Usage

```elixir
Pdf.build([size: :a4, compress: true], fn pdf ->
  pdf
  |> Pdf.set_info(title: "Demo PDF")
  |> Pdf.set_font("Helvetica", 10)
  |> Pdf.text_at({200,200}, "Welcome to Pdf")
  |> Pdf.write_to("test.pdf")
end)
```

## Installation

Add `:pdf` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pdf, "~> 0.6"},
  ]
end
```

## Copyright and License

Copyright (c) 2016 Andrew Timberlake

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
