defmodule VpnApi.Migrations.CredentialsExpiresAt do
  use Ecto.Migration
  def change do
    alter table(:credentials) do
      add :expires_at, :utc_datetime
    end
    create index(:credentials, [:expires_at])
  end
end

