defmodule Meddie.Conversations do
  @moduledoc """
  The Conversations context. Manages Ask Meddie conversations and messages within a Space.
  Conversations are private — only visible to the user who created them.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts.Scope
  alias Meddie.Conversations.{Conversation, Message, MemoryUpdate}

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

  # -- Memory Updates --

  @doc """
  Creates a memory update record for undo tracking.
  """
  def create_memory_update(attrs) do
    %MemoryUpdate{inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)}
    |> MemoryUpdate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Reverts a memory update by setting reverted to true.
  Returns the memory update with previous_value for restoring the person field.
  """
  def revert_memory_update(memory_update_id) do
    memory_update = Repo.get!(MemoryUpdate, memory_update_id)

    memory_update
    |> Ecto.Changeset.change(reverted: true)
    |> Repo.update()
  end

  @doc """
  Gets memory updates for a message.
  """
  def list_memory_updates_for_message(message_id) do
    from(mu in MemoryUpdate,
      where: mu.message_id == ^message_id,
      order_by: [asc: mu.inserted_at]
    )
    |> Repo.all()
  end
end
