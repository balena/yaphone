defmodule Yaphone.MixProject do
  use Mix.Project

  def project do
    [
      app: :yaphone,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:sweet_xml, "~> 0.7"},

      # test related
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
