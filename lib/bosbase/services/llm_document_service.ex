defmodule Bosbase.LLMDocumentService do
  @moduledoc "LLM document collection helpers."
  alias Bosbase.Utils

  @base "/api/llm-documents"

  def list_collections(client, query \\ %{}, headers \\ %{}) do
    client.send(@base <> "/collections", %{query: query, headers: headers})
  end

  def create_collection(client, name, metadata \\ %{}, query \\ %{}, headers \\ %{}) do
    client.send(@base <> "/collections/#{Utils.encode_path_segment(name)}", %{
      method: :post,
      body: %{"metadata" => metadata},
      query: query,
      headers: headers
    })
  end

  def delete_collection(client, name, query \\ %{}, headers \\ %{}) do
    client.send(@base <> "/collections/#{Utils.encode_path_segment(name)}", %{
      method: :delete,
      query: query,
      headers: headers
    })
    |> case do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def insert(client, collection, doc, query \\ %{}, headers \\ %{}) do
    client.send(collection_path(collection), %{
      method: :post,
      body: doc,
      query: query,
      headers: headers
    })
  end

  def get(client, collection, document_id, query \\ %{}, headers \\ %{}) do
    client.send(collection_path(collection) <> "/#{Utils.encode_path_segment(document_id)}", %{
      query: query,
      headers: headers
    })
  end

  def update(client, collection, document_id, doc, query \\ %{}, headers \\ %{}) do
    client.send(collection_path(collection) <> "/#{Utils.encode_path_segment(document_id)}", %{
      method: :patch,
      body: doc,
      query: query,
      headers: headers
    })
  end

  def delete(client, collection, document_id, query \\ %{}, headers \\ %{}) do
    client.send(collection_path(collection) <> "/#{Utils.encode_path_segment(document_id)}", %{
      method: :delete,
      query: query,
      headers: headers
    })
  end

  def list(client, collection, page \\ nil, per_page \\ nil, query \\ %{}, headers \\ %{}) do
    params =
      query
      |> Map.new()
      |> maybe_put("page", page)
      |> maybe_put("perPage", per_page)

    client.send(collection_path(collection), %{query: params, headers: headers})
  end

  def query(client, collection, options, query \\ %{}, headers \\ %{}) do
    path = collection_path(collection) <> "/documents/query"
    client.send(path, %{method: :post, body: options, query: query, headers: headers})
  end

  defp collection_path(collection) do
    @base <> "/" <> Utils.encode_path_segment(collection)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
