defmodule Meddie.Repo.Migrations.AddBiomarkersSpacePersonIndex do
  use Ecto.Migration

  def change do
    create index(:biomarkers, [:space_id, :person_id])
  end
end
