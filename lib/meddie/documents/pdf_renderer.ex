defmodule Meddie.Documents.PdfRenderer do
  @moduledoc """
  Converts PDF pages to images using poppler-utils (pdftoppm).
  Requires `poppler-utils` to be installed on the system.

  macOS: `brew install poppler`
  Linux/Docker: `apt-get install -y poppler-utils`
  """

  require Logger

  @doc """
  Renders each page of a PDF to a PNG image.
  Returns `{:ok, [{page_number, image_binary}]}` or `{:error, reason}`.
  """
  def render_pages(pdf_binary) do
    tmp_dir = System.tmp_dir!()
    unique = :erlang.unique_integer([:positive])
    input_path = Path.join(tmp_dir, "meddie_pdf_#{unique}.pdf")
    output_prefix = Path.join(tmp_dir, "meddie_page_#{unique}")

    try do
      File.write!(input_path, pdf_binary)

      case System.cmd("pdftoppm", ["-png", "-r", "200", input_path, output_prefix],
             stderr_to_stdout: true
           ) do
        {_output, 0} ->
          pages = collect_pages(output_prefix)
          {:ok, pages}

        {output, code} ->
          Logger.error("pdftoppm failed (exit #{code}): #{output}")
          {:error, "pdftoppm failed: #{String.trim(output)}"}
      end
    rescue
      e in ErlangError ->
        {:error, "pdftoppm not found. Install poppler-utils: #{Exception.message(e)}"}
    after
      File.rm(input_path)
    end
  end

  @doc """
  Returns the number of pages in a PDF using pdfinfo.
  """
  def page_count(pdf_binary) do
    tmp_path =
      Path.join(System.tmp_dir!(), "meddie_count_#{:erlang.unique_integer([:positive])}.pdf")

    try do
      File.write!(tmp_path, pdf_binary)

      case System.cmd("pdfinfo", [tmp_path], stderr_to_stdout: true) do
        {output, 0} ->
          case Regex.run(~r/Pages:\s+(\d+)/, output) do
            [_, count] -> {:ok, String.to_integer(count)}
            _ -> {:error, "could not parse page count"}
          end

        {output, _} ->
          {:error, "pdfinfo failed: #{String.trim(output)}"}
      end
    rescue
      e in ErlangError ->
        {:error, "pdfinfo not found. Install poppler-utils: #{Exception.message(e)}"}
    after
      File.rm(tmp_path)
    end
  end

  defp collect_pages(output_prefix) do
    dir = Path.dirname(output_prefix)
    basename = Path.basename(output_prefix)

    dir
    |> File.ls!()
    |> Enum.filter(&String.starts_with?(&1, basename))
    |> Enum.filter(&String.ends_with?(&1, ".png"))
    |> Enum.sort()
    |> Enum.with_index(1)
    |> Enum.map(fn {filename, page_num} ->
      full_path = Path.join(dir, filename)
      data = File.read!(full_path)
      File.rm(full_path)
      {page_num, data}
    end)
  end
end
