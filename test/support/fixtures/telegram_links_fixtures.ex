defmodule Meddie.TelegramLinksFixtures do
  @moduledoc """
  Test helpers for creating Telegram links.
  """

  alias Meddie.Telegram.Links

  def telegram_link_fixture(space, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "telegram_id" => System.unique_integer([:positive])
      })

    {:ok, link} = Links.create_link(space.id, attrs)
    link
  end
end
