
defmodule VpnApi.Router do
  @moduledoc """
  Minimal REST API for managing users, nodes, credentials and issuing VLESS links.

  Endpoints (JSON):
  - `GET /health` — health probe.
  - `POST /v1/users` — create user by Telegram id.
  - `POST /v1/issue` — issue VLESS link for a user on a node.
  - `POST /v1/nodes/:id/sync` — render and write Xray config for a node.
  - `POST /v1/nodes/:id/reload` — hot‑reload Xray via docker signal.
  - Nodes CRUD: `GET /v1/nodes`, `POST /v1/nodes`, `GET/patch/delete /v1/nodes/:id`.

  Responses are JSON; errors share the shape
  `%{error: true, error_code: String.t(), event: String.t(), details: map()}`.
  """
  use Plug.Router
  use Plug.ErrorHandler
  import Ecto.Query
  alias VpnApi.{Repo}
  alias VpnApi.Schemas.{User, Node, Credential}
  alias VpnApi.{Vless}
  alias VpnApi.Core.Log
  alias VpnApi.Xray.Renderer

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  # GET /health — simple readiness probe
  get "/health" do
    Log.info("health_ok", "Router", %{})
    send_json(conn, 200, %{ok: true}, "health_ok")
  end

  # POST /v1/users — create a user from JSON body: %{tg_id: integer, status?: string}
  post "/v1/users" do
    params = conn.body_params
    case User.changeset(%User{}, params) |> Repo.insert() do
      {:ok, user} -> (Log.info("user_created", "Router", %{user_id: user.id}); send_json(conn, 201, user, "user_created"))
      {:error, err} -> send_error(conn, 422, "DB-001", "user_create_failed", %{reason: inspect(err)})
    end
  end

  # POST /v1/issue — issue a VLESS link for a TG user on a node
  # Body accepts keys: tg_id, host, port, public_key, short_id, server_name, label, node_id?
  post "/v1/issue" do
    p = conn.body_params
    ttl_hours = pick_ttl_hours(p)
    single_active = truthy?(Map.get(p, "single_active"))
    revoke_scope = Map.get(p, "revoke_scope", "user_node")
    force_new = truthy?(Map.get(p, "force_new"))
    with tg_id when is_integer(tg_id) <- Map.get(p, "tg_id"),
         %User{} = user <- Repo.one(from u in User, where: u.tg_id == ^tg_id, order_by: [asc: u.id], limit: 1) || {:error, :not_found_user},
         %Node{} = node <- pick_node(Map.get(p, "node_id")) || {:error, :not_found_node},
         _ <- (if single_active, do: revoke_credentials(user.id, node.id, revoke_scope), else: :ok),
         {:ok, cred} <- ensure_credential(user.id, node.id, ttl_hours, force_new),
         {:ok, link} <- Vless.render(cred.uuid, %{
           host: Map.get(p, "host", System.get_env("VLESS_HOST") || (case node.ip do s when is_binary(s) and s != "" -> s; _ -> "localhost" end)),
           port: Map.get(p, "port", 443),
           public_key: Map.get(p, "public_key", ""),
           short_id: Map.get(p, "short_id", ""),
           server_name: Map.get(p, "server_name", ""),
           label: Map.get(p, "label", "vpn")
         }) do
      Log.info("vless_issued", "Router", %{user_id: user.id, details: %{node_id: node.id}})

      # Optional inline sync+reload when sync=true is passed
      {synced, sync_event} =
        if truthy?(Map.get(p, "sync")) do
          case inline_sync_and_reload(node.id) do
            :ok -> {true, "issue_inline_sync_ok"}
            {:error, _} -> {false, "issue_inline_sync_failed"}
          end
        else
          {false, nil}
        end

      if sync_event, do: Log.info(sync_event, "Router", %{details: %{node_id: node.id, synced: synced}})

      # Include node_id and synced flag (if requested) for clients/bots
      send_json(conn, 200, %{vless: link, node_id: node.id, synced: synced}, "vless_issued")
    else
      {:error, :not_found_user} -> send_error(conn, 404, "API-001", "user_not_found", %{})
      {:error, :not_found_node} -> send_error(conn, 404, "API-001", "node_not_found", %{})
      {:error, %{error_code: code} = e} -> send_error(conn, 500, code, "vless_issue_failed", e)
      {:error, reason} -> send_error(conn, 500, "VPN-003", "vless_issue_failed", %{reason: inspect(reason)})
      _ -> send_error(conn, 400, "API-001", "bad_request", %{})
    end
  end

  # POST /v1/nodes/:id/sync — render and write Xray config for node
  post "/v1/nodes/:id/sync" do
    json = case conn.body_params do m when is_map(m) -> m; _ -> %{} end
    with node_id <- String.to_integer(id),
         %Node{} = node <- Repo.get(Node, node_id) || throw(:not_found_node) do

      now = DateTime.utc_now()
      clients =
        Repo.all(
          from c in Credential,
            join: u in User, on: u.id == c.user_id,
            where:
              c.node_id == ^node_id and is_nil(c.revoked_at) and (
                is_nil(c.expires_at) or c.expires_at > ^now
              ),
            select: {c.uuid, u.id, u.tg_id}
        )
        |> Enum.map(fn {uuid, uid, tg} -> %{"id" => uuid, "email" => format_email(uid, tg)} end)

      params =
        %{
          "dest" => node.reality_dest || "www.cloudflare.com:443",
          "serverNames" => (node.reality_server_names || []),
          "privateKey" => node.reality_private_key || "",
          "publicKey" => node.reality_public_key || "",
          "shortIds" => (node.reality_short_ids || []),
          "listen_port" => node.listen_port || 443
        }
        |> Map.merge(json)

      case Renderer.render(params, clients) do
        {:ok, cfg} ->
          case Renderer.write!(cfg, "/xray/config.json") do
            :ok -> Log.info("xray_config_written", "Router", %{details: %{node_id: id, clients: length(clients)}})
                   send_json(conn, 202, %{"written" => true, "clients" => length(clients)}, "xray_config_written")
            {:error, e} -> send_error(conn, 500, "VPN-003", "xray_config_write_failed", %{reason: inspect(e)})
          end
        {:error, e} -> send_error(conn, 500, "VPN-003", "xray_config_render_failed", e)
      end
    else
      :not_found_node -> send_error(conn, 404, "API-001", "node_not_found", %{})
      _ -> send_error(conn, 400, "API-001", "bad_request", %{})
    end
  end

  # POST /v1/nodes/:id/reload — signal dockerized xray for hot reload
  post "/v1/nodes/:id/reload" do
    case VpnApi.Xray.Renderer.reload() do
      :ok -> send_json(conn, 200, %{reloaded: true, node_id: id}, "xray_reload_ok")
      {:error, e} -> send_error(conn, 500, "VPN-002", "xray_reload_failed", e)
    end
  end

  # NODES CRUD
  # GET /v1/nodes — list nodes
  get "/v1/nodes" do
    nodes = Repo.all(from n in Node, order_by: [asc: n.id])
    send_json(conn, 200, nodes, "nodes_list")
  end

  # POST /v1/nodes — create node
  post "/v1/nodes" do
    params = conn.body_params
    case Node.changeset(%Node{}, params) |> Repo.insert() do
      {:ok, node} -> send_json(conn, 201, node, "node_created")
      {:error, err} -> send_error(conn, 422, "DB-001", "node_create_failed", %{reason: inspect(err)})
    end
  end

  # GET /v1/nodes/:id — fetch node
  get "/v1/nodes/:id" do
    case Repo.get(Node, String.to_integer(id)) do
      %Node{} = node -> send_json(conn, 200, node, "node_fetched")
      nil -> send_error(conn, 404, "API-001", "node_not_found", %{})
    end
  end

  # PATCH /v1/nodes/:id — update node
  patch "/v1/nodes/:id" do
    attrs = sanitize_node_attrs(conn.body_params)
    with %Node{} = node <- Repo.get(Node, String.to_integer(id)) || throw(:not_found),
         changeset <- Node.changeset(node, attrs),
         {:ok, node2} <- Repo.update(changeset) do
      send_json(conn, 200, node2, "node_updated")
    else
      :not_found -> send_error(conn, 404, "API-001", "node_not_found", %{})
      {:error, err} -> send_error(conn, 422, "DB-001", "node_update_failed", %{reason: inspect(err)})
    end
  end

  # DELETE /v1/nodes/:id — remove node
  delete "/v1/nodes/:id" do
    case Repo.get(Node, String.to_integer(id)) do
      %Node{} = node ->
        case Repo.delete(node) do
          {:ok, _} -> (Log.info("node_deleted", "Router", %{details: %{id: node.id}}); send_resp(conn, 204, ""))
          {:error, err} -> send_error(conn, 422, "DB-001", "node_delete_failed", %{reason: inspect(err)})
        end
      nil -> send_error(conn, 404, "API-001", "node_not_found", %{})
    end
  end

  match _ do
    send_error(conn, 404, "API-001", "route_not_found", %{})
  end

  # helpers

  # Picks a node by id or the first available one.
  # Raises (via `throw(:not_found_node)`) if none found.
  defp pick_node(nil), do: Repo.one(from n in Node, order_by: [asc: n.id], limit: 1)
  defp pick_node(id),  do: Repo.get(Node, id)

  # Ensures there is a credential for `{user_id, node_id}`.
  # Returns `{:ok, %Credential{}}` or `{:error, %{error_code: String.t(), reason: term()}}`.
  defp ensure_credential(user_id, node_id, ttl_hours, force_new) do
    expires_at =
      case ttl_hours do
        n when is_integer(n) and n > 0 -> DateTime.add(DateTime.utc_now(), n * 3600, :second)
        _ -> nil
      end

    now = DateTime.utc_now()
    # Pick the most recent ACTIVE credential (not revoked and not expired) to reuse/extend.
    q = from c in Credential,
          where:
            c.user_id == ^user_id and c.node_id == ^node_id and is_nil(c.revoked_at) and (
              is_nil(c.expires_at) or c.expires_at > ^now
            ),
          order_by: [desc: c.inserted_at],
          limit: 1

    case Repo.one(q) do
      %Credential{} = c ->
        if force_new do
          attrs = %{user_id: user_id, node_id: node_id, uuid: Ecto.UUID.generate()}
          attrs = if expires_at, do: Map.put(attrs, :expires_at, expires_at), else: attrs
          %Credential{} |> Credential.changeset(attrs) |> Repo.insert()
        else
          new_exp =
            cond do
              is_nil(expires_at) -> nil
              is_nil(c.expires_at) -> expires_at
              DateTime.compare(expires_at, c.expires_at) == :gt -> expires_at
              true -> nil
            end
          changes = if new_exp, do: %{expires_at: new_exp}, else: %{}
          if map_size(changes) == 0, do: {:ok, c}, else: Repo.update(Credential.changeset(c, changes))
        end
      nil ->
        attrs = %{user_id: user_id, node_id: node_id, uuid: Ecto.UUID.generate()}
        attrs = if expires_at, do: Map.put(attrs, :expires_at, expires_at), else: attrs
        %Credential{} |> Credential.changeset(attrs) |> Repo.insert()
    end
  rescue
    e -> {:error, %{error_code: "DB-001", reason: inspect(e)}}
  end

  # Formats an Xray client email label to identify the user in logs.
  defp format_email(user_id, tg_id) do
    tg = case tg_id do
      nil -> ""
      v -> "|tg:" <> to_string(v)
    end
    "u:" <> to_string(user_id) <> tg
  end

  # Picks TTL (in hours) from request params. Supports "ttl_hours" or high-level plans.
  # Plans: trial (24h), week (7d), month (30d).
  defp pick_ttl_hours(p) do
    cond do
      is_integer(Map.get(p, "ttl_hours")) -> Map.get(p, "ttl_hours")
      is_binary(Map.get(p, "ttl_hours")) ->
        case Integer.parse(Map.get(p, "ttl_hours")) do
          {n, _} when n > 0 -> n
          _ -> plan_to_ttl(Map.get(p, "plan"))
        end
      true -> plan_to_ttl(Map.get(p, "plan"))
    end
  end

  defp plan_to_ttl(nil), do: nil
  defp plan_to_ttl("trial"), do: 24
  defp plan_to_ttl("week"), do: 24 * 7
  defp plan_to_ttl("month"), do: 24 * 30
  defp plan_to_ttl(_), do: nil

  # Parse common truthy representations (true/"true"/"1"/1)
  defp truthy?(true), do: true
  defp truthy?(1), do: true
  defp truthy?("true"), do: true
  defp truthy?("1"), do: true
  defp truthy?(_), do: false

  # Inline sync: render + write + reload using node settings and non-expired credentials
  defp inline_sync_and_reload(node_id) do
    with %Node{} = node <- Repo.get(Node, node_id),
         now <- DateTime.utc_now(),
         clients <- Repo.all(
                     from c in Credential,
                       join: u in User, on: u.id == c.user_id,
                       where: c.node_id == ^node_id and is_nil(c.revoked_at) and (is_nil(c.expires_at) or c.expires_at > ^now),
                       select: {c.uuid, u.id, u.tg_id}
                   ) |> Enum.map(fn {uuid, uid, tg} -> %{"id" => uuid, "email" => format_email(uid, tg)} end),
         lvl <- System.get_env("XRAY_LOG_LEVEL") || "error",
         stats_env <- System.get_env("XRAY_ENABLE_STATS"),
         enable_stats <- (stats_env in ["1", "true", "TRUE", "True"]),
         params <- %{
           "dest" => node.reality_dest || "www.cloudflare.com:443",
           "serverNames" => node.reality_server_names || [],
           "privateKey" => node.reality_private_key || "",
           "publicKey" => node.reality_public_key || "",
           "shortIds" => node.reality_short_ids || [],
           "listen_port" => node.listen_port || 443,
            "loglevel" => lvl,
            "enable_stats" => enable_stats
         },
         {:ok, cfg} <- Renderer.render(params, clients),
         :ok <- Renderer.write!(cfg, "/xray/config.json") do
      case Renderer.reload() do
        :ok -> :ok
        {:error, e} -> {:error, e}
      end
    else
      _ -> {:error, :sync_failed}
    end
  end

  # Revoke existing active credentials for a user (scope: "user" or "user_node").
  defp revoke_credentials(user_id, node_id, scope) do
    now = DateTime.utc_now()
    base = from c in Credential,
      where: c.user_id == ^user_id and is_nil(c.revoked_at) and (is_nil(c.expires_at) or c.expires_at > ^now)
    q = case scope do
      "user" -> base
      _ -> from c in base, where: c.node_id == ^node_id
    end
    Repo.update_all(q, set: [revoked_at: now])
    :ok
  end

  # Sanitize incoming node attributes: drop placeholders like "<XRAY_PUBLIC_KEY>"
  # and empty strings for key fields; filter placeholder entries from arrays.
  defp sanitize_node_attrs(attrs) when is_map(attrs) do
    placeholders = MapSet.new(["<XRAY_PUBLIC_KEY>", "<XRAY_REALITY_SERVER_NAME>", "<XRAY_SHORT_ID>", "<ВАШ_PUBLIC_IP>"])

    clean_bin = fn val ->
      cond do
        not is_binary(val) -> :drop
        val == "" -> :drop
        MapSet.member?(placeholders, val) -> :drop
        true -> val
      end
    end

    clean_list = fn arr ->
      case arr do
        list when is_list(list) ->
          list
          |> Enum.filter(fn s -> is_binary(s) and s != "" and not MapSet.member?(placeholders, s) end)
        _ -> []
      end
    end

    base = %{}
    base =
      case clean_bin.(Map.get(attrs, "reality_public_key")) do
        :drop -> base
        v -> Map.put(base, "reality_public_key", v)
      end
    base =
      case clean_bin.(Map.get(attrs, "reality_private_key")) do
        :drop -> base
        v -> Map.put(base, "reality_private_key", v)
      end
    base =
      case clean_bin.(Map.get(attrs, "ip")) do
        :drop -> base
        v -> Map.put(base, "ip", v)
      end
    base =
      case clean_bin.(Map.get(attrs, "reality_dest")) do
        :drop -> base
        v -> Map.put(base, "reality_dest", v)
      end
    base =
      case Map.get(attrs, "reality_server_names") do
        nil -> base
        v -> Map.put(base, "reality_server_names", clean_list.(v))
      end
    base =
      case Map.get(attrs, "reality_short_ids") do
        nil -> base
        v -> Map.put(base, "reality_short_ids", clean_list.(v))
      end
    # pass through other attrs like region/status/version/listen_port if provided
    base
    |> (fn m ->
      m = if Map.has_key?(attrs, "region"), do: Map.put(m, "region", Map.get(attrs, "region")), else: m
      m = if Map.has_key?(attrs, "status"), do: Map.put(m, "status", Map.get(attrs, "status")), else: m
      m = if Map.has_key?(attrs, "version"), do: Map.put(m, "version", Map.get(attrs, "version")), else: m
      m = if Map.has_key?(attrs, "listen_port"), do: Map.put(m, "listen_port", Map.get(attrs, "listen_port")), else: m
      m
    end).()
  end
  defp sanitize_node_attrs(other), do: %{}

  # Sends a JSON response and logs the event as info.
  defp send_json(conn, status, data, event), do: (Log.info(event, "Router", %{details: data}); conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(data)))

  # Sends a standardized JSON error response and logs the event as error.
  defp send_error(conn, status, code, event, details), do: (Log.error(code, event, "Router", %{details: details}); conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(%{error: true, error_code: code, event: event, details: details})))
end
