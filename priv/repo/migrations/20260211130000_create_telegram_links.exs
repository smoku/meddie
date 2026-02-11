defmodule Meddie.Repo.Migrations.CreateTelegramLinks do
  use Ecto.Migration

  def change do
    create table(:telegram_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :telegram_id, :bigint, null: false
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :person_id, references(:people, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:telegram_links, [:telegram_id, :space_id])
    create index(:telegram_links, [:space_id])
  end
end
