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

    token =
      case System.get_env("TELEGRAM_BOT_TOKEN") do
        nil ->
          Logger.error(Jason.encode!(%{ts: DateTime.utc_now(), level: "error", event: "bot_token_missing", module: "VpnBot.Application"}))
          raise "TELEGRAM_BOT_TOKEN is not set"
        <<>> ->
          Logger.error(Jason.encode!(%{ts: DateTime.utc_now(), level: "error", event: "bot_token_empty", module: "VpnBot.Application"}))
          raise "TELEGRAM_BOT_TOKEN is empty"
        t -> t
      end

    children = [
      # ExGram registry/root supervisor
      ExGram,
      # Actual bot supervisor (polling updates + dispatcher)
      {VpnBot.Handler, [method: :polling, token: token]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: VpnBot.Supervisor)
  end
end
