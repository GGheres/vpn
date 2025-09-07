
defmodule VpnApi.Schemas.Payment do
  @moduledoc """
  Payment record for tracking user top‑ups or charges.

  Fields include `amount` (integer, in minor units), `currency`, `status`,
  `provider`, and an opaque `meta_json` for provider payloads.
  """
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :user_id, :amount, :currency, :status, :provider, :meta_json, :inserted_at, :updated_at]}
  schema "payments" do
    field :amount, :integer
    field :currency, :string
    field :status, :string
    field :provider, :string
    field :meta_json, :map
    belongs_to :user, VpnApi.Schemas.User
    timestamps()
  end
  @doc """
  Validates creation/update params for a payment.
  Requires `:user_id`, `:amount (> 0)`, `:currency`.
  """
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:user_id, :amount, :currency, :status, :provider, :meta_json]) |> validate_required([:user_id, :amount, :currency]) |> validate_number(:amount, greater_than: 0) |> assoc_constraint(:user)
  end
end
