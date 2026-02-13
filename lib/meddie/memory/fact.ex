defmodule Meddie.Memory.Fact do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Accounts.User
  alias Meddie.Conversations.Message
  alias Meddie.Spaces.Space

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @sources ~w(chat manual)

  schema "memories" do
    field :content, :string
    field :content_hash, :string
    field :embedding, Pgvector.Ecto.Vector
    field :source, :string, default: "chat"
    field :active, :boolean, default: true

    belongs_to :user, User
    belongs_to :space, Space
    belongs_to :source_message, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(fact, attrs) do
    fact
    |> cast(attrs, [:content, :content_hash, :embedding, :source, :source_message_id, :active])
    |> validate_required([:content, :content_hash, :embedding, :source])
    |> validate_inclusion(:source, @sources)
    |> validate_length(:content, max: 500)
    |> unique_constraint([:content_hash, :user_id, :space_id])
  end
end
