defmodule Meddie.Invitations.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Accounts.User
  alias Meddie.Spaces.Space

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "invitations" do
    field :email, :string
    field :token, :string
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :space, Space
    belongs_to :invited_by, User, foreign_key: :invited_by_id

    timestamps(type: :utc_datetime)
  end

  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :space_id, :invited_by_id, :token, :expires_at, :accepted_at])
    |> validate_required([:email, :invited_by_id, :token, :expires_at])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/)
    |> unique_constraint(:token)
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:invited_by_id)
  end

  def accept_changeset(invitation) do
    change(invitation, accepted_at: DateTime.utc_now(:second))
  end

  @doc """
  Returns true if the invitation has expired.
  """
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(:second), expires_at) == :gt
  end

  @doc """
  Returns true if the invitation has been accepted.
  """
  def accepted?(%__MODULE__{accepted_at: accepted_at}) do
    not is_nil(accepted_at)
  end
end
