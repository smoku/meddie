defmodule Meddie.Repo.Migrations.CreateConversationsAndMessages do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :title, :string

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:space_id])
    create index(:conversations, [:person_id])
    create index(:conversations, [:user_id, :space_id])

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :role, :string, null: false
      add :content, :text, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:messages, [:conversation_id])

    create table(:memory_updates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :person_id, references(:people, type: :binary_id, on_delete: :delete_all), null: false
      add :field, :string, null: false
      add :action, :string, null: false
      add :text, :text, null: false
      add :previous_value, :text
      add :reverted, :boolean, null: false, default: false
      add :inserted_at, :utc_datetime, null: false
    end
  end
end
