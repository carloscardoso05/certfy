defmodule Certfy.Release do
  @moduledoc """
  Tasks executed against a release, e.g. `bin/certfy eval "Certfy.Release.migrate()"`.
  """

  @app :certfy

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _repo, _apps} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end

    :ok
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _repo, _apps} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, :down, to: version)
      end)
  end

  @doc """
  Runs `priv/repo/seeds.exs`, creating the first admin from `CERTFY_ADMIN_EMAIL`.
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _repo, _apps} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Code.eval_file(seeds_path())
        end)
    end

    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp seeds_path do
    Application.app_dir(@app, "priv/repo/seeds.exs")
  end
end
