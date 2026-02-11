defmodule Meddie.Repo.Migrations.AddSourceToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :source, :string, null: false, default: "web"
    end
  end
end
