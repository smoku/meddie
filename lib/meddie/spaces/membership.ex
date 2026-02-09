defmodule Meddie.Spaces.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Accounts.User
  alias Meddie.Spaces.Space

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    field :role, :string, default: "member"

    belongs_to :user, User
    belongs_to :space, Space

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :space_id, :role])
    |> validate_required([:user_id, :space_id, :role])
    |> validate_inclusion(:role, ~w(admin member))
    |> unique_constraint([:user_id, :space_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:space_id)
  end
end
