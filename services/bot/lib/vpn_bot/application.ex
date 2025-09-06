
defmodule VpnBot.Application do
  use Application
  require Logger
  def start(_t, _a) do
    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_boot", module: "VpnBot.Application"}))
    children = [{ExGram, [method: :polling, handler: VpnBot.Handler]}]
    Supervisor.start_link(children, strategy: :one_for_one, name: VpnBot.Supervisor)
  end
end
