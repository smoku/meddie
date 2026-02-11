defmodule Meddie.Conversations.MemoryUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Conversations.Message
  alias Meddie.People.Person

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @fields ~w(health_notes supplements medications)
  @actions ~w(append remove)

  schema "memory_updates" do
    field :field, :string
    field :action, :string
    field :text, :string
    field :previous_value, :string
    field :reverted, :boolean, default: false
    field :inserted_at, :utc_datetime

    belongs_to :message, Message
    belongs_to :person, Person
  end

  def changeset(memory_update, attrs) do
    memory_update
    |> cast(attrs, [:field, :action, :text, :previous_value, :message_id, :person_id])
    |> validate_required([:field, :action, :text, :message_id, :person_id])
    |> validate_inclusion(:field, @fields)
    |> validate_inclusion(:action, @actions)
  end

  def fields, do: @fields
  def actions, do: @actions
end
