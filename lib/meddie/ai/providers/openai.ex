defmodule Meddie.AI.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation using gpt-4o for vision and chat.
  """

  @behaviour Meddie.AI.Provider

  require Logger

  @api_url "https://api.openai.com/v1/chat/completions"
  @model "gpt-4o"
  @fast_model "gpt-4o-mini"
  @timeout 60_000

  @impl true
  def parse_document(images, person_context) do
    system_prompt = person_context <> "\n\n" <> Meddie.AI.Prompts.document_parsing_prompt()

    content =
      Enum.map(images, fn {image_data, content_type} ->
        mime = content_type_to_mime(content_type)
        base64 = Base.encode64(image_data)

        %{
          "type" => "image_url",
          "image_url" => %{
            "url" => "data:#{mime};base64,#{base64}"
          }
        }
      end)

    body = %{
      "model" => @model,
      "messages" => [
        %{"role" => "system", "content" => system_prompt},
        %{"role" => "user", "content" => content}
      ],
      "response_format" => %{"type" => "json_object"},
      "max_tokens" => 4096
    }

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: response}} ->
        parse_response(response)

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenAI API error: status=#{status} body=#{inspect(body)}")
        {:error, "OpenAI API error: #{status}"}

      {:error, reason} ->
        Logger.error("OpenAI request failed: #{inspect(reason)}")
        {:error, "OpenAI request failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def chat_stream(messages, system_prompt, callback) do
    body = %{
      "model" => @model,
      "messages" =>
        [%{"role" => "system", "content" => system_prompt}] ++
          Enum.map(messages, fn msg ->
            %{"role" => msg.role, "content" => msg.content}
          end),
      "stream" => true
    }

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout,
           into: fn {:data, data}, {req, resp} ->
             for line <- String.split(data, "\n", trim: true),
                 String.starts_with?(line, "data: "),
                 chunk = String.trim_leading(line, "data: "),
                 chunk != "[DONE]",
                 {:ok, parsed} <- [Jason.decode(chunk)],
                 content = get_in(parsed, ["choices", Access.at(0), "delta", "content"]),
                 content != nil do
               callback.(%{content: content})
             end

             {:cont, {req, resp}}
           end
         ) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "OpenAI stream failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def chat(messages, system_prompt) do
    body = %{
      "model" => @model,
      "messages" =>
        [%{"role" => "system", "content" => system_prompt}] ++
          Enum.map(messages, fn msg ->
            %{"role" => msg.role, "content" => msg.content}
          end)
    }

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, content}

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenAI chat error: status=#{status} body=#{inspect(body)}")
        {:error, "OpenAI API error: #{status}"}

      {:error, reason} ->
        Logger.error("OpenAI chat failed: #{inspect(reason)}")
        {:error, "OpenAI chat failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def resolve_person(message, people_context) do
    body = %{
      "model" => @fast_model,
      "messages" => [
        %{
          "role" => "system",
          "content" =>
            "You resolve which person a message is about. Return JSON: {\"person_number\": N} where N is the 1-indexed number, or {\"person_number\": null} if unclear."
        },
        %{
          "role" => "user",
          "content" => "#{people_context}\n\nUser message: #{message}"
        }
      ],
      "response_format" => %{"type" => "json_object"},
      "max_tokens" => 50
    }

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: response}} ->
        case parse_response(response) do
          {:ok, %{"person_number" => n}} -> {:ok, n}
          _ -> {:ok, nil}
        end

      {:error, reason} ->
        {:error, "OpenAI resolve_person failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def generate_title(user_message, assistant_message) do
    body = %{
      "model" => @fast_model,
      "messages" => [
        %{
          "role" => "system",
          "content" =>
            "Generate a concise conversation title (3-6 words) in the same language as the user message. Return only the title text, no quotes or punctuation at the end."
        },
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
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => title}} | _]}}} ->
        {:ok, String.trim(title)}

      {:error, reason} ->
        {:error, "OpenAI generate_title failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def format_profile_field(current_value, action, text) do
    system_prompt = Meddie.AI.Prompts.profile_field_format_prompt(action, text, current_value)

    body = %{
      "model" => @fast_model,
      "messages" => [
        %{"role" => "system", "content" => system_prompt},
        %{"role" => "user", "content" => "Update the field now."}
      ],
      "max_tokens" => 500
    }

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, String.trim(content)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("OpenAI format_profile_field error: status=#{status} body=#{inspect(body)}")
        {:error, "OpenAI API error: #{status}"}

      {:error, reason} ->
        Logger.error("OpenAI format_profile_field failed: #{inspect(reason)}")
        {:error, "OpenAI format_profile_field failed: #{inspect(reason)}"}
    end
  end

  defp parse_response(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    case Jason.decode(content) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, "Failed to parse JSON response from OpenAI"}
    end
  end

  defp parse_response(response) do
    {:error, "Unexpected OpenAI response format: #{inspect(response)}"}
  end

  defp content_type_to_mime("image/jpeg"), do: "image/jpeg"
  defp content_type_to_mime("image/png"), do: "image/png"
  defp content_type_to_mime("image/webp"), do: "image/webp"
  defp content_type_to_mime(other), do: other

  defp api_key do
    Application.get_env(:meddie, :ai)[:openai_api_key] ||
      raise "OPENAI_API_KEY not configured"
  end
end
