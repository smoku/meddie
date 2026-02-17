defmodule Meddie.Telegram.Formatter do
  @moduledoc """
  Converts Markdown text to Telegram-compatible HTML.

  Telegram's HTML mode supports a limited subset of tags:
  <b>, <strong>, <i>, <em>, <u>, <s>, <del>, <code>, <pre>,
  <a href="...">, <blockquote>, <tg-spoiler>.

  Unsupported elements (headers, lists, images, hr) are converted
  to their closest Telegram-safe equivalents.
  """

  @doc """
  Converts a Markdown string to Telegram-compatible HTML.
  """
  def to_telegram_html(nil), do: ""
  def to_telegram_html(""), do: ""

  def to_telegram_html(markdown) do
    markdown
    |> Earmark.as_html!(smartypants: false)
    |> convert_unsupported_tags()
    |> collapse_whitespace()
    |> String.trim()
  end

  # Convert HTML tags not supported by Telegram into safe equivalents.
  defp convert_unsupported_tags(html) do
    html
    |> convert_headers()
    |> convert_tables()
    |> convert_lists()
    |> convert_paragraphs()
    |> strip_tag_attributes(~w(code pre blockquote a))
    |> strip_tags(~w(hr img br div span))
  end

  # <h1>-<h6> → <b>text</b>\n
  defp convert_headers(html) do
    Regex.replace(~r/<h[1-6][^>]*>(.*?)<\/h[1-6]>/s, html, fn _, inner ->
      "<b>#{String.trim(inner)}</b>\n"
    end)
  end

  # Convert <table> to plain-text rows with | separators.
  defp convert_tables(html) do
    Regex.replace(~r/<table[^>]*>(.*?)<\/table>/s, html, fn _, inner ->
      inner
      |> extract_rows()
      |> Enum.map_join("\n", &format_row/1)
      |> Kernel.<>("\n")
    end)
  end

  defp extract_rows(html) do
    Regex.scan(~r/<tr[^>]*>(.*?)<\/tr>/s, html, capture: :all_but_first)
    |> Enum.map(fn [row_html] ->
      header_cells = Regex.scan(~r/<th[^>]*>(.*?)<\/th>/s, row_html, capture: :all_but_first)
      data_cells = Regex.scan(~r/<td[^>]*>(.*?)<\/td>/s, row_html, capture: :all_but_first)

      cond do
        header_cells != [] -> {:header, Enum.map(header_cells, fn [c] -> String.trim(c) end)}
        data_cells != [] -> {:data, Enum.map(data_cells, fn [c] -> String.trim(c) end)}
        true -> {:data, []}
      end
    end)
  end

  defp format_row({:header, cells}), do: "<b>#{Enum.join(cells, " | ")}</b>"
  defp format_row({:data, cells}), do: Enum.join(cells, " | ")

  # Convert <ul>/<ol> lists to text with bullet/number prefixes.
  defp convert_lists(html) do
    html
    |> convert_unordered_lists()
    |> convert_ordered_lists()
  end

  defp convert_unordered_lists(html) do
    Regex.replace(~r/<ul[^>]*>(.*?)<\/ul>/s, html, fn _, inner ->
      inner
      |> extract_list_items()
      |> Enum.map_join("\n", fn item -> "• #{item}" end)
      |> Kernel.<>("\n")
    end)
  end

  defp convert_ordered_lists(html) do
    Regex.replace(~r/<ol[^>]*>(.*?)<\/ol>/s, html, fn _, inner ->
      inner
      |> extract_list_items()
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {item, idx} -> "#{idx}. #{item}" end)
      |> Kernel.<>("\n")
    end)
  end

  defp extract_list_items(html) do
    Regex.scan(~r/<li[^>]*>(.*?)<\/li>/s, html, capture: :all_but_first)
    |> Enum.map(fn [item] -> String.trim(item) end)
  end

  # <p>text</p> → text\n\n
  defp convert_paragraphs(html) do
    Regex.replace(~r/<p[^>]*>(.*?)<\/p>/s, html, "\\1\n\n")
  end

  # Strip attributes from tags (Telegram doesn't support class=, etc.)
  # Preserves href on <a> tags since Telegram needs it.
  defp strip_tag_attributes(html, tags) do
    Enum.reduce(tags, html, fn
      "a", acc ->
        # Keep href, strip everything else
        Regex.replace(~r/<a\s+[^>]*?(href="[^"]*")[^>]*>/, acc, "<a \\1>")

      tag, acc ->
        Regex.replace(~r/<(#{tag})\s+[^>]*>/, acc, "<\\1>")
    end)
  end

  # Strip specific unsupported tags (self-closing and paired).
  defp strip_tags(html, tags) do
    Enum.reduce(tags, html, fn tag, acc ->
      acc
      # Self-closing: <br>, <br/>, <hr />, etc.
      |> then(&Regex.replace(~r/<#{tag}[^>]*\/?>/, &1, ""))
      # Paired: <div>...</div>, <span>...</span>
      |> then(&Regex.replace(~r/<\/#{tag}>/, &1, ""))
    end)
  end

  # Collapse multiple blank lines into at most two newlines.
  defp collapse_whitespace(html) do
    Regex.replace(~r/\n{3,}/, html, "\n\n")
  end
end
