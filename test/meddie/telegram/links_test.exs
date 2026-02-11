defmodule Meddie.Telegram.LinksTest do
  use Meddie.DataCase

  alias Meddie.Telegram.Links

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures

  setup do
    %{user: user, space: space, scope: scope} = user_with_space_fixture(%{locale: "en"})
    person = person_fixture(scope, %{"name" => "Test Person"})
    %{user: user, space: space, scope: scope, person: person}
  end

  describe "create_link/2" do
    test "creates a link with telegram_id only", %{space: space} do
      assert {:ok, link} = Links.create_link(space.id, %{"telegram_id" => 123_456})
      assert link.telegram_id == 123_456
      assert link.space_id == space.id
      assert link.user_id == nil
      assert link.person_id == nil
    end

    test "creates a link with all fields", %{space: space, user: user, person: person} do
      assert {:ok, link} =
               Links.create_link(space.id, %{
                 "telegram_id" => 789_012,
                 "user_id" => user.id,
                 "person_id" => person.id
               })

      assert link.telegram_id == 789_012
      assert link.user_id == user.id
      assert link.person_id == person.id
    end

    test "enforces unique telegram_id per space", %{space: space} do
      {:ok, _} = Links.create_link(space.id, %{"telegram_id" => 111})
      assert {:error, changeset} = Links.create_link(space.id, %{"telegram_id" => 111})
      assert changeset.errors[:telegram_id]
    end

    test "allows same telegram_id in different spaces", %{space: space} do
      %{space: other_space} = user_with_space_fixture(%{locale: "en"})

      {:ok, _} = Links.create_link(space.id, %{"telegram_id" => 222})
      assert {:ok, _} = Links.create_link(other_space.id, %{"telegram_id" => 222})
    end

    test "requires telegram_id", %{space: space} do
      assert {:error, changeset} = Links.create_link(space.id, %{})
      assert changeset.errors[:telegram_id]
    end
  end

  describe "get_link/2" do
    test "returns the link when found", %{space: space, user: user} do
      {:ok, _} =
        Links.create_link(space.id, %{"telegram_id" => 333, "user_id" => user.id})

      link = Links.get_link(333, space.id)
      assert link.telegram_id == 333
      assert link.user != nil
      assert link.user.id == user.id
    end

    test "returns nil when not found", %{space: space} do
      assert Links.get_link(999_999, space.id) == nil
    end

    test "preloads user and person", %{space: space, user: user, person: person} do
      {:ok, _} =
        Links.create_link(space.id, %{
          "telegram_id" => 444,
          "user_id" => user.id,
          "person_id" => person.id
        })

      link = Links.get_link(444, space.id)
      assert link.user.id == user.id
      assert link.person.id == person.id
    end
  end

  describe "list_links/1" do
    test "returns all links for a space", %{space: space} do
      {:ok, _} = Links.create_link(space.id, %{"telegram_id" => 100})
      {:ok, _} = Links.create_link(space.id, %{"telegram_id" => 200})

      links = Links.list_links(space.id)
      assert length(links) == 2
    end

    test "does not include links from other spaces", %{space: space} do
      %{space: other_space} = user_with_space_fixture(%{locale: "en"})

      {:ok, _} = Links.create_link(space.id, %{"telegram_id" => 100})
      {:ok, _} = Links.create_link(other_space.id, %{"telegram_id" => 200})

      links = Links.list_links(space.id)
      assert length(links) == 1
    end
  end

  describe "update_link/2" do
    test "updates link fields", %{space: space, person: person} do
      {:ok, link} = Links.create_link(space.id, %{"telegram_id" => 555})
      assert link.person_id == nil

      {:ok, updated} = Links.update_link(link, %{"person_id" => person.id})
      assert updated.person_id == person.id
    end
  end

  describe "delete_link/1" do
    test "deletes a link", %{space: space} do
      {:ok, link} = Links.create_link(space.id, %{"telegram_id" => 666})
      assert {:ok, _} = Links.delete_link(link)
      assert Links.get_link(666, space.id) == nil
    end
  end
end
