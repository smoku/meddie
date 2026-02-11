defmodule Meddie.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Spaces.Space
  alias Meddie.People.Person
  alias Meddie.Accounts.User
  alias Meddie.Conversations.Message

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :title, :string

    belongs_to :space, Space
    belongs_to :person, Person
    belongs_to :user, User
    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :person_id])
    |> validate_length(:title, max: 255)
  end
end
