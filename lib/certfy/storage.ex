defmodule Certfy.Storage do
  @moduledoc """
  Stores template files in the configured S3-compatible object storage (RustFS).
  """

  @extension_regex ~r/\A\.[a-z0-9]{1,10}\z/

  @doc """
  Uploads a template file and returns its object key.
  """
  def put_template(key, body, content_type)
      when is_binary(key) and is_binary(body) and is_binary(content_type) do
    with :ok <- ensure_bucket(),
         {:ok, _response} <-
           bucket()
           |> ExAws.S3.put_object(key, body, content_type: content_type)
           |> ExAws.request() do
      {:ok, key}
    end
  end

  @doc """
  Downloads a template file by its object key.
  """
  def get_template(key) when is_binary(key) do
    case bucket() |> ExAws.S3.get_object(key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes a template file by its object key.
  """
  def delete_template(key) when is_binary(key) do
    case bucket() |> ExAws.S3.delete_object(key) |> ExAws.request() do
      {:ok, _response} -> :ok
      {:error, {:http_error, 404, _response}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Builds a unique and safe object key for a template file.
  """
  def template_key(filename) when is_binary(filename) do
    "templates/#{random_id()}#{extension(filename)}"
  end

  defp extension(filename) do
    extension = filename |> Path.extname() |> String.downcase()

    if Regex.match?(@extension_regex, extension), do: extension, else: ""
  end

  defp random_id do
    :crypto.strong_rand_bytes(18)
    |> Base.url_encode64(padding: false)
  end

  defp ensure_bucket do
    case ExAws.S3.head_bucket(bucket()) |> ExAws.request() do
      {:ok, _response} -> :ok
      {:error, {:http_error, 404, _response}} -> create_bucket()
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_bucket do
    case bucket() |> ExAws.S3.put_bucket(region()) |> ExAws.request() do
      {:ok, _response} -> :ok
      {:error, {:http_error, 409, _response}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp bucket do
    :certfy
    |> Application.fetch_env!(:storage)
    |> Keyword.fetch!(:bucket)
  end

  defp region do
    Application.get_env(:ex_aws, :region, "us-east-1")
  end
end
