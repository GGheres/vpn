defmodule VpnBot.Handler do
  @moduledoc """
  Telegram bot command handler.

  Commands:
  - `/start` — приветствие и подсказки по командам.
  - `/config` — выдать VLESS‑ссылку, создаёт пользователя при отсутствии.
  - `/renew` — заглушка для продления подписки (будущая интеграция).
  """
  use ExGram.Bot, name: :vpn_bot, setup_commands: true
  require Logger

  command("start", description: "Start bot")
  command("config", description: "Get config link")
  command("renew", description: "Renew subscription")

  # Обработка команды /start — отправляет приветствие и список команд
  def handle({:command, :start, _}, cnt) do
    ExGram.send_message(cnt.chat.id, "Добро пожаловать! Команды: /config, /renew")
  end

  # Обработка команды /config — запрашивает ссылку у API и отправляет её пользователю
  def handle({:command, :config, _}, cnt) do
    api_base = System.get_env("API_BASE", "http://api:4000")
    host = System.get_env("VLESS_HOST", "localhost")
    port = System.get_env("XRAY_LISTEN_PORT", "443") |> to_int(443)
    public_key = System.get_env("XRAY_PUBLIC_KEY", "")
    short_id = System.get_env("XRAY_SHORT_ID", "")
    server_name = System.get_env("XRAY_REALITY_SERVER_NAME", "")

    payload = %{
      tg_id: cnt.from.id,
      host: host,
      port: port,
      public_key: public_key,
      short_id: short_id,
      server_name: server_name,
      label: "vpn"
    }

    with {:ok, link} <- issue_link(api_base, payload) do
      ExGram.send_message(cnt.chat.id, "Твой конфиг:\n" <> link)
      Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_config_issued", module: "VpnBot.Handler", user_id: cnt.from.id}))
    else
      {:error, :user_not_found} ->
        # Авто-создание пользователя и повторная попытка
        _ = Req.post(api_base <> "/v1/users", json: %{tg_id: cnt.from.id, status: "active"})
        case issue_link(api_base, payload) do
          {:ok, link} ->
            ExGram.send_message(cnt.chat.id, "Твой конфиг:\n" <> link)
            Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_config_issued", module: "VpnBot.Handler", user_id: cnt.from.id}))
          {:error, reason} ->
            ExGram.send_message(cnt.chat.id, "Ошибка выдачи конфига: #{inspect(reason)}")
          _ -> :ok
        end
      {:error, reason} ->
        ExGram.send_message(cnt.chat.id, "Ошибка выдачи конфига: #{inspect(reason)}")
    end
  end

  # Обработка команды /renew — зарезервировано для биллинга
  def handle({:command, :renew, _}, _cnt) do
    # TODO: интеграция с биллингом
    :ok
  end

  # Игнор остальных событий/сообщений
  def handle(_, _), do: :ignore

  # Делает REST‑запрос к API `/v1/issue` и возвращает ссылку VLESS.
  # Возвращает `{:ok, link}` или `{:error, reason}`.
  defp issue_link(api_base, payload) do
    case Req.post(api_base <> "/v1/issue", json: payload) do
      {:ok, %Req.Response{status: 200, body: %{"vless" => link}}} -> {:ok, link}
      {:ok, %Req.Response{status: 404, body: %{"event" => "user_not_found"}}} -> {:error, :user_not_found}
      {:ok, %Req.Response{} = resp} -> {:error, {:bad_status, resp.status}}
      {:error, e} -> {:error, e}
    end
  end

  # Безопасно приводит строку/число к integer, иначе возвращает `default`.
  defp to_int(nil, default), do: default
  defp to_int(<<>>, default), do: default
  defp to_int(v, default) do
    case Integer.parse(to_string(v)) do
      {n, _} -> n
      :error -> default
    end
  end
end

