
defmodule VpnApi.Xray.Renderer do
  @moduledoc """
  Builds an Xray REALITY VLESS configuration and manages hot reloads.

  Responsibilities:
  - `render/2` — create in‑memory Xray JSON config from params and client UUIDs.
  - `write!/2` — write JSON config to a file (defaults to `/xray/config.json`).
  - `reload/0` — send `USR1` to the `xray` docker container to hot‑reload.

  Expected params keys for `render/2` (with defaults):
  - `"listen_port"` (443), `"dest"` ("www.cloudflare.com:443"),
    `"serverNames"`, `"privateKey"`, `"publicKey"`, `"shortIds"`.
  """
  alias VpnApi.Core.{Log, Retry}

  @doc """
  Render an Xray REALITY VLESS config for given params and client UUIDs.

  Returns `{:ok, map}` with the config or `{:error, %{error_code: String.t(), reason: term}}`.
  """
  @spec render(map(), list()) :: {:ok, map()} | {:error, map()}
  def render(params, list) when is_map(params) and is_list(list) do
    try do
      loglevel = Map.get(params, "loglevel", "warning")
      clients =
        case list do
          [%{} | _] ->
            Enum.map(list, fn m -> m |> Map.put_new("flow", "xtls-rprx-vision") end)
          _ ->
            Enum.map(list, &%{"id" => &1, "flow" => "xtls-rprx-vision"})
        end
      config = %{
        "log" => %{"loglevel" => loglevel},
        "inbounds" => [
          %{
            "tag" => "vless-in",
            "listen" => "0.0.0.0",
            "port" => Map.get(params, "listen_port", 443),
            "protocol" => "vless",
            "settings" => %{"clients" => clients, "decryption" => "none"},
            "streamSettings" => %{
              "network" => "tcp",
              "security" => "reality",
              "realitySettings" => %{
                "dest" => Map.get(params, "dest", "www.cloudflare.com:443"),
                "serverNames" => Map.get(params, "serverNames", ["www.cloudflare.com"]),
                "privateKey" => Map.get(params, "privateKey", ""),
                "publicKey" => Map.get(params, "publicKey", ""),
                "shortIds" => Map.get(params, "shortIds", ["0123456789abcdef"]),
                "xver" => 0,
                "show" => false
              }
            }
          }
        ],
        "outbounds" => [%{"protocol" => "freedom", "tag" => "direct"}]
      }
      {:ok, config}
    rescue
      e -> {:error, %{error_code: "VPN-003", reason: {:render_failed, inspect(e)}}}
    end
  end

  @doc """
  Encode the config to JSON and write it to `path`.

  Returns `:ok` or `{:error, %{error_code: "VPN-003", reason: term}}`.
  """
  @spec write!(map(), binary()) :: :ok | {:error, map()}
  def write!(map, path \\ "/xray/config.json") when is_map(map) and is_binary(path) do
    with {:ok, json} <- Jason.encode(map, pretty: true),
         :ok <- File.write(path, json) do
      :ok
    else
      {:error, reason} -> {:error, %{error_code: "VPN-003", reason: {:encode_or_write_failed, reason}}}
    end
  end

  @doc """
  Hot‑reload Xray by signaling the `xray` docker container with `USR1`.

  Retries with backoff up to 3 times; returns `:ok` on success.
  """
  @spec reload() :: :ok | {:error, map()}
  def reload do
    Retry.with_backoff(fn ->
      case System.cmd("sh", ["-lc", "docker kill -s USR1 xray"], stderr_to_stdout: true) do
        {_, 0} -> Log.info("xray_reload_ok", "Xray.Renderer", %{}); {:ok, :ok}
        {out, _} -> Log.error("VPN-002", "xray_reload_failed", "Xray.Renderer", %{details: %{out: out}}); {:error, :reload_failed}
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, reason} -> {:error, %{error_code: "VPN-002", reason: reason}}
    end
  end
end
