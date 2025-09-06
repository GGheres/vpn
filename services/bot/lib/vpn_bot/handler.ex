
defmodule VpnBot.Handler do
  use ExGram.Bot, setup_commands: true
  require Logger

  command("start", description: "Start bot")
  command("config", description: "Get config link")
  command("renew", description: "Renew subscription")

  def handle({:command, :start, _}, cnt) do
    ExGram.send_message(cnt.chat.id, "Добро пожаловать! Команды: /config, /renew")
  end

  def handle({:command, :config, _}, cnt) do
    uuid = System.get_env("XRAY_CLIENT_UUID", "demo")
    vless = "vless://" <> uuid <> "@localhost:443?encryption=none&security=reality#vpn"
    ExGram.send_message(cnt.chat.id, "Твой конфиг:
" <> vless)
    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_config_issued", module: "VpnBot.Handler", user_id: cnt.from.id}))
  end

  def handle({:command, :renew, _}, cnt) do
    ExGram.send_message(cnt.chat.id, "Продление оформлено (stub).")
  end

  def handle(_, _), do: :ignore
end
