defmodule Meddie.Telegram.Poller do
  @moduledoc """
  GenServer that long-polls the Telegram Bot API for updates.
  One instance per Space with a configured bot token.
  """

  use GenServer

  require Logger

  alias Meddie.Telegram.{Client, Handler}

  @poll_timeout 30
  @error_retry_delay 5_000

  def start_link({space_id, token}) do
    GenServer.start_link(__MODULE__, {space_id, token},
      name: via_tuple(space_id)
    )
  end

  defp via_tuple(space_id) do
    {:via, Registry, {Meddie.Telegram.Registry, space_id}}
  end

  @impl true
  def init({space_id, token}) do
    Logger.info("Telegram.Poller: starting for space #{space_id}")
    send(self(), :poll)
    {:ok, %{space_id: space_id, token: token, offset: 0}}
  end

  @impl true
  def handle_info(:poll, state) do
    case Client.get_updates(state.token, state.offset, @poll_timeout) do
      {:ok, updates} ->
        new_offset = process_updates(updates, state)
        send(self(), :poll)
        {:noreply, %{state | offset: new_offset}}

      {:error, reason} ->
        Logger.warning("Telegram.Poller: error for space #{state.space_id}: #{inspect(reason)}, retrying in #{@error_retry_delay}ms")
        Process.send_after(self(), :poll, @error_retry_delay)
        {:noreply, state}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Telegram.Poller: stopping for space #{state.space_id}: #{inspect(reason)}")
    :ok
  end

  defp process_updates([], state), do: state.offset

  defp process_updates(updates, state) do
    space = Meddie.Spaces.get_space!(state.space_id)

    Enum.each(updates, fn update ->
      Task.start(fn ->
        try do
          Handler.handle(update, space, state.token)
        rescue
          e ->
            Logger.error("Telegram.Handler error: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}")
        end
      end)
    end)

    # Return the next offset (last update_id + 1)
    last_update = List.last(updates)
    last_update["update_id"] + 1
  end
end
