defmodule Meddie.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :storage_path, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :document_type, :string, null: false, default: "lab_results"
      add :summary, :text
      add :page_count, :integer
      add :document_date, :date
      add :error_message, :string

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:space_id])
    create index(:documents, [:person_id])
  end
end
