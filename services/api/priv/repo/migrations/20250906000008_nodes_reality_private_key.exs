defmodule VpnApi.Migrations.NodesRealityPrivateKey do
  use Ecto.Migration
  def change do
    alter table(:nodes) do
      add :reality_private_key, :text
    end
  end
end

