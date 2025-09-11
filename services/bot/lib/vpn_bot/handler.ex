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
  command("config", description: "Get trial link (24h)")
  command("trial", description: "Get trial link (24h)")
  command("week", description: "Get paid link (7d)")
  command("month", description: "Get paid link (30d)")
  command("renew", description: "Renew subscription")

  # Обработка команды /start — отправляет приветствие и список команд
  def handle({:command, :start, msg}, _cnt) do
    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_start_cmd", module: "VpnBot.Handler", user_id: msg.from.id}))
    ExGram.send_message(msg.chat.id, "Добро пожаловать! Команды: /config, /renew")
  end

  # Обработка команды /config — запрашивает ссылку у API и отправляет её пользователю
  def handle({:command, :config, msg}, _cnt) do
    issue_for(msg, "trial", 24)
  end

  def handle({:command, :trial, msg}, _cnt) do
    issue_for(msg, "trial", 24)
  end

  def handle({:command, :week, msg}, _cnt) do
    issue_for(msg, "week", 24 * 7)
  end

  def handle({:command, :month, msg}, _cnt) do
    issue_for(msg, "month", 24 * 30)
  end

  defp issue_for(msg, plan, ttl_hours) do
    api_base = System.get_env("API_BASE", "http://api:4000")
    host = System.get_env("VLESS_HOST", "localhost")
    port = System.get_env("XRAY_LISTEN_PORT", "443") |> to_int(443)
    public_key = System.get_env("XRAY_PUBLIC_KEY", "")
    short_id = System.get_env("XRAY_SHORT_ID", "")
    server_name = System.get_env("XRAY_REALITY_SERVER_NAME", "")

    single_active = truthy?(System.get_env("BOT_SINGLE_ACTIVE") || "0")
    revoke_scope = System.get_env("BOT_REVOKE_SCOPE") || "user_node"
    force_new = truthy?(System.get_env("BOT_FORCE_NEW") || "0")
    payload = %{
      tg_id: msg.from.id,
      host: host,
      port: port,
      public_key: public_key,
      short_id: short_id,
      server_name: server_name,
      label: "vpn-" <> plan,
      plan: plan,
      ttl_hours: ttl_hours,
      force_new: force_new,
      single_active: single_active,
      revoke_scope: revoke_scope,
      sync: true
    }

    with {:ok, {link, node_id, synced}} <- issue_link(api_base, payload),
         :ok <- maybe_sync_and_reload_unless_synced(api_base, node_id, synced) do
      ExGram.send_message(msg.chat.id, "Твой конфиг:\n" <> link)
      Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_config_issued", module: "VpnBot.Handler", user_id: msg.from.id, details: %{node_id: node_id}}))
    else
      {:error, :user_not_found} ->
        # Авто-создание пользователя и повторная попытка
        _ = Req.post(api_base <> "/v1/users", json: %{tg_id: msg.from.id, status: "active"})
        case issue_link(api_base, Map.put(payload, :sync, true)) do
          {:ok, {link, node_id, synced}} ->
            _ = maybe_sync_and_reload_unless_synced(api_base, node_id, synced)
            ExGram.send_message(msg.chat.id, "Твой конфиг:\n" <> link)
            Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_config_issued", module: "VpnBot.Handler", user_id: msg.from.id, details: %{node_id: node_id}}))
          {:error, reason} ->
            ExGram.send_message(msg.chat.id, "Ошибка выдачи конфига: #{inspect(reason)}")
          _ -> :ok
        end
      {:error, reason} ->
        ExGram.send_message(msg.chat.id, "Ошибка выдачи конфига: #{inspect(reason)}")
    end
  end

  # Обработка команды /renew — зарезервировано для биллинга
  def handle({:command, :renew, _}, _cnt) do
    # TODO: интеграция с биллингом
    :ok
  end

  # Игнор остальных событий/сообщений
  def handle(other, cnt) do
    # Логируем непросмотренные апдейты для отладки
    Logger.info(Jason.encode!(%{ts: DateTime.utc_now(), level: "info", event: "bot_unmatched_update", module: "VpnBot.Handler", details: %{update: inspect(other)}}))
    :ignore
  end

  # Делает REST‑запрос к API `/v1/issue` и возвращает ссылку VLESS.
  # Возвращает `{:ok, {link, node_id, synced}}` или `{:error, reason}`.
  defp issue_link(api_base, payload) do
    case Req.post(api_base <> "/v1/issue", json: payload) do
      # Новый формат: {"vless": link, "node_id": id, "synced": bool}
      {:ok, %Req.Response{status: 200, body: %{"vless" => link} = body}} ->
        {:ok, {link, Map.get(body, "node_id"), Map.get(body, "synced")}}
      # Пользователь не найден
      {:ok, %Req.Response{status: 404, body: %{"event" => "user_not_found"}}} -> {:error, :user_not_found}
      {:ok, %Req.Response{} = resp} -> {:error, {:bad_status, resp.status}}
      {:error, e} -> {:error, e}
    end
  end

  # Если API уже выполнил sync (synced=true), пропускаем локальный sync.
  # Иначе триггерим синхронизацию Xray и горячую перезагрузку.
  defp maybe_sync_and_reload_unless_synced(_api_base, _node_id, true), do: :ok
  defp maybe_sync_and_reload_unless_synced(_api_base, nil, _), do: :ok
  defp maybe_sync_and_reload_unless_synced(api_base, node_id, _) when is_integer(node_id) do
    _ = Req.post(api_base <> "/v1/nodes/" <> Integer.to_string(node_id) <> "/sync", json: %{})
    case Req.post(api_base <> "/v1/nodes/" <> Integer.to_string(node_id) <> "/reload", json: %{}) do
      {:ok, %Req.Response{status: 200}} -> :ok
      _ -> :ok
    end
  end
  defp maybe_sync_and_reload_unless_synced(_api_base, _, _), do: :ok

  # Безопасно приводит строку/число к integer, иначе возвращает `default`.
  defp to_int(nil, default), do: default
  defp to_int(<<>>, default), do: default
  defp to_int(v, default) do
    case Integer.parse(to_string(v)) do
      {n, _} -> n
      :error -> default
    end
  end

  # Common truthy parsing for env flags
  defp truthy?("1"), do: true
  defp truthy?("true"), do: true
  defp truthy?("TRUE"), do: true
  defp truthy?(true), do: true
  defp truthy?(1), do: true
  defp truthy?(_), do: false
end
