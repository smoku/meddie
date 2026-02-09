defmodule Mix.Tasks.Meddie.CreateAdmin do
  @moduledoc """
  Creates a platform admin user.

      mix meddie.create_admin NAME EMAIL PASSWORD

  The user is created with a confirmed account and the platform_admin flag set.
  If the user already exists, their platform_admin flag is set to true.
  """

  use Mix.Task

  @shortdoc "Creates a platform admin user"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [name, email, password] ->
        create_admin(name, email, password)

      _ ->
        Mix.shell().error("Usage: mix meddie.create_admin NAME EMAIL PASSWORD")
    end
  end

  defp create_admin(name, email, password) do
    alias Meddie.Accounts
    alias Meddie.Accounts.User
    alias Meddie.Repo

    case Repo.get_by(User, email: email) do
      nil ->
        case Accounts.register_user_via_invitation(%{
               name: name,
               email: email,
               password: password,
               password_confirmation: password
             }) do
          {:ok, user} ->
            user
            |> User.admin_changeset(%{platform_admin: true})
            |> Repo.update!()

            Mix.shell().info("Created platform admin: #{email}")

          {:error, changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
                  opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
                end)
              end)

            Mix.shell().error("Failed to create admin: #{inspect(errors)}")
        end

      existing_user ->
        if existing_user.platform_admin do
          Mix.shell().info("User #{email} is already a platform admin.")
        else
          existing_user
          |> User.admin_changeset(%{platform_admin: true})
          |> Repo.update!()

          Mix.shell().info("Promoted existing user #{email} to platform admin.")
        end
    end
  end
end
