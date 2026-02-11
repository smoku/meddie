defmodule Meddie.Telegram.Supervisor do
  @moduledoc """
  DynamicSupervisor that manages one Poller GenServer per Space with a Telegram bot token.
  """

  use DynamicSupervisor

  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Called after the supervisor starts to boot pollers for all spaces with tokens.
  """
  def boot_pollers do
    if polling_enabled?() do
      spaces = Meddie.Spaces.list_spaces_with_telegram_token()

      Enum.each(spaces, fn space ->
        start_poller(space.id, space.telegram_bot_token)
      end)

      Logger.info("Telegram: started #{length(spaces)} poller(s)")
    else
      Logger.info("Telegram: polling disabled")
    end
  end

  @doc """
  Starts a poller for a specific space.
  """
  def start_poller(space_id, token) do
    child_spec = {Meddie.Telegram.Poller, {space_id, token}}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Telegram: started poller for space #{space_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Telegram: failed to start poller for space #{space_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops the poller for a specific space.
  """
  def stop_poller(space_id) do
    case Registry.lookup(Meddie.Telegram.Registry, space_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Telegram: stopped poller for space #{space_id}")
        :ok

      [] ->
        :ok
    end
  end

  @doc """
  Restarts a poller (stop then start) — used when token changes.
  """
  def restart_poller(space_id, token) do
    stop_poller(space_id)
    start_poller(space_id, token)
  end

  defp polling_enabled? do
    Application.get_env(:meddie, :telegram, [])[:polling_enabled] != false
  end
end
