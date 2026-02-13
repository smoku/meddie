defmodule Meddie.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create table(:memories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :content_hash, :string, null: false
      add :embedding, :vector, size: 1536, null: false
      add :source, :string, null: false, default: "chat"
      add :source_message_id, references(:messages, type: :binary_id, on_delete: :nilify_all)
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:memories, [:user_id, :space_id])
    create unique_index(:memories, [:content_hash, :user_id, :space_id])

    # Full-text search
    execute """
    ALTER TABLE memories
    ADD COLUMN content_tsv tsvector
    GENERATED ALWAYS AS (to_tsvector('simple', content)) STORED
    """

    execute "CREATE INDEX memories_content_tsv_idx ON memories USING gin(content_tsv)"

    # Vector similarity index (HNSW)
    execute """
    CREATE INDEX memories_embedding_idx ON memories
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """
  end

  def down do
    drop table(:memories)
  end
end
