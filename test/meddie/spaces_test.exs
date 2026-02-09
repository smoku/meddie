defmodule Meddie.SpacesTest do
  use Meddie.DataCase, async: true

  alias Meddie.Spaces
  alias Meddie.Spaces.{Space, Membership}
  alias Meddie.Accounts.Scope

  import Meddie.AccountsFixtures
  import Meddie.SpacesFixtures

  describe "create_space/2" do
    test "creates a space and admin membership" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert {:ok, %Space{} = space} = Spaces.create_space(scope, %{name: "My Health"})
      assert space.name == "My Health"

      membership = Spaces.get_membership(user, space)
      assert membership.role == "admin"
    end

    test "returns error when name is blank" do
      user = user_fixture()
      scope = Scope.for_user(user)

      assert {:error, %Ecto.Changeset{}} = Spaces.create_space(scope, %{name: ""})
    end

    test "returns error when name exceeds max length" do
      user = user_fixture()
      scope = Scope.for_user(user)

      long_name = String.duplicate("a", 256)
      assert {:error, %Ecto.Changeset{}} = Spaces.create_space(scope, %{name: long_name})
    end
  end

  describe "list_user_spaces/1" do
    test "returns all spaces for a user" do
      user = user_fixture()
      space1 = space_fixture(user, %{name: "Alpha Space"})
      space2 = space_fixture(user, %{name: "Beta Space"})

      spaces = Spaces.list_user_spaces(user)
      assert length(spaces) == 2
      assert Enum.map(spaces, & &1.id) == [space1.id, space2.id]
    end

    test "does not return spaces the user does not belong to" do
      user1 = user_fixture()
      user2 = user_fixture()
      _space1 = space_fixture(user1)
      _space2 = space_fixture(user2)

      spaces = Spaces.list_user_spaces(user1)
      assert length(spaces) == 1
    end

    test "returns empty list when user has no spaces" do
      user = user_fixture()
      assert Spaces.list_user_spaces(user) == []
    end
  end

  describe "get_space!/1" do
    test "returns the space" do
      user = user_fixture()
      space = space_fixture(user)
      assert Spaces.get_space!(space.id).id == space.id
    end

    test "raises when space does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Spaces.get_space!("11111111-1111-1111-1111-111111111111")
      end
    end
  end

  describe "get_space_for_user/2" do
    test "returns space when user is a member" do
      user = user_fixture()
      space = space_fixture(user)
      assert Spaces.get_space_for_user(user, space.id).id == space.id
    end

    test "returns nil when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      space = space_fixture(user1)
      assert is_nil(Spaces.get_space_for_user(user2, space.id))
    end
  end

  describe "get_user_role/2" do
    test "returns admin for space creator" do
      user = user_fixture()
      space = space_fixture(user)
      assert Spaces.get_user_role(user, space) == "admin"
    end

    test "returns nil for non-member" do
      user1 = user_fixture()
      user2 = user_fixture()
      space = space_fixture(user1)
      assert is_nil(Spaces.get_user_role(user2, space))
    end
  end

  describe "list_space_members/1" do
    test "returns all members with user preloaded" do
      %{user: user, space: space, scope: scope} = user_with_space_fixture()

      members = Spaces.list_space_members(scope)
      assert length(members) == 1
      assert hd(members).user.id == user.id
      assert hd(members).space_id == space.id
    end
  end

  describe "remove_member/2" do
    test "removes a regular member" do
      %{scope: admin_scope, space: space} = user_with_space_fixture()

      member = user_fixture()

      {:ok, _} =
        Repo.insert(
          Membership.changeset(%Membership{}, %{
            user_id: member.id,
            space_id: space.id,
            role: "member"
          })
        )

      membership = Spaces.get_membership(member, space)
      assert {:ok, _} = Spaces.remove_member(admin_scope, membership.id)
      assert is_nil(Spaces.get_membership(member, space))
    end

    test "prevents removing the last admin" do
      %{scope: admin_scope, user: user, space: space} = user_with_space_fixture()

      membership = Spaces.get_membership(user, space)
      assert {:error, :last_admin} = Spaces.remove_member(admin_scope, membership.id)
    end

    test "allows removing an admin when another admin exists" do
      %{scope: scope, space: space} = user_with_space_fixture()

      second_admin = user_fixture()

      {:ok, _} =
        Repo.insert(
          Membership.changeset(%Membership{}, %{
            user_id: second_admin.id,
            space_id: space.id,
            role: "admin"
          })
        )

      second_membership = Spaces.get_membership(second_admin, space)
      assert {:ok, _} = Spaces.remove_member(scope, second_membership.id)
    end
  end

  describe "update_space/2" do
    test "updates the space name" do
      %{scope: scope} = user_with_space_fixture()

      assert {:ok, updated} = Spaces.update_space(scope, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "returns error for invalid data" do
      %{scope: scope} = user_with_space_fixture()

      assert {:error, %Ecto.Changeset{}} = Spaces.update_space(scope, %{name: ""})
    end
  end

  describe "change_space/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = Spaces.change_space(%Space{})
    end
  end
end
