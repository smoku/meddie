defmodule Meddie.AI.Prompts do
  @moduledoc """
  Prompt templates for AI document parsing and chat.
  """

  @doc """
  Returns the system prompt for medical document parsing.
  """
  def document_parsing_prompt do
    """
    You are a medical document parser. Analyze the provided medical document image.

    First, classify the document:
    - "lab_results": Laboratory test results, blood work, urine analysis — contains tabular biomarker data with values and reference ranges
    - "medical_report": Medical reports (MRI, CT, ultrasound descriptions, specialist consultations, discharge summaries) — narrative text with findings
    - "other": Prescriptions, referrals, or other medical documents

    Then, for ALL document types:
    - Extract the document date if visible
    - Write a brief summary (2-4 sentences) of the document contents and key findings. Write the summary in the same language as the document.

    Additionally, for lab_results ONLY, extract every biomarker/test result:
    - name: The biomarker or test name exactly as written on the document (keep original language, do NOT translate)
    - value: The measured value as a string, exactly as shown (e.g., "5,96" with comma if that's how it appears)
    - numeric_value: The numeric value normalized to use dots as decimal separators (e.g., 5.96). For values like ">60" or "<1,0", use the number (60 or 1.0)
    - unit: The unit of measurement as shown on the document
    - reference_range_low: Lower bound of reference range as a number (null if not available)
    - reference_range_high: Upper bound of reference range as a number (null if not available)
    - reference_range_text: Raw reference range text as shown on the document (e.g., "4,23 - 9,07")
    - status: "normal" if within range, "low" if below, "high" if above, "unknown" if range not available
    - category: The panel or section name as shown on the document (e.g., "Morfologia krwi", "Lipidogram")

    Skip pages that contain only lab metadata, sample information, or administrative details — no biomarkers to extract there.

    Return ONLY valid JSON in this format:
    {
      "document_type": "lab_results | medical_report | other",
      "document_date": "YYYY-MM-DD or null",
      "summary": "Brief summary of document contents and key findings",
      "biomarkers": [
        {
          "name": "string",
          "value": "string",
          "numeric_value": null,
          "unit": "string or null",
          "reference_range_low": null,
          "reference_range_high": null,
          "reference_range_text": "string or null",
          "status": "normal|low|high|unknown",
          "category": "string or null"
        }
      ]
    }

    For medical_report and other document types, return an empty biomarkers array.
    """
  end

  @doc """
  Builds person context string for AI prompts.
  """
  def person_context(person) do
    """
    ## Context: This document belongs to #{person.name}
    Sex: #{person.sex} | DOB: #{person.date_of_birth || "unknown"} | Height: #{person.height_cm || "unknown"} cm | Weight: #{person.weight_kg || "unknown"} kg
    """
  end
end
