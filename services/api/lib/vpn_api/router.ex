
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
    with tg_id when is_integer(tg_id) <- Map.get(p, "tg_id"),
         %User{} = user <- Repo.one(from u in User, where: u.tg_id == ^tg_id, order_by: [asc: u.id], limit: 1) || {:error, :not_found_user},
         %Node{} = node <- pick_node(Map.get(p, "node_id")) || {:error, :not_found_node},
         {:ok, cred} <- ensure_credential(user.id, node.id),
         {:ok, link} <- Vless.render(cred.uuid, %{
           host: Map.get(p, "host", "localhost"),
           port: Map.get(p, "port", 443),
           public_key: Map.get(p, "public_key", ""),
           short_id: Map.get(p, "short_id", ""),
           server_name: Map.get(p, "server_name", ""),
           label: Map.get(p, "label", "vpn")
         }) do
      Log.info("vless_issued", "Router", %{user_id: user.id, details: %{node_id: node.id}})
      send_json(conn, 200, %{vless: link}, "vless_issued")
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

      uuids = Repo.all(from c in Credential, where: c.node_id == ^node_id, select: c.uuid)

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

      case Renderer.render(params, uuids) do
        {:ok, cfg} ->
          case Renderer.write!(cfg, "/xray/config.json") do
            :ok -> Log.info("xray_config_written", "Router", %{details: %{node_id: id, clients: length(uuids)}})
                   send_json(conn, 202, %{"written" => true, "clients" => length(uuids)}, "xray_config_written")
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
    with %Node{} = node <- Repo.get(Node, String.to_integer(id)) || throw(:not_found),
         changeset <- Node.changeset(node, conn.body_params),
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
  defp ensure_credential(user_id, node_id) do
    case Repo.one(from c in Credential, where: c.user_id == ^user_id and c.node_id == ^node_id) do
      %Credential{} = c -> {:ok, c}
      nil -> %Credential{user_id: user_id, node_id: node_id, uuid: Ecto.UUID.generate()} |> Credential.changeset(%{}) |> Repo.insert()
    end
  rescue
    e -> {:error, %{error_code: "DB-001", reason: inspect(e)}}
  end

  # Sends a JSON response and logs the event as info.
  defp send_json(conn, status, data, event), do: (Log.info(event, "Router", %{details: data}); conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(data)))

  # Sends a standardized JSON error response and logs the event as error.
  defp send_error(conn, status, code, event, details), do: (Log.error(code, event, "Router", %{details: details}); conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(%{error: true, error_code: code, event: event, details: details})))
end
