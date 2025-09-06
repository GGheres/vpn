
defmodule VpnApi.Vless do
  @moduledoc "Builds vless:// links for REALITY + Vision."
  def render("", _opts), do: {:error, %{error_code: "VPN-003", reason: :invalid_uuid}}
  def render(uuid, opts) do
    host = Map.get(opts, :host, "localhost")
    port = Map.get(opts, :port, 443)
    pk   = Map.get(opts, :public_key, "")
    sid  = Map.get(opts, :short_id, "")
    sni  = Map.get(opts, :server_name, "")
    lbl  = URI.encode_www_form(Map.get(opts, :label, "vpn"))
    link =
      "vless://#{uuid}@#{host}:#{port}?encryption=none&security=reality&fp=chrome" <>
      (if pk  != "", do: "&pbk=#{pk}", else: "") <>
      (if sid != "", do: "&sid=#{sid}", else: "") <>
      (if sni != "", do: "&sni=#{sni}", else: "") <>
      "&type=tcp##{lbl}"
    {:ok, link}
  end
end
