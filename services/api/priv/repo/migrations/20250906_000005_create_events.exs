
defmodule VpnApi.Migrations.CreateEvents do
  use Ecto.Migration
  def change do
    create table(:events) do
      add :ts, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all)
      add :event, :string
      add :payload_json, :map
    end
    create index(:events, [:user_id])
    create index(:events, [:event])
    create index(:events, [:ts])
  end
end
