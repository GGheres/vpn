
defmodule VpnBot.MixProject do
  @moduledoc """
  Mix project for the Telegram bot service.
  Defines project properties, runtime application spec and dependencies.
  """
  use Mix.Project

  @doc "Project metadata (name, version, toolchain, deps)."
  def project, do: [app: :vpn_bot, version: "0.1.0", elixir: "~> 1.16", deps: deps()]

  @doc "Application specification for runtime."
  def application, do: [extra_applications: [:logger, :ssl, :inets], mod: {VpnBot.Application, []}]

  # Runtime dependencies for the bot.
  defp deps, do: [
    {:ex_gram, "~> 0.56"},
    {:tesla, "~> 1.7"},
    {:jason, "~> 1.4"},
    {:req, "~> 0.5"}
  ]
  |> Kernel.++([{:ex_doc, "~> 0.32", only: :dev, runtime: false}])
end
