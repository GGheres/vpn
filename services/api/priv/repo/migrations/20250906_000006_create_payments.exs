
defmodule VpnApi.Migrations.CreatePayments do
  use Ecto.Migration
  def change do
    create table(:payments) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :amount, :integer
      add :currency, :string
      add :status, :string
      add :provider, :string
      add :meta_json, :map
      timestamps()
    end
    create index(:payments, [:user_id])
    create index(:payments, [:status])
    create index(:payments, [:provider])
    create index(:payments, [:inserted_at])
  end
end
