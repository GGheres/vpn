
defmodule VpnApi.Core.Retry do
  @moduledoc "Simple retry with backoff (3 attempts)."
  def with_backoff(fun), do: do_try(fun, 0)
  defp do_try(fun, attempt) when attempt < 3 do
    case fun.() do
      {:ok, _} = ok -> ok
      {:error, _} ->
        :timer.sleep(trunc(:math.pow(4, attempt) * 250 + :rand.uniform(200)))
        do_try(fun, attempt + 1)
    end
  end
  defp do_try(_fun, _attempt), do: {:error, :max_retries}
end
