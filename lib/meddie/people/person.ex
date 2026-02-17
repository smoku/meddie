defmodule Meddie.People.Person do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Spaces.Space
  alias Meddie.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "people" do
    field :name, :string
    field :date_of_birth, :date
    field :sex, :string
    field :height_cm, :integer
    field :weight_kg, :float
    field :health_notes, :string
    field :supplements, :string
    field :medications, :string
    field :position, :integer, default: 0

    belongs_to :space, Space
    belongs_to :user, User
    has_many :documents, Meddie.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(person, attrs) do
    person
    |> cast(attrs, [
      :name,
      :date_of_birth,
      :sex,
      :height_cm,
      :weight_kg,
      :health_notes,
      :supplements,
      :medications
    ])
    |> validate_required([:name, :sex])
    |> validate_inclusion(:sex, ["male", "female"])
    |> validate_length(:name, max: 255)
    |> validate_length(:health_notes, max: 50_000)
    |> validate_length(:supplements, max: 50_000)
    |> validate_length(:medications, max: 50_000)
    |> validate_number(:height_cm, greater_than: 0)
    |> validate_number(:weight_kg, greater_than: 0)
    |> unique_constraint([:user_id, :space_id],
      name: :people_user_id_space_id_index,
      message: "is already linked to another person in this space"
    )
  end
end
