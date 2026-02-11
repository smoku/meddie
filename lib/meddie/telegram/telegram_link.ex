defmodule Meddie.Telegram.TelegramLink do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias Meddie.Spaces.Space
  alias Meddie.Accounts.User
  alias Meddie.People.Person

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "telegram_links" do
    field :telegram_id, :integer

    belongs_to :space, Space
    belongs_to :user, User
    belongs_to :person, Person

    timestamps(type: :utc_datetime)
  end

  def changeset(link, attrs) do
    link
    |> cast(attrs, [:telegram_id, :user_id, :person_id])
    |> validate_required([:telegram_id])
    |> unique_constraint([:telegram_id, :space_id])
    |> foreign_key_constraint(:space_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:person_id)
    |> validate_person_in_space()
  end

  defp validate_person_in_space(changeset) do
    with person_id when not is_nil(person_id) <- get_change(changeset, :person_id),
         space_id when not is_nil(space_id) <- get_field(changeset, :space_id) do
      exists =
        from(p in Person, where: p.id == ^person_id and p.space_id == ^space_id, select: true)
        |> Meddie.Repo.one()

      if exists, do: changeset, else: add_error(changeset, :person_id, "not found in this space")
    else
      _ -> changeset
    end
  end
end
