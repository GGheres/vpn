
defmodule VpnApi.Migrations.CreateUsers do
  use Ecto.Migration
  def change do
    create table(:users) do
      add :tg_id, :bigint
      add :status, :string
      timestamps()
    end
    create index(:users, [:tg_id])
    create index(:users, [:status])
  end
end
