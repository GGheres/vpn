defmodule VpnApi.Migrations.CreateCredentials do
  use Ecto.Migration
  def change do
    create table(:credentials) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :node_id, references(:nodes, on_delete: :delete_all)
      add :uuid, :uuid
      add :revoked_at, :utc_datetime
      timestamps()
    end
    create index(:credentials, [:user_id])
    create index(:credentials, [:node_id])
    create unique_index(:credentials, [:uuid])
  end
end
