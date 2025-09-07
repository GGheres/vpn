
defmodule VpnApi.Core.Retry do
  @moduledoc """
  Simple retry helper with exponential backoff (up to 3 attempts).

  Backoff: `250ms * 4^attempt + jitter(0..200ms)`.
  """

  @doc """
  Calls `fun` until it returns `{:ok, value}` or attempts are exhausted.

  Returns the `{:ok, value}` on success, otherwise `{:error, :max_retries}`.
  """
  def with_backoff(fun), do: do_try(fun, 0)
  defp do_try(fun, attempt) when attempt < 3 do
    case fun.() do
      {:ok, _} = ok -> ok
      {:error, _} ->
        :timer.sleep(trunc(:math.pow(4, attempt) * 250 + :rand.uniform(200)))
        do_try(fun, attempt + 1)
    end
  end
  # After 3 attempts, give up
  defp do_try(_fun, _attempt), do: {:error, :max_retries}
end
