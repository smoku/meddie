defmodule Meddie.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :space_id, references(:spaces, type: :binary_id, on_delete: :delete_all)

      add :invited_by_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :token, :string, null: false
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invitations, [:token])
    create index(:invitations, [:email])
  end
end
