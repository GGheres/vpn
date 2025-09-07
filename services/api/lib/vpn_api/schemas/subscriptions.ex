
defmodule VpnApi.Schemas.Subscription do
  @moduledoc """
  Subscription record describing a user's plan, quota and expiry.

  Tracks `bytes_limit`/`bytes_used` counters and `expires_at` timestamp.
  """
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :user_id, :plan, :expires_at, :bytes_limit, :bytes_used, :inserted_at, :updated_at]}
  schema "subscriptions" do
    field :plan, :string
    field :expires_at, :utc_datetime
    field :bytes_limit, :integer
    field :bytes_used, :integer, default: 0
    belongs_to :user, VpnApi.Schemas.User
    timestamps()
  end
  @doc """
  Validates creation/update params for a subscription.
  Requires `:user_id`, `:plan`; enforces positive `:bytes_limit`.
  """
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:user_id, :plan, :expires_at, :bytes_limit, :bytes_used]) |> validate_required([:user_id, :plan]) |> validate_number(:bytes_limit, greater_than: 0) |> assoc_constraint(:user)
  end
end
