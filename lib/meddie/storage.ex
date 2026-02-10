defmodule Meddie.Storage do
  @moduledoc """
  Behaviour and facade for file storage (local or S3-compatible).
  """

  @callback put(path :: String.t(), data :: binary(), content_type :: String.t()) ::
              :ok | {:error, term()}

  @callback get(path :: String.t()) ::
              {:ok, binary()} | {:error, term()}

  @callback delete(path :: String.t()) ::
              :ok | {:error, term()}

  @callback presigned_url(path :: String.t(), expires_in :: pos_integer()) ::
              {:ok, String.t()} | {:error, term()}

  def put(path, data, content_type), do: impl().put(path, data, content_type)
  def get(path), do: impl().get(path)
  def delete(path), do: impl().delete(path)
  def presigned_url(path, expires_in \\ 900), do: impl().presigned_url(path, expires_in)

  defp impl, do: Application.get_env(:meddie, :storage_impl, Meddie.Storage.Local)
end
