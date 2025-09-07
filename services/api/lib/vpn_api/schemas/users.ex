
defmodule VpnApi.Schemas.User do
  @moduledoc """
  User model representing a Telegram user.

  Fields: `tg_id` (integer), `status` (string).
  Associations: subscriptions, credentials, payments, events.
  Encoded to JSON with selected fields for API responses.
  """
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :tg_id, :status, :inserted_at, :updated_at]}
  schema "users" do
    field :tg_id, :integer
    field :status, :string
    has_many :subscriptions, VpnApi.Schemas.Subscription
    has_many :credentials, VpnApi.Schemas.Credential
    has_many :payments, VpnApi.Schemas.Payment
    has_many :events, VpnApi.Schemas.Event
    timestamps()
  end
  @doc """
  Validates creation/update params for a user.

  Requires positive `:tg_id`; limits `:status` length.
  """
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:tg_id, :status]) |> validate_number(:tg_id, greater_than: 0) |> validate_length(:status, max: 32)
  end
end
