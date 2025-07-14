defmodule Inherit.MixProject do
  use Mix.Project

  @source_url "https://github.com/dockyard/inherit"
  @version "0.1.0"

  def project do
    [
      app: :inherit,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      deps: deps(),
      docs: docs()
    ]
  end

  defp docs do
    [
      extras: extras(),
      main: "readme",
      source_url: @source_url,
      source_ref: @version
    ]
  end

  def description do
    "Pseudo-inheritance in Elixir"
  end

  def package do
    %{
      maintainers: ["Brian Cardarella"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Built by DockYard, Expert Elixir & Phoenix Consultants" => "https://dockyard.com/phoenix-consulting"
      }
    }
  end

  defp extras do
    ["README.md", "LICENSE.md"]
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
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end
end
