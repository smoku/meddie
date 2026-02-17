defmodule Meddie.Storage.S3 do
  @moduledoc """
  S3-compatible storage for production (Tigris).
  """

  @behaviour Meddie.Storage

  @impl true
  def put(path, data, content_type) do
    bucket()
    |> ExAws.S3.put_object(path, data, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get(path) do
    bucket()
    |> ExAws.S3.get_object(path)
    |> ExAws.request()
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def delete(path) do
    bucket()
    |> ExAws.S3.delete_object(path)
    |> ExAws.request()
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def presigned_url(path, expires_in) do
    config = ExAws.Config.new(:s3)
    ExAws.S3.presigned_url(config, :get, bucket(), path, expires_in: expires_in)
  end

  defp bucket do
    Application.get_env(:meddie, :storage_bucket, "meddie-documents")
  end
end
