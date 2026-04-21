
defmodule VpnApi.Vless do
  @moduledoc """
  Helper to construct `vless://` links compatible with REALITY + Vision.

  Encodes optional parameters for Reality transport such as `public_key`,
  `short_id`, `server_name`, and a human label appended after `#`.
  """

  @doc """
  Build a VLESS link from a credential UUID and options.

  Options:
  - `:host` (default: "localhost")
  - `:port` (default: 443)
  - `:public_key` (Reality public key)
  - `:short_id` (Reality short id)
  - `:server_name` (SNI)
  - `:label` (label after '#', URL‑encoded)

  Returns `{:ok, binary}` or `{:error, %{error_code: "VPN-003", reason: term}}`.
  """
  def render("", _opts), do: {:error, %{error_code: "VPN-003", reason: :invalid_uuid}}
  def render(uuid, opts) do
    host = Map.get(opts, :host, "localhost")
    port = Map.get(opts, :port, 443)
    pk   = Map.get(opts, :public_key, "")
    sid  = Map.get(opts, :short_id, "")
    sni  = Map.get(opts, :server_name, "")
    lbl  = URI.encode_www_form(Map.get(opts, :label, "vpn"))

    with :ok <- validate_port(port) do
      link =
        "vless://#{uuid}@#{host}:#{port}?encryption=none&security=reality&fp=chrome&flow=xtls-rprx-vision" <>
        (if pk  != "", do: "&pbk=#{URI.encode_www_form(pk)}", else: "") <>
        (if sid != "", do: "&sid=#{URI.encode_www_form(sid)}", else: "") <>
        (if sni != "", do: "&sni=#{URI.encode_www_form(sni)}", else: "") <>
        "&type=tcp##{lbl}"
      {:ok, link}
    end
  end

  defp validate_port(port) when is_integer(port) and port >= 1 and port <= 65535, do: :ok
  defp validate_port(port) when is_binary(port) do
    case Integer.parse(port) do
      {n, ""} when n >= 1 and n <= 65535 -> :ok
      _ -> {:error, %{error_code: "VPN-003", reason: :invalid_port}}
    end
  end
  defp validate_port(_), do: {:error, %{error_code: "VPN-003", reason: :invalid_port}}
end
