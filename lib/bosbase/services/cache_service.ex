defmodule Bosbase.CacheService do
  @moduledoc "Cache service helpers."
  alias Bosbase.Utils

  def list(client, query \\ %{}, headers \\ %{}) do
    client.send("/api/cache", %{query: query, headers: headers})
  end

  def create(
        client,
        name,
        size_bytes \\ nil,
        default_ttl_seconds \\ nil,
        read_timeout_ms \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("name", name)
      |> maybe_put("sizeBytes", size_bytes)
      |> maybe_put("defaultTTLSeconds", default_ttl_seconds)
      |> maybe_put("readTimeoutMs", read_timeout_ms)

    client.send("/api/cache", %{method: :post, body: payload, query: query, headers: headers})
  end

  def update(client, name, body \\ %{}, query \\ %{}, headers \\ %{}) do
    client.send("/api/cache/#{Utils.encode_path_segment(name)}", %{
      method: :patch,
      body: body,
      query: query,
      headers: headers
    })
  end

  def delete(client, name, query \\ %{}, headers \\ %{}) do
    client.send("/api/cache/#{Utils.encode_path_segment(name)}", %{
      method: :delete,
      query: query,
      headers: headers
    })
    |> case do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def set_entry(
        client,
        cache,
        key,
        value,
        ttl_seconds \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("value", value)
      |> maybe_put("ttlSeconds", ttl_seconds)

    path =
      "/api/cache/#{Utils.encode_path_segment(cache)}/entries/#{Utils.encode_path_segment(key)}"

    client.send(path, %{method: :put, body: payload, query: query, headers: headers})
  end

  def get_entry(client, cache, key, query \\ %{}, headers \\ %{}) do
    path =
      "/api/cache/#{Utils.encode_path_segment(cache)}/entries/#{Utils.encode_path_segment(key)}"

    client.send(path, %{query: query, headers: headers})
  end

  def renew_entry(
        client,
        cache,
        key,
        ttl_seconds \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> maybe_put("ttlSeconds", ttl_seconds)

    path =
      "/api/cache/#{Utils.encode_path_segment(cache)}/entries/#{Utils.encode_path_segment(key)}"

    client.send(path, %{method: :patch, body: payload, query: query, headers: headers})
  end

  def delete_entry(client, cache, key, query \\ %{}, headers \\ %{}) do
    path =
      "/api/cache/#{Utils.encode_path_segment(cache)}/entries/#{Utils.encode_path_segment(key)}"

    client.send(path, %{method: :delete, query: query, headers: headers})
    |> case do
      {:ok, _} -> :ok
      other -> other
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
