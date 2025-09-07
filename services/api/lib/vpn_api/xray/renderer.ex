
defmodule VpnApi.Xray.Renderer do
  @moduledoc "Renders /xray/config.json and hot-reloads Xray."
  alias VpnApi.Core.{Log, Retry}

  @spec render(map(), [binary()]) :: {:ok, map()} | {:error, map()}
  def render(params, uuids) when is_map(params) and is_list(uuids) do
    try do
      clients = Enum.map(uuids, &%{"id" => &1, "flow" => "xtls-rprx-vision"})
      config = %{
        "log" => %{"loglevel" => "warning"},
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

  @spec write!(map(), binary()) :: :ok | {:error, map()}
  def write!(map, path \\ "/xray/config.json") when is_map(map) and is_binary(path) do
    with {:ok, json} <- Jason.encode(map, pretty: true),
         :ok <- File.write(path, json) do
      :ok
    else
      {:error, reason} -> {:error, %{error_code: "VPN-003", reason: {:encode_or_write_failed, reason}}}
    end
  end

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
