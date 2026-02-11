defmodule Meddie.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Meddie.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Meddie.Accounts.User
  alias Meddie.Spaces.Space

  defstruct user: nil, space: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Adds a space to the scope.
  """
  def put_space(%__MODULE__{} = scope, %Space{} = space) do
    %{scope | space: space}
  end

  def put_space(%__MODULE__{} = scope, nil) do
    %{scope | space: nil}
  end

  @doc """
  Creates a scope for the given space without a user.
  Used for Telegram links that don't have a linked Meddie account.
  """
  def for_space(%Space{} = space) do
    %__MODULE__{space: space}
  end
end
