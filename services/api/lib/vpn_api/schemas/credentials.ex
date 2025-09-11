
defmodule VpnApi.Schemas.Credential do
  @moduledoc """
  Credential linking a user to a node with a VLESS UUID.

  Used for generating per‑user client entries in Xray config and issuing links.
  """
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :user_id, :node_id, :uuid, :revoked_at, :inserted_at, :updated_at]}
  schema "credentials" do
    field :uuid, Ecto.UUID
    field :revoked_at, :utc_datetime
    field :expires_at, :utc_datetime
    belongs_to :user, VpnApi.Schemas.User
    belongs_to :node, VpnApi.Schemas.Node
    timestamps()
  end
  @doc """
  Validates creation/update params for a credential and enforces constraints.
  """
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:user_id, :node_id, :uuid, :revoked_at, :expires_at])
    |> validate_required([:user_id, :node_id, :uuid])
    |> assoc_constraint(:user)
    |> assoc_constraint(:node)
    |> unique_constraint(:uuid)
  end
end
