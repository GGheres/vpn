
defmodule VpnBot.MixProject do
  use Mix.Project
  def project, do: [app: :vpn_bot, version: "0.1.0", elixir: "~> 1.16", deps: deps()]
  def application, do: [extra_applications: [:logger, :ssl, :inets], mod: {VpnBot.Application, []}]
  defp deps, do: [{:ex_gram, "~> 0.47"}, {:jason, "~> 1.4"}, {:req, "~> 0.5"}]
end
