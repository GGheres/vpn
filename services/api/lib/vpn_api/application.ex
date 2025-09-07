
defmodule VpnApi.Application do
  @moduledoc """
  OTP application entrypoint for the API service.

  Supervised children:
  - `VpnApi.Repo` — Ecto repository (PostgreSQL connection pool).
  - `Bandit` — HTTP server running the `VpnApi.Router` on configured `app_port`.

  The listening port is taken from the `:vpn_api, :app_port` application env.
  """
  use Application
  require Logger

  @doc """
  Starts the supervision tree for the API service.

  Returns `{:ok, pid}` or `{:error, reason}` as per `Supervisor.start_link/2`.
  """
  def start(_type, _args) do
    children = [
      VpnApi.Repo,
      {Bandit, plug: VpnApi.Router, scheme: :http, port: app_port()}
    ]

    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "app_boot", module: "VpnApi.Application"}))
    Supervisor.start_link(children, strategy: :one_for_one, name: VpnApi.Supervisor)
  end

  # Fetches the HTTP port from application environment.
  # Raises if the configuration key is missing.
  defp app_port, do: Application.fetch_env!(:vpn_api, :app_port)
end
