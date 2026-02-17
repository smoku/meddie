defmodule Meddie.Repo.Migrations.AddPositionToPeople do
  use Ecto.Migration

  def change do
    alter table(:people) do
      add :position, :integer, null: false, default: 0
    end
  end
end
