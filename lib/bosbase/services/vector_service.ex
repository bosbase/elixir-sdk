defmodule Bosbase.VectorService do
  @moduledoc "Vector API helpers."
  alias Bosbase.Utils

  def collection_path(base_path, collection) do
    if collection in [nil, ""] do
      base_path
    else
      base_path <> "/" <> Utils.encode_path_segment(collection)
    end
  end

  def insert(client, doc, collection \\ "", query \\ %{}, headers \\ %{}) do
    client.send(collection_path("/api/vectors", collection), %{
      method: :post,
      body: doc,
      query: query,
      headers: headers
    })
  end

  def batch_insert(client, opts, collection \\ "", query \\ %{}, headers \\ %{}) do
    client.send(collection_path("/api/vectors", collection) <> "/documents/batch", %{
      method: :post,
      body: opts,
      query: query,
      headers: headers
    })
  end

  def update(client, document_id, doc, collection \\ "", query \\ %{}, headers \\ %{}) do
    path =
      collection_path("/api/vectors", collection) <> "/" <> Utils.encode_path_segment(document_id)

    client.send(path, %{method: :patch, body: doc, query: query, headers: headers})
  end

  def delete(client, document_id, collection \\ "", body \\ %{}, query \\ %{}, headers \\ %{}) do
    path =
      collection_path("/api/vectors", collection) <> "/" <> Utils.encode_path_segment(document_id)

    client.send(path, %{method: :delete, body: body, query: query, headers: headers})
    |> case do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def search(client, options, collection \\ "", query \\ %{}, headers \\ %{}) do
    client.send(collection_path("/api/vectors", collection) <> "/documents/search", %{
      method: :post,
      body: options,
      query: query,
      headers: headers
    })
  end

  def get(client, document_id, collection \\ "", query \\ %{}, headers \\ %{}) do
    path =
      collection_path("/api/vectors", collection) <> "/" <> Utils.encode_path_segment(document_id)

    client.send(path, %{query: query, headers: headers})
  end

  def list(client, collection \\ "", page \\ nil, per_page \\ nil, query \\ %{}, headers \\ %{}) do
    params =
      query
      |> Map.new()
      |> maybe_put("page", page)
      |> maybe_put("perPage", per_page)

    client.send(collection_path("/api/vectors", collection), %{query: params, headers: headers})
  end

  def create_collection(client, name, config, query \\ %{}, headers \\ %{}) do
    client.send("/api/vectors/collections/#{Utils.encode_path_segment(name)}", %{
      method: :post,
      body: config,
      query: query,
      headers: headers
    })
  end

  def update_collection(client, name, config, query \\ %{}, headers \\ %{}) do
    client.send("/api/vectors/collections/#{Utils.encode_path_segment(name)}", %{
      method: :patch,
      body: config,
      query: query,
      headers: headers
    })
  end

  def delete_collection(client, name, body \\ %{}, query \\ %{}, headers \\ %{}) do
    client.send("/api/vectors/collections/#{Utils.encode_path_segment(name)}", %{
      method: :delete,
      body: body,
      query: query,
      headers: headers
    })
  end

  def list_collections(client, query \\ %{}, headers \\ %{}) do
    client.send("/api/vectors/collections", %{query: query, headers: headers})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
