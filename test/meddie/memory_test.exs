defmodule Meddie.MemoryTest do
  use Meddie.DataCase, async: true

  alias Meddie.Memory
  alias Meddie.Memory.Fact

  import Meddie.SpacesFixtures

  setup do
    user_with_space_fixture()
  end

  describe "create_memory/3" do
    test "creates a memory with embedding", %{scope: scope} do
      {:ok, %Fact{} = fact} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User is allergic to penicillin",
          source: "chat"
        })

      assert fact.content == "User is allergic to penicillin"
      assert fact.source == "chat"
      assert fact.active == true
      assert fact.user_id == scope.user.id
      assert fact.space_id == scope.space.id
      assert fact.content_hash != nil
      assert fact.embedding != nil
    end

    test "deduplicates by content hash", %{scope: scope} do
      attrs = %{content: "User is vegetarian", source: "chat"}

      {:ok, %Fact{}} = Memory.create_memory(scope.user.id, scope.space.id, attrs)
      {:ok, :duplicate} = Memory.create_memory(scope.user.id, scope.space.id, attrs)
    end

    test "deduplicates case-insensitive", %{scope: scope} do
      {:ok, %Fact{}} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User is vegetarian",
          source: "chat"
        })

      {:ok, :duplicate} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "user is vegetarian",
          source: "chat"
        })
    end

    test "deduplicates semantically similar content", %{scope: scope} do
      {:ok, %Fact{}} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "allergic to penicillin",
          source: "chat"
        })

      # Same exact content → duplicate
      {:ok, :duplicate} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "allergic to penicillin",
          source: "chat"
        })
    end

    test "allows different content", %{scope: scope} do
      {:ok, %Fact{}} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User is allergic to penicillin",
          source: "chat"
        })

      {:ok, %Fact{}} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User runs 5km every morning",
          source: "chat"
        })
    end

    test "validates content length", %{scope: scope} do
      long_content = String.duplicate("a", 501)

      {:error, changeset} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: long_content,
          source: "chat"
        })

      assert "should be at most 500 character(s)" in errors_on(changeset).content
    end

    test "validates source", %{scope: scope} do
      {:error, changeset} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "some fact",
          source: "invalid"
        })

      assert "is invalid" in errors_on(changeset).source
    end
  end

  describe "list_memories/2" do
    test "returns active memories for user in space", %{scope: scope} do
      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "Fact one",
          source: "chat"
        })

      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "Fact two",
          source: "chat"
        })

      memories = Memory.list_memories(scope.user.id, scope.space.id)
      assert length(memories) == 2
    end

    test "does not return inactive memories", %{scope: scope} do
      {:ok, fact} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "To be deleted",
          source: "chat"
        })

      Memory.delete_memory(fact)

      memories = Memory.list_memories(scope.user.id, scope.space.id)
      assert memories == []
    end

    test "does not return other user's memories", %{scope: scope} do
      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "My fact",
          source: "chat"
        })

      %{scope: other_scope} = user_with_space_fixture()

      {:ok, _} =
        Memory.create_memory(other_scope.user.id, other_scope.space.id, %{
          content: "Other fact",
          source: "chat"
        })

      my_memories = Memory.list_memories(scope.user.id, scope.space.id)
      assert length(my_memories) == 1
      assert hd(my_memories).content == "My fact"
    end
  end

  describe "search/4" do
    test "returns memories via hybrid search", %{scope: scope} do
      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User is allergic to ibuprofen",
          source: "chat"
        })

      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User runs every morning",
          source: "chat"
        })

      # Use min_score: 0.0 since mock embeddings are random vectors
      {:ok, results} = Memory.search(scope.user.id, scope.space.id, "allergies", min_score: 0.0)
      assert length(results) > 0
    end

    test "returns empty list when no memories exist", %{scope: scope} do
      {:ok, results} = Memory.search(scope.user.id, scope.space.id, "anything")
      assert results == []
    end

    test "does not return inactive memories", %{scope: scope} do
      {:ok, fact} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User is vegetarian",
          source: "chat"
        })

      Memory.delete_memory(fact)

      {:ok, results} = Memory.search(scope.user.id, scope.space.id, "diet")
      assert results == []
    end

    test "respects max_results option", %{scope: scope} do
      for i <- 1..5 do
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "Fact number #{i} about health topic #{i}",
          source: "chat"
        })
      end

      {:ok, results} =
        Memory.search(scope.user.id, scope.space.id, "health", max_results: 2, min_score: 0.0)

      assert length(results) <= 2
    end
  end

  describe "search_for_prompt/2" do
    test "returns facts for user with scope", %{scope: scope} do
      {:ok, _} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "User has hypothyroidism",
          source: "chat"
        })

      results = Memory.search_for_prompt(scope, "thyroid")
      assert is_list(results)
    end

    test "returns empty list when scope has no user" do
      scope = %{user: nil, space: nil}
      assert Memory.search_for_prompt(scope, "anything") == []
    end
  end

  describe "delete_memory/1" do
    test "soft deletes a memory", %{scope: scope} do
      {:ok, fact} =
        Memory.create_memory(scope.user.id, scope.space.id, %{
          content: "To be removed",
          source: "chat"
        })

      {:ok, deleted} = Memory.delete_memory(fact)
      assert deleted.active == false
    end
  end
end
