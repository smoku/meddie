defmodule Meddie.Conversations do
  @moduledoc """
  The Conversations context. Manages Ask Meddie conversations and messages within a Space.
  Conversations are private — only visible to the user who created them.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.Conversations.{Conversation, Message, ProfileUpdate}

  # -- Conversations --

  @doc """
  Returns the user's conversations in the current space, most recent first.
  Preloads person and includes message count.
  """
  def list_conversations(%Scope{user: user, space: space}) do
    from(c in Conversation,
      where: c.space_id == ^space.id and c.user_id == ^user.id,
      order_by: [desc: c.updated_at],
      preload: [:person]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single conversation owned by the user in the current space.
  Preloads messages (ordered asc) and person.
  Raises `Ecto.NoResultsError` if not found or not owned by user.
  """
  def get_conversation!(%Scope{user: user, space: space}, id) do
    from(c in Conversation,
      where: c.id == ^id and c.space_id == ^space.id and c.user_id == ^user.id,
      preload: [
        :person,
        messages: ^from(m in Message, order_by: [asc: m.inserted_at])
      ]
    )
    |> Repo.one!()
  end

  @doc """
  Creates a conversation for the current user in the current space.
  """
  def create_conversation(%Scope{user: user, space: space}, attrs \\ %{}) do
    %Conversation{space_id: space.id, user_id: user.id}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a conversation (e.g., title, person_id).
  """
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a conversation owned by the user.
  """
  def delete_conversation(%Scope{user: user}, %Conversation{} = conversation) do
    if conversation.user_id == user.id do
      Repo.delete(conversation)
    else
      {:error, :unauthorized}
    end
  end

  # -- Messages --

  @doc """
  Creates a message in a conversation.
  """
  def create_message(%Conversation{} = conversation, attrs) do
    %Message{conversation_id: conversation.id, inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns messages for a conversation, ordered by inserted_at asc.
  Supports `:limit` option for truncation.
  """
  def list_messages(%Conversation{} = conversation, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from(m in Message,
        where: m.conversation_id == ^conversation.id,
        order_by: [asc: m.inserted_at]
      )

    query = if limit, do: from(q in query, limit: ^limit), else: query

    Repo.all(query)
  end

  @doc """
  Returns the count of messages for a conversation.
  """
  def count_messages(%Conversation{} = conversation) do
    from(m in Message,
      where: m.conversation_id == ^conversation.id,
      select: count(m.id)
    )
    |> Repo.one()
  end

  # -- Rate Limiting --

  @doc """
  Counts all user-role messages sent today in the current space.
  Rate limit is shared across all users in a space.
  """
  def count_messages_today(%Scope{space: space}) do
    today_start = Date.utc_today() |> DateTime.new!(~T[00:00:00], "Etc/UTC")

    from(m in Message,
      join: c in Conversation,
      on: m.conversation_id == c.id,
      where: c.space_id == ^space.id,
      where: m.role == "user",
      where: m.inserted_at >= ^today_start,
      select: count(m.id)
    )
    |> Repo.one()
  end

  # -- Profile Updates --

  @doc """
  Creates a profile update record for undo tracking.
  """
  def create_profile_update(attrs) do
    %ProfileUpdate{inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    |> ProfileUpdate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Reverts a profile update by setting reverted to true.
  Returns the profile update with previous_value for restoring the person field.
  """
  def revert_profile_update(profile_update_id) do
    profile_update = Repo.get!(ProfileUpdate, profile_update_id)

    profile_update
    |> Ecto.Changeset.change(reverted: true)
    |> Repo.update()
  end

  @doc """
  Gets profile updates for a message.
  """
  def list_profile_updates_for_message(message_id) do
    from(pu in ProfileUpdate,
      where: pu.message_id == ^message_id,
      order_by: [asc: pu.inserted_at]
    )
    |> Repo.all()
  end

  # -- Telegram --

  @doc """
  Gets or creates the active Telegram conversation for a user in a space.
  Returns the most recent telegram conversation, or creates a new one.
  """
  def get_or_create_telegram_conversation(%Scope{user: user, space: space} = scope, person_id) do
    query =
      from(c in Conversation,
        where:
          c.space_id == ^space.id and
            c.user_id == ^user.id and
            c.source == "telegram",
        order_by: [desc: c.updated_at],
        limit: 1,
        preload: [:person]
      )

    case Repo.one(query) do
      %Conversation{} = conv -> {:ok, conv}
      nil -> create_conversation(scope, %{"source" => "telegram", "person_id" => person_id})
    end
  end

  # Telegram conversations auto-close after 8 hours of inactivity
  @telegram_idle_timeout_hours 8

  # Number of messages to carry forward from the previous conversation
  @previous_conversation_messages 30

  @doc """
  Gets or creates the active Telegram conversation for a telegram_link (no user required).
  Queries by telegram_link_id instead of user_id.

  If the most recent conversation has been idle for more than #{@telegram_idle_timeout_hours} hours,
  a new conversation is created automatically.
  """
  def get_or_create_telegram_link_conversation(space, telegram_link, person_id \\ nil) do
    query =
      from(c in Conversation,
        where:
          c.space_id == ^space.id and
            c.telegram_link_id == ^telegram_link.id and
            c.source == "telegram",
        order_by: [desc: c.updated_at],
        limit: 1,
        preload: [:person]
      )

    case Repo.one(query) do
      %Conversation{updated_at: updated_at} = conv ->
        cutoff = DateTime.add(DateTime.utc_now(), -@telegram_idle_timeout_hours, :hour)

        if DateTime.compare(updated_at, cutoff) == :lt do
          create_telegram_conversation(space, telegram_link, person_id)
        else
          {:ok, conv}
        end

      nil ->
        create_telegram_conversation(space, telegram_link, person_id)
    end
  end

  @doc """
  Creates a new Telegram conversation for a telegram_link.
  """
  def create_telegram_conversation(space, telegram_link, person_id \\ nil) do
    %Conversation{
      space_id: space.id,
      telegram_link_id: telegram_link.id,
      user_id: telegram_link.user_id
    }
    |> Conversation.changeset(%{"source" => "telegram", "person_id" => person_id})
    |> Repo.insert()
  end

  @doc """
  Returns the last N user/assistant messages from the previous Telegram conversation
  for the same link. Used to carry forward context after auto-close.

  Returns an empty list if no previous conversation exists.
  """
  def get_previous_conversation_messages(space, telegram_link, limit \\ @previous_conversation_messages) do
    query =
      from(c in Conversation,
        where:
          c.space_id == ^space.id and
            c.telegram_link_id == ^telegram_link.id and
            c.source == "telegram",
        order_by: [desc: c.updated_at],
        offset: 1,
        limit: 1
      )

    case Repo.one(query) do
      %Conversation{} = conv ->
        list_messages(conv)
        |> Enum.filter(&(&1.role in ["user", "assistant"]))
        |> Enum.take(-limit)

      nil ->
        []
    end
  end
end
