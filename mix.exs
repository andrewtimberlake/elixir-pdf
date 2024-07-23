defmodule Pdf.Mixfile do
  use Mix.Project

  @version "0.7.0"
  @github_url "https://github.com/andrewtimberlake/elixir-pdf"

  def project do
    [
      app: :pdf,
      name: "PDF",
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      # Code style
      {:credo, "~> 1.0", only: [:dev, :test]},

      # Docs
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "Elixir API for generating PDF documents.",
      maintainers: ["Andrew Timberlake"],
      contributors: ["Andrew Timberlake"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README* fonts),
      links: %{"GitHub" => @github_url}
    ]
  end

  defp docs do
    [
      extras: [
        "CHANGELOG.md": [],
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"],
        "extra_doc/Tables.md": []
      ],
      main: "readme",
      source_url: @github_url,
      source_ref: @version,
      canonical: "http://hexdocs.pm/pdf",
      assets: %{"extra_doc/assets" => "assets"},
      formatters: ["html"]
    ]
  end
end
