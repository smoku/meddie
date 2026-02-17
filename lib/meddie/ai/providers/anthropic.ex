defmodule Meddie.AI.Providers.Anthropic do
  @moduledoc """
  Anthropic provider implementation using Claude for vision and chat.
  """

  @behaviour Meddie.AI.Provider

  require Logger

  @api_url "https://api.anthropic.com/v1/messages"
  @model "claude-sonnet-4-5-20250929"
  @fast_model "claude-haiku-4-5-20251001"
  @timeout 180_000

  @impl true
  def parse_document(images, person_context) do
    system_prompt = person_context <> "\n\n" <> Meddie.AI.Prompts.document_parsing_prompt()

    content =
      Enum.flat_map(images, fn {image_data, content_type} ->
        mime = content_type_to_media_type(content_type)
        base64 = Base.encode64(image_data)

        [
          %{
            "type" => "image",
            "source" => %{
              "type" => "base64",
              "media_type" => mime,
              "data" => base64
            }
          }
        ]
      end)

    content = content ++ [%{"type" => "text", "text" => "Parse this medical document."}]

    body = %{
      "model" => @model,
      "system" => system_prompt,
      "messages" => [
        %{"role" => "user", "content" => content}
      ],
      "max_tokens" => 32_768
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: response}} ->
        parse_response(response)

      {:ok, %{status: status, body: body}} ->
        Logger.error("Anthropic API error: status=#{status} body=#{inspect(body)}")
        {:error, "Anthropic API error: #{status}"}

      {:error, reason} ->
        Logger.error("Anthropic request failed: #{inspect(reason)}")
        {:error, "Anthropic request failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def chat_stream(messages, system_prompt, callback) do
    body = %{
      "model" => @model,
      "system" => system_prompt,
      "messages" =>
        Enum.map(messages, fn msg ->
          %{"role" => msg.role, "content" => msg.content}
        end),
      "max_tokens" => 4096,
      "stream" => true
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout,
           into: fn {:data, data}, {req, resp} ->
             for line <- String.split(data, "\n", trim: true),
                 String.starts_with?(line, "data: "),
                 chunk = String.trim_leading(line, "data: "),
                 {:ok, parsed} <- [Jason.decode(chunk)],
                 parsed["type"] == "content_block_delta",
                 text = get_in(parsed, ["delta", "text"]),
                 text != nil do
               callback.(%{content: text})
             end

             {:cont, {req, resp}}
           end
         ) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Anthropic stream failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def chat(messages, system_prompt) do
    body = %{
      "model" => @model,
      "system" => system_prompt,
      "messages" =>
        Enum.map(messages, fn msg ->
          %{"role" => msg.role, "content" => msg.content}
        end),
      "max_tokens" => 4096
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        {:ok, text}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Anthropic chat error: status=#{status} body=#{inspect(body)}")
        {:error, "Anthropic API error: #{status}"}

      {:error, reason} ->
        Logger.error("Anthropic chat failed: #{inspect(reason)}")
        {:error, "Anthropic chat failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def resolve_person(message, people_context) do
    body = %{
      "model" => @fast_model,
      "system" =>
        "You resolve which person a message is about. Return JSON: {\"person_number\": N} where N is the 1-indexed number, or {\"person_number\": null} if unclear.",
      "messages" => [
        %{
          "role" => "user",
          "content" => "#{people_context}\n\nUser message: #{message}"
        }
      ],
      "max_tokens" => 50
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => text} | _]}}} ->
        text = strip_code_fences(text)

        case Jason.decode(text) do
          {:ok, %{"person_number" => n}} -> {:ok, n}
          _ -> {:ok, nil}
        end

      {:error, reason} ->
        {:error, "Anthropic resolve_person failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def generate_title(user_message, assistant_message) do
    body = %{
      "model" => @fast_model,
      "system" =>
        "Generate a concise conversation title (3-6 words) in the same language as the user message. Return only the title text, no quotes or punctuation at the end.",
      "messages" => [
        %{
          "role" => "user",
          "content" =>
            "User: #{String.slice(user_message, 0..500)}\nAssistant: #{String.slice(assistant_message, 0..500)}"
        }
      ],
      "max_tokens" => 30
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => title} | _]}}} ->
        {:ok, String.trim(title)}

      {:error, reason} ->
        {:error, "Anthropic generate_title failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def format_profile_field(current_value, action, text) do
    system_prompt = Meddie.AI.Prompts.profile_field_format_prompt(action, text, current_value)

    body = %{
      "model" => @fast_model,
      "system" => system_prompt,
      "messages" => [
        %{"role" => "user", "content" => "Update the field now."}
      ],
      "max_tokens" => 500
    }

    case Req.post(@api_url,
           json: body,
           headers: [
             {"x-api-key", api_key()},
             {"anthropic-version", "2023-06-01"}
           ],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"content" => [%{"text" => content} | _]}}} ->
        {:ok, String.trim(content)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("Anthropic format_profile_field error: status=#{status} body=#{inspect(body)}")
        {:error, "Anthropic API error: #{status}"}

      {:error, reason} ->
        Logger.error("Anthropic format_profile_field failed: #{inspect(reason)}")
        {:error, "Anthropic format_profile_field failed: #{inspect(reason)}"}
    end
  end

  defp parse_response(%{"content" => [%{"type" => "text", "text" => text} | _]}) do
    text = strip_code_fences(text)

    case Jason.decode(text) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "Failed to parse JSON response from Anthropic"}
    end
  end

  defp parse_response(response) do
    {:error, "Unexpected Anthropic response format: #{inspect(response)}"}
  end

  defp strip_code_fences(text) do
    text
    |> String.trim()
    |> then(fn
      "```json" <> rest -> rest |> String.trim_trailing("```") |> String.trim()
      "```" <> rest -> rest |> String.trim_trailing("```") |> String.trim()
      other -> other
    end)
  end

  defp content_type_to_media_type("image/jpeg"), do: "image/jpeg"
  defp content_type_to_media_type("image/png"), do: "image/png"
  defp content_type_to_media_type("image/webp"), do: "image/webp"
  defp content_type_to_media_type(other), do: other

  defp api_key do
    Application.get_env(:meddie, :ai)[:anthropic_api_key] ||
      raise "ANTHROPIC_API_KEY not configured"
  end
end
