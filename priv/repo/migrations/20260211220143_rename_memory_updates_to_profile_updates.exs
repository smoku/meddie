defmodule Meddie.Repo.Migrations.RenameMemoryUpdatesToProfileUpdates do
  use Ecto.Migration

  def change do
    rename table(:memory_updates), to: table(:profile_updates)
  end
end
