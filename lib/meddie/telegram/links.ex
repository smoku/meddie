defmodule Meddie.Telegram.Links do
  @moduledoc """
  Context module for managing Telegram links.
  A telegram_link maps a Telegram user ID to a Space, with optional User and Person associations.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo
  alias Meddie.Telegram.TelegramLink

  @doc """
  Gets a telegram link by telegram_id and space_id.
  Preloads user and person associations.
  Returns nil if not found.
  """
  def get_link(telegram_id, space_id) when is_integer(telegram_id) do
    from(tl in TelegramLink,
      where: tl.telegram_id == ^telegram_id and tl.space_id == ^space_id,
      preload: [:user, :person]
    )
    |> Repo.one()
  end

  @doc """
  Gets a telegram link by ID. Raises if not found.
  """
  def get_link!(id) do
    Repo.get!(TelegramLink, id) |> Repo.preload([:user, :person])
  end

  @doc """
  Lists all telegram links for a space, preloaded with user and person.
  """
  def list_links(space_id) do
    from(tl in TelegramLink,
      where: tl.space_id == ^space_id,
      order_by: [asc: tl.telegram_id],
      preload: [:user, :person]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new telegram link for a space.
  """
  def create_link(space_id, attrs) do
    %TelegramLink{space_id: space_id}
    |> TelegramLink.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing telegram link.
  """
  def update_link(%TelegramLink{} = link, attrs) do
    link
    |> TelegramLink.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a telegram link.
  """
  def delete_link(%TelegramLink{} = link) do
    Repo.delete(link)
  end
end
