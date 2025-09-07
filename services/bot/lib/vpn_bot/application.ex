defmodule VpnBot.Application do
  @moduledoc """
  OTP application for the Telegram bot service.

  Starts an `ExGram` bot in polling mode with `VpnBot.Handler`.
  """
  use Application
  require Logger

  @doc """
  Boots the supervision tree and configures ExGram polling handler.
  """
  def start(_t, _a) do
    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_boot", module: "VpnBot.Application"}))
    children = [{ExGram, [method: :polling, handler: VpnBot.Handler]}]
    Supervisor.start_link(children, strategy: :one_for_one, name: VpnBot.Supervisor)
  end
end
