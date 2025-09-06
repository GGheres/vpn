
defmodule VpnApi.Schemas.Node do
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :region, :ip, :status, :version, :last_sync_at, :listen_port, :reality_dest, :reality_public_key, :reality_server_names, :reality_short_ids, :inserted_at, :updated_at]}
  schema "nodes" do
    field :region, :string
    field :ip, :string
    field :status, :string
    field :version, :string
    field :last_sync_at, :utc_datetime
    field :reality_dest, :string
    field :reality_public_key, :string
    field :reality_server_names, {:array, :string}, default: []
    field :reality_short_ids, {:array, :string}, default: []
    field :listen_port, :integer, default: 443
    has_many :credentials, VpnApi.Schemas.Credential
    timestamps()
  end
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:region, :ip, :status, :version, :last_sync_at, :reality_dest, :reality_public_key, :reality_server_names, :reality_short_ids, :listen_port]) |> validate_required([:region, :ip]) |> validate_number(:listen_port, greater_than: 0, less_than: 65536)
  end
end
