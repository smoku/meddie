defmodule Meddie.Telegram.Client do
  @moduledoc """
  HTTP client for the Telegram Bot API. Uses Req for HTTP requests.
  """

  require Logger

  @base_url "https://api.telegram.org"
  @timeout 35_000

  @doc """
  Long-polls for updates from the Telegram Bot API.
  """
  def get_updates(token, offset, timeout \\ 30) do
    url = "#{@base_url}/bot#{token}/getUpdates"

    case Req.post(url,
           json: %{"offset" => offset, "timeout" => timeout},
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"ok" => true, "result" => updates}}} ->
        {:ok, updates}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Telegram getUpdates error: status=#{status} body=#{inspect(body)}")
        {:error, "Telegram API error: #{status}"}

      {:error, reason} ->
        Logger.error("Telegram getUpdates failed: #{inspect(reason)}")
        {:error, "Telegram request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Sends a text message to a Telegram chat.
  Supports optional `reply_markup` for inline keyboards.
  """
  def send_message(token, chat_id, text, opts \\ []) do
    url = "#{@base_url}/bot#{token}/sendMessage"

    body =
      %{"chat_id" => chat_id, "text" => text, "parse_mode" => "Markdown"}
      |> maybe_add_reply_markup(opts[:reply_markup])

    case Req.post(url, json: body, receive_timeout: @timeout) do
      {:ok, %{status: 200, body: %{"ok" => true, "result" => result}}} ->
        {:ok, result}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Telegram sendMessage error: status=#{status} body=#{inspect(body)}")
        {:error, "Telegram API error: #{status}"}

      {:error, reason} ->
        Logger.error("Telegram sendMessage failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sends a chat action (e.g., "typing") to indicate the bot is processing.
  """
  def send_chat_action(token, chat_id, action \\ "typing") do
    url = "#{@base_url}/bot#{token}/sendChatAction"

    Req.post(url,
      json: %{"chat_id" => chat_id, "action" => action},
      receive_timeout: @timeout
    )

    :ok
  end

  defp maybe_add_reply_markup(body, nil), do: body
  defp maybe_add_reply_markup(body, markup), do: Map.put(body, "reply_markup", markup)
end
