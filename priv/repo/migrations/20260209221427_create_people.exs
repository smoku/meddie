defmodule Meddie.Repo.Migrations.CreatePeople do
  use Ecto.Migration

  def change do
    create table(:people, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :date_of_birth, :date
      add :sex, :string, null: false
      add :height_cm, :integer
      add :weight_kg, :float
      add :health_notes, :text
      add :supplements, :text
      add :medications, :text

      timestamps(type: :utc_datetime)
    end

    create index(:people, [:space_id])

    create unique_index(:people, [:user_id, :space_id],
             where: "user_id IS NOT NULL",
             name: :people_user_id_space_id_index
           )
  end
end
