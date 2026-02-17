defmodule Meddie.Invitations do
  @moduledoc """
  The Invitations context. Manages platform and space invitations.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts
  alias Meddie.Accounts.Scope
  alias Meddie.Accounts.UserNotifier
  alias Meddie.Invitations.Invitation
  alias Meddie.Spaces.Membership

  @token_length 32
  @expires_in_days 7

  @doc """
  Creates a platform invitation (no space). Only for platform admins.
  Expires any existing pending invitation for the same email and sends an email.
  """
  def create_platform_invitation(%Scope{user: user} = scope, email) do
    email = String.downcase(email)
    expire_duplicate_pending(email, nil)

    attrs = %{
      email: email,
      invited_by_id: user.id,
      token: generate_token(),
      expires_at: DateTime.add(DateTime.utc_now(:second), @expires_in_days, :day)
    }

    with {:ok, invitation} <- %Invitation{} |> Invitation.changeset(attrs) |> Repo.insert() do
      deliver_invitation_email(invitation, scope)
      {:ok, invitation}
    end
  end

  @doc """
  Creates a space invitation.

  If the email belongs to an existing user, creates a membership immediately
  and marks the invitation as accepted. Otherwise, expires any existing pending
  invitation for the same email+space and sends a new invitation email.
  """
  def create_space_invitation(%Scope{user: user, space: space} = scope, email, role \\ "member") do
    email = String.downcase(email)

    case Accounts.get_user_by_email(email) do
      nil ->
        # New user — expire old invitation and send a new one
        expire_duplicate_pending(email, space.id)

        attrs = %{
          email: email,
          space_id: space.id,
          invited_by_id: user.id,
          role: role,
          token: generate_token(),
          expires_at: DateTime.add(DateTime.utc_now(:second), @expires_in_days, :day)
        }

        with {:ok, invitation} <- %Invitation{} |> Invitation.changeset(attrs) |> Repo.insert() do
          deliver_invitation_email(invitation, scope)
          {:ok, invitation}
        end

      existing_user ->
        # Existing user — create membership immediately
        existing_membership =
          Repo.get_by(Membership, user_id: existing_user.id, space_id: space.id)

        if existing_membership do
          {:error, :already_member}
        else
          Ecto.Multi.new()
          |> Ecto.Multi.insert(
            :membership,
            Membership.changeset(%Membership{}, %{
              user_id: existing_user.id,
              space_id: space.id,
              role: role
            })
          )
          |> Ecto.Multi.insert(
            :invitation,
            Invitation.changeset(%Invitation{}, %{
              email: email,
              space_id: space.id,
              invited_by_id: user.id,
              role: role,
              token: generate_token(),
              expires_at: DateTime.utc_now(:second),
              accepted_at: DateTime.utc_now(:second)
            })
          )
          |> Repo.transaction()
          |> case do
            {:ok, %{invitation: invitation}} -> {:ok, invitation}
            {:error, _step, changeset, _} -> {:error, changeset}
          end
        end
    end
  end

  @doc """
  Gets a valid invitation by token.
  Returns nil if token not found, expired, or already accepted.
  """
  def get_valid_invitation_by_token(token) do
    invitation =
      from(i in Invitation,
        where: i.token == ^token,
        preload: [:space]
      )
      |> Repo.one()

    case invitation do
      nil -> nil
      inv -> if Invitation.expired?(inv) or Invitation.accepted?(inv), do: nil, else: inv
    end
  end

  @doc """
  Accepts an invitation for a user. Marks it accepted and creates
  a membership if it's a space invitation.
  """
  def accept_invitation(%Invitation{} = invitation, user) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:invitation, Invitation.accept_changeset(invitation))

    multi =
      if invitation.space_id do
        Ecto.Multi.insert(
          multi,
          :membership,
          Membership.changeset(%Membership{}, %{
            user_id: user.id,
            space_id: invitation.space_id,
            role: invitation.role || "member"
          })
        )
      else
        multi
      end

    Repo.transaction(multi)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, _step, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Lists pending platform invitations (not expired, not accepted).
  """
  def list_pending_platform_invitations do
    now = DateTime.utc_now(:second)

    from(i in Invitation,
      where: is_nil(i.space_id) and is_nil(i.accepted_at) and i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:invited_by]
    )
    |> Repo.all()
  end

  @doc """
  Lists invitations for a space.
  """
  def list_space_invitations(%Scope{space: space}) do
    from(i in Invitation,
      where: i.space_id == ^space.id,
      order_by: [desc: i.inserted_at],
      preload: [:invited_by]
    )
    |> Repo.all()
  end

  @doc """
  Lists pending space invitations (not expired, not accepted).
  """
  def list_pending_space_invitations(%Scope{space: space}) do
    now = DateTime.utc_now(:second)

    from(i in Invitation,
      where: i.space_id == ^space.id and is_nil(i.accepted_at) and i.expires_at > ^now,
      order_by: [desc: i.inserted_at],
      preload: [:invited_by]
    )
    |> Repo.all()
  end

  @doc """
  Deletes an invitation.
  """
  def delete_invitation(%Invitation{} = invitation) do
    Repo.delete(invitation)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(@token_length) |> Base.url_encode64(padding: false)
  end

  @doc """
  Resends the invitation email for an existing pending invitation.
  Returns `{:ok, invitation}` or `{:error, :invalid}` if expired/accepted.
  """
  def resend_invitation(%Invitation{} = invitation) do
    if Invitation.expired?(invitation) or Invitation.accepted?(invitation) do
      {:error, :invalid}
    else
      invitation = Repo.preload(invitation, [:invited_by, :space])

      opts = %{
        inviter_name: invitation.invited_by.name || invitation.invited_by.email
      }

      opts =
        if invitation.space do
          Map.put(opts, :space_name, invitation.space.name)
        else
          opts
        end

      url = invitation_url(invitation.token)
      UserNotifier.deliver_invitation_instructions(invitation.email, url, opts)
      {:ok, invitation}
    end
  end

  defp expire_duplicate_pending(email, space_id) do
    now = DateTime.utc_now(:second)
    past = DateTime.add(now, -1, :second)

    query =
      from(i in Invitation,
        where:
          i.email == ^email and
            is_nil(i.accepted_at) and
            i.expires_at > ^now
      )

    query =
      if space_id do
        from(i in query, where: i.space_id == ^space_id)
      else
        from(i in query, where: is_nil(i.space_id))
      end

    Repo.update_all(query, set: [expires_at: past])
  end

  defp deliver_invitation_email(invitation, scope) do
    opts = %{inviter_name: scope.user.name || scope.user.email}

    opts =
      if scope.space do
        Map.put(opts, :space_name, scope.space.name)
      else
        opts
      end

    url = invitation_url(invitation.token)
    UserNotifier.deliver_invitation_instructions(invitation.email, url, opts)
  end

  defp invitation_url(token) do
    MeddieWeb.Endpoint.url() <> "/invitations/#{token}"
  end
end
