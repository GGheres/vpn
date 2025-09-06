
defmodule VpnApi.Schemas.Payment do
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
  def changeset(struct, attrs) do
    struct |> cast(attrs, [:user_id, :amount, :currency, :status, :provider, :meta_json]) |> validate_required([:user_id, :amount, :currency]) |> validate_number(:amount, greater_than: 0) |> assoc_constraint(:user)
  end
end
