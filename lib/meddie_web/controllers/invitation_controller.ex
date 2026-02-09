defmodule MeddieWeb.InvitationController do
  use MeddieWeb, :controller

  alias Meddie.Accounts
  alias Meddie.Invitations
  alias Meddie.Accounts.User

  def show(conn, %{"token" => token}) do
    case Invitations.get_valid_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(
          :error,
          "This invitation is invalid or has expired. Please ask for a new one."
        )
        |> redirect(to: ~p"/users/log-in")

      invitation ->
        case Accounts.get_user_by_email(invitation.email) do
          nil ->
            # New user — show registration form
            form =
              %User{email: invitation.email}
              |> Accounts.change_user_registration()
              |> Phoenix.Component.to_form(as: "user")

            render(conn, :new, form: form, invitation: invitation, token: token)

          _existing_user ->
            # Existing user — prompt to log in, then auto-accept
            conn
            |> put_session(:pending_invitation_token, token)
            |> put_flash(
              :info,
              "You already have an account. Please log in to accept this invitation."
            )
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  def accept(conn, %{"token" => token, "user" => user_params}) do
    case Invitations.get_valid_invitation_by_token(token) do
      nil ->
        conn
        |> put_flash(:error, "This invitation is invalid or has expired.")
        |> redirect(to: ~p"/users/log-in")

      invitation ->
        case Accounts.register_user_via_invitation(
               Map.put(user_params, "email", invitation.email)
             ) do
          {:ok, user} ->
            {:ok, _} = Invitations.accept_invitation(invitation, user)

            redirect_to = if invitation.space_id, do: ~p"/people", else: ~p"/spaces/new"

            conn =
              if invitation.space_id do
                conn
                |> put_session(:current_space_id, invitation.space_id)
                |> put_session(:user_return_to, redirect_to)
              else
                put_session(conn, :user_return_to, redirect_to)
              end

            MeddieWeb.UserAuth.log_in_user(conn, user)

          {:error, changeset} ->
            form = Phoenix.Component.to_form(changeset, as: "user")
            render(conn, :new, form: form, invitation: invitation, token: token)
        end
    end
  end
end
