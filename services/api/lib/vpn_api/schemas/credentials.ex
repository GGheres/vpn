
defmodule VpnApi.Schemas.Credential do
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :user_id, :node_id, :uuid, :revoked_at, :inserted_at, :updated_at]}
  schema "credentials" do
    field :uuid, Ecto.UUID
    field :revoked_at, :utc_datetime
    belongs_to :user, VpnApi.Schemas.User
    belongs_to :node, VpnApi.Schemas.Node
    timestamps()
  end
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:user_id, :node_id, :uuid, :revoked_at]) |> validate_required([:user_id, :node_id, :uuid]) |> assoc_constraint(:user) |> assoc_constraint(:node) |> unique_constraint(:uuid)
  end
end
