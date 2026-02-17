defmodule Meddie.Repo.Migrations.AddAttachmentsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :attachment_path, :string
      add :attachment_type, :string
      add :attachment_name, :string
    end
  end
end
