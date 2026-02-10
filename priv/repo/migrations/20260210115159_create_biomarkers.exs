defmodule Meddie.Repo.Migrations.CreateBiomarkers do
  use Ecto.Migration

  def change do
    create table(:biomarkers, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all),
        null: false

      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :value, :string, null: false
      add :numeric_value, :float
      add :unit, :string
      add :reference_range_low, :float
      add :reference_range_high, :float
      add :reference_range_text, :string
      add :status, :string, null: false
      add :page_number, :integer
      add :category, :string

      timestamps(type: :utc_datetime)
    end

    create index(:biomarkers, [:document_id])
    create index(:biomarkers, [:person_id, :name])
  end
end
