defmodule VpnApi.Migrations.CreateSubscriptions do
  use Ecto.Migration
  def change do
    create table(:subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :plan, :string
      add :expires_at, :utc_datetime
      add :bytes_limit, :bigint
      add :bytes_used, :bigint, default: 0
      timestamps()
    end
    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:expires_at])
  end
end
