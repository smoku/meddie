defmodule Meddie.Repo.Migrations.AddContentHashToDocuments do
  use Ecto.Migration

  def change do
    alter table(:documents) do
      add :content_hash, :string
    end

    create unique_index(:documents, [:person_id, :content_hash],
      name: :documents_person_id_content_hash_index
    )
  end
end
