defmodule Meddie.Storage.Local do
  @moduledoc """
  Local filesystem storage for development and testing.
  Stores files under `priv/static/uploads/`.
  """

  @behaviour Meddie.Storage

  @upload_dir "priv/static/uploads"

  @impl true
  def put(path, data, _content_type) do
    full_path = Path.join(@upload_dir, path)
    full_path |> Path.dirname() |> File.mkdir_p!()
    File.write(full_path, data)
  end

  @impl true
  def get(path) do
    full_path = Path.join(@upload_dir, path)
    File.read(full_path)
  end

  @impl true
  def delete(path) do
    full_path = Path.join(@upload_dir, path)

    case File.rm(full_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end

  @impl true
  def presigned_url(path, _expires_in) do
    {:ok, "/uploads/#{path}"}
  end
end
