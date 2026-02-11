defmodule Meddie.Repo.Migrations.AddTelegramBotTokenToSpaces do
  use Ecto.Migration

  def change do
    alter table(:spaces) do
      add :telegram_bot_token, :string
    end
  end
end
