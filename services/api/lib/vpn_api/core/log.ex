
defmodule VpnApi.Core.Log do
  @moduledoc "Structured JSON logs."
  require Logger
  def info(event, module, opts \\ %{}) do
    Logger.info(Jason.encode!(Map.merge(%{ts: DateTime.utc_now(), level: "info", event: event, module: module}, Map.take(opts, [:req_id, :user_id, :details, :fingerprint]))))
  end
  def error(error_code, event, module, opts \\ %{}) do
    Logger.error(Jason.encode!(Map.merge(%{ts: DateTime.utc_now(), level: "error", event: event, error_code: error_code, module: module}, Map.take(opts, [:req_id, :user_id, :details, :fingerprint]))))
  end
end
