defmodule Meddie.Documents.Biomarker do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Spaces.Space
  alias Meddie.People.Person
  alias Meddie.Documents.Document

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(normal low high unknown)

  schema "biomarkers" do
    field :name, :string
    field :value, :string
    field :numeric_value, :float
    field :unit, :string
    field :reference_range_low, :float
    field :reference_range_high, :float
    field :reference_range_text, :string
    field :status, :string
    field :page_number, :integer
    field :category, :string

    belongs_to :document, Document
    belongs_to :space, Space
    belongs_to :person, Person

    timestamps(type: :utc_datetime)
  end

  def changeset(biomarker, attrs) do
    biomarker
    |> cast(attrs, [
      :name,
      :value,
      :numeric_value,
      :unit,
      :reference_range_low,
      :reference_range_high,
      :reference_range_text,
      :status,
      :page_number,
      :category
    ])
    |> validate_required([:name, :value, :status])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses
end
