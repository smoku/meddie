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
    - Write the summary in the same language as the document:
      - For lab_results: Write a brief summary (2-4 sentences) of the document contents and key findings.
      - For medical_report and other: Write a detailed summary covering all key findings, diagnoses, recommendations, measurements, and conclusions. Be thorough — this summary is the primary stored representation of the document.

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
      "summary": "Summary of document contents and key findings (brief for lab_results, detailed for others)",
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
  Builds person context string for AI prompts (document parsing).
  """
  def person_context(person) do
    """
    ## Context: This document belongs to #{person.name}
    Sex: #{person.sex} | DOB: #{person.date_of_birth || "unknown"} | Height: #{person.height_cm || "unknown"} cm | Weight: #{person.weight_kg || "unknown"} kg
    """
  end

  @doc """
  Returns the system prompt for Ask Meddie chat conversations.
  Includes person context if a person is selected, memory facts from previous
  conversations, and memory detection instructions.
  """
  def chat_system_prompt(person_context \\ nil, memory_facts \\ []) do
    base = """
    You are Meddie, a friendly health assistant. You help users understand their medical test results. You speak in the same language as the user.

    Guidelines:
    - Reference specific values and ranges when answering
    - Explain medical terms in plain language
    - If a value is out of range, explain what it might indicate
    - Always recommend consulting a healthcare provider for medical decisions
    - Do not diagnose conditions — explain what results might suggest
    - If you don't have enough data, say so clearly
    """

    base =
      if person_context do
        base <> "\n" <> person_context
      else
        base
      end

    base =
      if memory_facts != [] do
        facts_text = Enum.map_join(memory_facts, "\n", &("- " <> &1.content))

        base <>
          "\n\n## Remembered Facts\nThings you know about this user from previous conversations:\n" <>
          facts_text
      else
        base
      end

    base <> "\n" <> memory_detection_instructions()
  end

  @doc """
  Builds the full person context for chat, including profile, memory fields,
  biomarkers, and document summaries.
  """
  def chat_context(scope, person) do
    is_current_user = scope.user != nil and person.user_id != nil and person.user_id == scope.user.id
    user_marker = if is_current_user, do: " (this is you)", else: ""

    age = calculate_age(person.date_of_birth)
    age_str = if age, do: " (age #{age})", else: ""

    profile = """
    ## Person: #{person.name}#{user_marker}
    Sex: #{person.sex} | DOB: #{person.date_of_birth || "unknown"}#{age_str} | Height: #{person.height_cm || "unknown"} cm | Weight: #{person.weight_kg || "unknown"} kg
    """

    memory = build_memory_section(person)
    biomarkers = build_biomarkers_section(scope, person)
    summaries = build_summaries_section(scope, person)

    [profile, memory, biomarkers, summaries]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc """
  Builds the prompt for person resolution.
  """
  def person_resolution_prompt(people, scope) do
    people
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {person, idx} ->
      is_current = scope.user != nil and person.user_id != nil and person.user_id == scope.user.id
      marker = if is_current, do: " — THIS IS THE CURRENT USER", else: ""
      age = calculate_age(person.date_of_birth)
      age_str = if age, do: ", age #{age}", else: ""
      "#{idx}. #{person.name} (#{person.sex}#{age_str})#{marker}"
    end)
  end

  defp build_memory_section(person) do
    [
      {"Health Notes", person.health_notes},
      {"Supplements", person.supplements},
      {"Medications", person.medications}
    ]
    |> Enum.reject(fn {_, val} -> is_nil(val) or val == "" end)
    |> Enum.map_join("\n\n", fn {label, val} -> "## #{label}\n#{val}" end)
  end

  defp build_biomarkers_section(scope, person) do
    biomarkers = Meddie.Documents.list_person_biomarkers(scope, person.id)

    if biomarkers == [] do
      ""
    else
      latest_by_name =
        biomarkers
        |> Enum.group_by(fn b -> {b.name, b.unit} end)
        |> Enum.map(fn {_key, group} -> List.last(group) end)

      two_years_ago = Date.utc_today() |> Date.add(-730)

      latest_by_name =
        Enum.filter(latest_by_name, fn b ->
          b.document && b.document.document_date &&
            Date.compare(b.document.document_date, two_years_ago) != :lt
        end)

      if latest_by_name == [] do
        ""
      else
        by_category = Enum.group_by(latest_by_name, & &1.category)

        lines =
          by_category
          |> Enum.sort_by(fn {cat, _} -> cat || "" end)
          |> Enum.map_join("\n", fn {category, items} ->
            date =
              items |> Enum.map(& &1.document.document_date) |> Enum.max(Date) |> to_string()

            header = "### #{category || "Other"} (from #{date})"

            item_lines =
              Enum.map_join(items, "\n", fn b ->
                status_icon = status_icon(b.status)
                ref = format_reference_range(b)
                "- #{b.name}: #{b.value} #{b.unit || ""} #{ref} #{status_icon} #{b.status}"
              end)

            "#{header}\n#{item_lines}"
          end)

        "## Latest Biomarker Results\n#{lines}"
      end
    end
  end

  defp build_summaries_section(scope, person) do
    documents = Meddie.Documents.list_documents(scope, person.id, limit: 10)

    parsed =
      Enum.filter(documents, fn d -> d.status == "parsed" and d.summary not in [nil, ""] end)

    if parsed == [] do
      ""
    else
      lines =
        Enum.map_join(parsed, "\n", fn d ->
          date = d.document_date || d.inserted_at |> DateTime.to_date()
          type = String.replace(d.document_type || "other", "_", " ")
          "- #{date}: #{type} — #{String.slice(d.summary, 0..200)}"
        end)

      "## Document Summaries\n#{lines}"
    end
  end

  defp memory_detection_instructions do
    """
    IMPORTANT: If the user mentions health-relevant information worth remembering, you MUST append a JSON block at the very end of your response (after your text response) in this exact format:

    ```json
    {"profile_updates": [{"field": "health_notes|supplements|medications", "action": "append|remove", "text": "what to save"}], "memory_saves": ["concise fact 1", "concise fact 2"]}
    ```

    Include whichever keys are relevant. Omit keys with empty arrays. Only include when the user clearly states factual information.

    **profile_updates** — for structured person profile data:
    - Only for health_notes, supplements, medications fields
    - "append" adds text to the field's Current section
    - "remove" moves text from Current to Previous section

    **memory_saves** — for broader facts worth remembering across conversations:
    - Preferences, lifestyle, family history, goals, key dates, doctor names, reactions to treatments
    - Each fact: concise, self-contained sentence (max 500 chars)
    - Write in the user's language
    - ONLY save facts the USER stated or confirmed — NEVER save medical knowledge or explanations YOU provided
    - Do NOT save biomarker values (stored separately) or supplement/medication lists (handled by profile_updates)
    """
  end

  defp status_icon("normal"), do: "✓"
  defp status_icon("high"), do: "⚠"
  defp status_icon("low"), do: "⚠"
  defp status_icon(_), do: "?"

  defp format_reference_range(biomarker) do
    cond do
      biomarker.reference_range_low && biomarker.reference_range_high ->
        "[#{biomarker.reference_range_low}-#{biomarker.reference_range_high}]"

      biomarker.reference_range_text ->
        "[#{biomarker.reference_range_text}]"

      true ->
        ""
    end
  end

  defp calculate_age(nil), do: nil

  defp calculate_age(dob) do
    today = Date.utc_today()
    years = today.year - dob.year

    if Date.compare(Date.new!(today.year, dob.month, dob.day), today) == :gt do
      years - 1
    else
      years
    end
  end
end
