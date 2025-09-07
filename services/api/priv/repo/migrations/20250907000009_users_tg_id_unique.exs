defmodule VpnApi.Migrations.UsersTgIdUnique do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  # Remove duplicates safely, then create unique index concurrently
  def up do
    # 1) Remove rows with NULL tg_id (not allowed for uniqueness semantics)
    execute("DELETE FROM users WHERE tg_id IS NULL;")

    # 2) Collapse duplicates by keeping the smallest id per tg_id
    execute("""
    DELETE FROM users u
    USING users k
    WHERE u.tg_id = k.tg_id
      AND u.id > k.id;
    """)

    # 3) Create the unique index without locking the table
    create_if_not_exists unique_index(:users, [:tg_id], name: :users_tg_id_unique, concurrently: true)
  end

  def down do
    drop_if_exists index(:users, [:tg_id], name: :users_tg_id_unique)
  end
end
