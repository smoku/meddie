defmodule Meddie.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  alias Meddie.Spaces.Space
  alias Meddie.People.Person
  alias Meddie.Documents.Biomarker

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending parsing parsed failed)
  @document_types ~w(lab_results medical_report other)

  schema "documents" do
    field :filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :storage_path, :string
    field :status, :string, default: "pending"
    field :document_type, :string, default: "lab_results"
    field :summary, :string
    field :page_count, :integer
    field :document_date, :date
    field :error_message, :string

    belongs_to :space, Space
    belongs_to :person, Person
    has_many :biomarkers, Biomarker

    timestamps(type: :utc_datetime)
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :filename,
      :content_type,
      :file_size,
      :storage_path,
      :status,
      :document_type,
      :summary,
      :page_count,
      :document_date,
      :error_message
    ])
    |> validate_required([:filename, :content_type, :file_size, :storage_path])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:document_type, @document_types)
    |> validate_number(:file_size, greater_than: 0)
  end

  def statuses, do: @statuses
  def document_types, do: @document_types
end
