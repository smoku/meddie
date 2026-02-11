defmodule Meddie.AI.PromptsTest do
  use Meddie.DataCase, async: true

  alias Meddie.AI.Prompts

  import Meddie.SpacesFixtures
  import Meddie.PeopleFixtures

  describe "chat_system_prompt/1" do
    test "returns base prompt without person context" do
      prompt = Prompts.chat_system_prompt()
      assert prompt =~ "You are Meddie"
      assert prompt =~ "friendly health assistant"
      assert prompt =~ "memory_updates"
    end

    test "includes person context when provided" do
      prompt = Prompts.chat_system_prompt("## Person: Anna\nSex: female")
      assert prompt =~ "You are Meddie"
      assert prompt =~ "## Person: Anna"
      assert prompt =~ "Sex: female"
    end
  end

  describe "chat_context/2" do
    test "builds context with person profile" do
      %{scope: scope} = user_with_space_fixture(%{locale: "en"})

      person =
        person_fixture(scope, %{
          "name" => "Anna Nowak",
          "sex" => "female",
          "date_of_birth" => "1990-05-15",
          "height_cm" => "170",
          "weight_kg" => "65"
        })

      context = Prompts.chat_context(scope, person)
      assert context =~ "Anna Nowak"
      assert context =~ "female"
      assert context =~ "170"
      assert context =~ "65"
    end

    test "includes memory fields when present" do
      %{scope: scope} = user_with_space_fixture(%{locale: "en"})

      person =
        person_fixture(scope, %{
          "name" => "Anna Nowak",
          "sex" => "female",
          "health_notes" => "Type 2 diabetes",
          "supplements" => "Vitamin D 2000 IU",
          "medications" => "Metformin 500mg"
        })

      context = Prompts.chat_context(scope, person)
      assert context =~ "Type 2 diabetes"
      assert context =~ "Vitamin D 2000 IU"
      assert context =~ "Metformin 500mg"
    end

    test "marks linked user with (this is you)" do
      %{user: user, scope: scope} = user_with_space_fixture(%{locale: "en"})

      person =
        person_fixture(scope, %{
          "name" => "Anna Nowak",
          "sex" => "female",
          "user_id" => user.id
        })

      context = Prompts.chat_context(scope, person)
      assert context =~ "(this is you)"
    end
  end

  describe "person_resolution_prompt/2" do
    test "builds numbered people list" do
      %{user: user, scope: scope} = user_with_space_fixture(%{locale: "en"})

      p1 = person_fixture(scope, %{"name" => "Anna Nowak", "sex" => "female", "user_id" => user.id})
      p2 = person_fixture(scope, %{"name" => "Tomek Nowak", "sex" => "male"})

      prompt = Prompts.person_resolution_prompt([p1, p2], scope)
      assert prompt =~ "1. Anna Nowak"
      assert prompt =~ "2. Tomek Nowak"
      assert prompt =~ "THIS IS THE CURRENT USER"
    end
  end

  describe "person_context/1" do
    test "builds person context for document parsing" do
      %{scope: scope} = user_with_space_fixture(%{locale: "en"})

      person =
        person_fixture(scope, %{
          "name" => "Anna Nowak",
          "sex" => "female",
          "height_cm" => "170"
        })

      ctx = Prompts.person_context(person)
      assert ctx =~ "Anna Nowak"
      assert ctx =~ "female"
      assert ctx =~ "170"
    end
  end
end
