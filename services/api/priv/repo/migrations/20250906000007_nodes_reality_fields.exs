defmodule VpnApi.Migrations.NodesRealityFields do
  use Ecto.Migration
  def change do
    alter table(:nodes) do
      add :reality_dest, :string
      add :reality_public_key, :text
      add :reality_server_names, {:array, :string}, default: []
      add :reality_short_ids, {:array, :string}, default: []
      add :listen_port, :integer, default: 443
    end
    create index(:nodes, [:listen_port])
  end
end
