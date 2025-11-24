defmodule Bosbase.MixProject do
  use Mix.Project

  def project do
    [
      app: :bosbase,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Bosbase.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.4"},
      {:finch, "~> 0.18"},
      {:websockex, "~> 0.4"},
      {:jason, "~> 1.4"}
    ]
  end
end
