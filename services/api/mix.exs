
defmodule VpnApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :vpn_api,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :inets, :ssl, :eex],
      mod: {VpnApi.Application, []}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.15"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.11"},
      {:postgrex, ">= 0.0.0"},
      {:redix, ">= 1.0.0"},
      {:uuid, "~> 1.1"},
      {:telemetry, "~> 1.2"}
    ]
  end
end
