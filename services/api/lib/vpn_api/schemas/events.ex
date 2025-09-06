
defmodule VpnApi.Schemas.Event do
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :ts, :user_id, :event, :payload_json]}
  schema "events" do
    field :ts, :utc_datetime
    field :event, :string
    field :payload_json, :map
    belongs_to :user, VpnApi.Schemas.User
  end
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:ts, :user_id, :event, :payload_json]) |> validate_required([:ts, :event])
  end
end
