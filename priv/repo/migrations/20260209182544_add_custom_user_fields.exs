defmodule Meddie.Repo.Migrations.AddCustomUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string, null: false, default: ""
      add :platform_admin, :boolean, null: false, default: false
      add :locale, :string, null: false, default: "pl"
    end
  end
end
