defmodule Meddie.Repo.Migrations.MigrateTelegramToLinks do
  use Ecto.Migration

  def up do
    # Add telegram_link_id to conversations
    alter table(:conversations) do
      add :telegram_link_id, references(:telegram_links, type: :binary_id, on_delete: :nilify_all)
    end

    # Make user_id nullable on conversations (for telegram-only links without a user)
    execute "ALTER TABLE conversations ALTER COLUMN user_id DROP NOT NULL"

    # Migrate existing users.telegram_id → telegram_links
    # For each user with telegram_id, create a link for each space they're a member of
    execute """
    INSERT INTO telegram_links (id, telegram_id, space_id, user_id, inserted_at, updated_at)
    SELECT gen_random_uuid(), u.telegram_id, m.space_id, u.id, NOW(), NOW()
    FROM users u
    JOIN memberships m ON m.user_id = u.id
    WHERE u.telegram_id IS NOT NULL
    """

    # Update existing telegram conversations to reference the new link
    execute """
    UPDATE conversations c
    SET telegram_link_id = tl.id
    FROM telegram_links tl
    WHERE c.source = 'telegram'
      AND c.user_id = tl.user_id
      AND c.space_id = tl.space_id
    """

    # Drop the old unique index and column from users
    drop_if_exists index(:users, [:telegram_id])

    alter table(:users) do
      remove :telegram_id
    end
  end

  def down do
    # Re-add telegram_id to users
    alter table(:users) do
      add :telegram_id, :bigint
    end

    create unique_index(:users, [:telegram_id], where: "telegram_id IS NOT NULL")

    # Migrate data back from telegram_links to users
    execute """
    UPDATE users u
    SET telegram_id = tl.telegram_id
    FROM telegram_links tl
    WHERE tl.user_id = u.id
    """

    # Restore user_id NOT NULL constraint
    execute "ALTER TABLE conversations ALTER COLUMN user_id SET NOT NULL"

    # Remove telegram_link_id from conversations
    alter table(:conversations) do
      remove :telegram_link_id
    end
  end
end
