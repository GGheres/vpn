defmodule VpnApi.Migrations.CreateNodes do
  use Ecto.Migration
  def change do
    create table(:nodes) do
      add :region, :string
      add :ip, :string
      add :status, :string
      add :version, :string
      add :last_sync_at, :utc_datetime
      timestamps()
    end
    create index(:nodes, [:region])
    create index(:nodes, [:status])
  end
end
