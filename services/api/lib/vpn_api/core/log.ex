
defmodule VpnApi.Core.Log do
  @moduledoc """
  Structured JSON logging helpers built on top of `Logger`.

  All logs include a UTC timestamp, level, event name, and module. Optional
  fields: `:req_id`, `:user_id`, `:details`, `:fingerprint`.
  """
  require Logger

  @doc """
  Logs an info event as a JSON line.
  """
  def info(event, module, opts \\ %{}) do
    Logger.info(Jason.encode!(Map.merge(%{ts: DateTime.utc_now(), level: "info", event: event, module: module}, Map.take(opts, [:req_id, :user_id, :details, :fingerprint]))))
  end

  @doc """
  Logs an error event as a JSON line with `error_code`.
  """
  def error(error_code, event, module, opts \\ %{}) do
    Logger.error(Jason.encode!(Map.merge(%{ts: DateTime.utc_now(), level: "error", event: event, error_code: error_code, module: module}, Map.take(opts, [:req_id, :user_id, :details, :fingerprint]))))
  end
end
