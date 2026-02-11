defmodule Meddie.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Conversations.Conversation

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(user assistant system)

  schema "messages" do
    field :role, :string
    field :content, :string
    field :inserted_at, :utc_datetime
    belongs_to :conversation, Conversation
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content])
    |> validate_required([:role, :content])
    |> validate_inclusion(:role, @roles)
  end

  def roles, do: @roles
end
