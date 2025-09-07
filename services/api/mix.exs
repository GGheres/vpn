
defmodule VpnApi.MixProject do
  @moduledoc """
  Mix project for the API application.
  Contains project metadata, runtime application spec, and dependencies.
  """
  use Mix.Project

  @doc "Project metadata (name, version, toolchain, deps)."
  def project do
    [
      app: :vpn_api,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  @doc "Application specification: extra apps and application module."
  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl, :eex],
      mod: {VpnApi.Application, []}
    ]
  end

  # Runtime dependencies for the API.
  defp deps do
    [
      {:plug, "~> 1.15"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:redix, ">= 1.0.0"},
      {:uuid, "~> 1.1"},
      {:telemetry, "~> 1.2"},
      {:ex_doc, "~> 0.32", only: :dev, runtime: false}
    ]
  end
end
