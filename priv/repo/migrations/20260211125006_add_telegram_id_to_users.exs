defmodule Meddie.Repo.Migrations.AddTelegramIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :telegram_id, :bigint
    end

    create unique_index(:users, [:telegram_id], where: "telegram_id IS NOT NULL")
  end
end
