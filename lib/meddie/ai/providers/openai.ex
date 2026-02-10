defmodule Meddie.AI.Providers.OpenAI do
  @moduledoc """
  OpenAI provider implementation using gpt-4o for vision and chat.
  """

  @behaviour Meddie.AI.Provider

  require Logger

  @api_url "https://api.openai.com/v1/chat/completions"
  @model "gpt-4o"
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

    Logger.debug(
      "OpenAI parse_document request: model=#{@model} images=#{length(images)} system_prompt_length=#{String.length(system_prompt)}"
    )

    case Req.post(@api_url,
           json: body,
           headers: [{"authorization", "Bearer #{api_key()}"}],
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 200, body: response}} ->
        Logger.debug("OpenAI parse_document response: #{inspect(response, limit: 2000)}")
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
