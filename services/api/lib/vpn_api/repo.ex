
defmodule VpnApi.Repo do
  @moduledoc """
  Ecto repository for the API service.

  - Uses `Ecto.Adapters.Postgres`.
  - Reads its configuration from the `:vpn_api` OTP application environment.
  """
  use Ecto.Repo, otp_app: :vpn_api, adapter: Ecto.Adapters.Postgres
end
