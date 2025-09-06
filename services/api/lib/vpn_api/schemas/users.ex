
defmodule VpnApi.Schemas.User do
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
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:tg_id, :status]) |> validate_number(:tg_id, greater_than: 0) |> validate_length(:status, max: 32)
  end
end
