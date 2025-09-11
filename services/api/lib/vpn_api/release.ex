defmodule VpnApi.Release do
  @moduledoc """
  Helpers to run Ecto migrations inside the production release.

  Usage on a running container:
    /app/bin/vpn_api eval "VpnApi.Release.migrate"
  """
  @app :vpn_api

  def migrate do
    Application.load(@app)
    repos = Application.fetch_env!(@app, :ecto_repos)
    Enum.each(repos, &migrate_repo/1)
    :ok
  end

  defp migrate_repo(repo) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn repo ->
      Ecto.Migrator.run(repo, :up, all: true)
    end)
  end
end

