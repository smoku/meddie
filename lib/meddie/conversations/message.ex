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
    field :attachment_path, :string
    field :attachment_type, :string
    field :attachment_name, :string
    field :inserted_at, :utc_datetime
    belongs_to :conversation, Conversation
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :attachment_path, :attachment_type, :attachment_name])
    |> validate_required([:role])
    |> validate_inclusion(:role, @roles)
    |> validate_content_or_attachment()
  end

  defp validate_content_or_attachment(changeset) do
    content = get_field(changeset, :content)
    attachment = get_field(changeset, :attachment_path)

    if (is_nil(content) or content == "") and is_nil(attachment) do
      add_error(changeset, :content, "either content or attachment is required")
    else
      changeset
    end
  end

  def roles, do: @roles
end
