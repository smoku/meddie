defmodule Meddie.AI.Providers.Mock do
  @moduledoc """
  Mock AI provider for testing. Returns predictable results.
  """

  @behaviour Meddie.AI.Provider

  @impl true
  def parse_document(_images, _person_context) do
    {:ok,
     %{
       "document_type" => "lab_results",
       "document_date" => "2025-01-15",
       "summary" => "Blood work results showing normal values.",
       "biomarkers" => [
         %{
           "name" => "Hemoglobina",
           "value" => "14,5",
           "numeric_value" => 14.5,
           "unit" => "g/dL",
           "reference_range_low" => 12.0,
           "reference_range_high" => 16.0,
           "reference_range_text" => "12,0 - 16,0",
           "status" => "normal",
           "category" => "Morfologia krwi"
         },
         %{
           "name" => "WBC",
           "value" => "6,8",
           "numeric_value" => 6.8,
           "unit" => "10^3/uL",
           "reference_range_low" => 4.0,
           "reference_range_high" => 10.0,
           "reference_range_text" => "4,0 - 10,0",
           "status" => "normal",
           "category" => "Morfologia krwi"
         }
       ]
     }}
  end

  @impl true
  def chat_stream(_messages, _system_prompt, callback) do
    callback.(%{content: "This is a mock response."})
    :ok
  end
end
