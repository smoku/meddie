defmodule Meddie.Spaces.Space do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Spaces.Membership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "spaces" do
    field :name, :string

    has_many :memberships, Membership

    timestamps(type: :utc_datetime)
  end

  def changeset(space, attrs) do
    space
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end
end
