defmodule SnapAssert.MixProject do
  use Mix.Project

  def project do
    [
      app: :snap_assert,
      description: "Instant snapshot testing inside your ex_unit tests",
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Docs
      source_url: "https://github.com/alexkorban/snap_assert",
      homepage_url: "https://github.com/alexkorban/snap_assert",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ],
      package: [
        licenses: ["BSD-3-Clause"],
        links: %{"GitHub" => "https://github.com/alexkorban/snap_assert"}
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:sourceror, "~> 0.14"}
    ]
  end
end
