
defmodule VpnApi.Application do
  @moduledoc """
  Starts Repo and Bandit HTTP server.
  """
  use Application
  require Logger

  def start(_type, _args) do
    children = [
      VpnApi.Repo,
      {Bandit, plug: VpnApi.Router, scheme: :http, options: [port: app_port()]}
    ]

    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "app_boot", module: "VpnApi.Application"}))
    Supervisor.start_link(children, strategy: :one_for_one, name: VpnApi.Supervisor)
  end

  defp app_port, do: Application.fetch_env!(:vpn_api, :app_port)
end
