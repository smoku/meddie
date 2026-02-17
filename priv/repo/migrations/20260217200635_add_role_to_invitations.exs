defmodule Meddie.Repo.Migrations.AddRoleToInvitations do
  use Ecto.Migration

  def change do
    alter table(:invitations) do
      add :role, :string, default: "member"
    end
  end
end
