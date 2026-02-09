defmodule Meddie.Invitations do
  @moduledoc """
  The Invitations context. Manages platform and space invitations.
  """

  import Ecto.Query, warn: false
  alias Meddie.Repo

  alias Meddie.Accounts
  alias Meddie.Accounts.Scope
  alias Meddie.Invitations.Invitation
  alias Meddie.Spaces.Membership

  @token_length 32
  @expires_in_days 7

  @doc """
  Creates a platform invitation (no space). Only for platform admins.
  """
  def create_platform_invitation(%Scope{user: user}, email) do
    attrs = %{
      email: String.downcase(email),
      invited_by_id: user.id,
      token: generate_token(),
      expires_at: DateTime.add(DateTime.utc_now(:second), @expires_in_days, :day)
    }

    %Invitation{}
    |> Invitation.changeset(attrs)
    |> check_duplicate_pending(email, nil)
    |> Repo.insert()
  end

  @doc """
  Creates a space invitation.

  If the email belongs to an existing user, creates a membership immediately
  and marks the invitation as accepted.
  """
  def create_space_invitation(%Scope{user: user, space: space}, email) do
    email = String.downcase(email)

    case Accounts.get_user_by_email(email) do
      nil ->
        # New user — send invitation
        attrs = %{
          email: email,
          space_id: space.id,
          invited_by_id: user.id,
          token: generate_token(),
          expires_at: DateTime.add(DateTime.utc_now(:second), @expires_in_days, :day)
        }

        %Invitation{}
        |> Invitation.changeset(attrs)
        |> check_duplicate_pending(email, space.id)
        |> Repo.insert()

      existing_user ->
        # Existing user — create membership immediately
        existing_membership = Repo.get_by(Membership, user_id: existing_user.id, space_id: space.id)

        if existing_membership do
          {:error, :already_member}
        else
          Ecto.Multi.new()
          |> Ecto.Multi.insert(:membership, Membership.changeset(%Membership{}, %{
            user_id: existing_user.id,
            space_id: space.id,
            role: "member"
          }))
          |> Ecto.Multi.insert(:invitation, Invitation.changeset(%Invitation{}, %{
            email: email,
            space_id: space.id,
            invited_by_id: user.id,
            token: generate_token(),
            expires_at: DateTime.utc_now(:second),
            accepted_at: DateTime.utc_now(:second)
          }))
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
    multi = Ecto.Multi.new()
    |> Ecto.Multi.update(:invitation, Invitation.accept_changeset(invitation))

    multi =
      if invitation.space_id do
        Ecto.Multi.insert(multi, :membership, Membership.changeset(%Membership{}, %{
          user_id: user.id,
          space_id: invitation.space_id,
          role: "member"
        }))
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

  defp generate_token do
    :crypto.strong_rand_bytes(@token_length) |> Base.url_encode64(padding: false)
  end

  defp check_duplicate_pending(changeset, email, space_id) do
    now = DateTime.utc_now(:second)

    query =
      from(i in Invitation,
        where:
          i.email == ^String.downcase(email) and
            is_nil(i.accepted_at) and
            i.expires_at > ^now
      )

    query =
      if space_id do
        from(i in query, where: i.space_id == ^space_id)
      else
        from(i in query, where: is_nil(i.space_id))
      end

    if Repo.exists?(query) do
      Ecto.Changeset.add_error(changeset, :email, "an invitation has already been sent to this email")
    else
      changeset
    end
  end
end
