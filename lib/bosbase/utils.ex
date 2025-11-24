defmodule Bosbase.Utils do
  @moduledoc false

  @doc "URL-encodes a single path segment."
  def encode_path_segment(value) do
    value
    |> to_string()
    |> URI.encode(&URI.char_unreserved?/1)
  end

  @doc "Normalizes a query map into a keyword list suitable for URI.encode_query/1."
  def normalize_query_params(params) when params in [nil, %{}], do: []

  def normalize_query_params(params) do
    Enum.flat_map(params, fn
      {_key, nil} ->
        []

      {key, list} when is_list(list) ->
        Enum.map(list, fn item -> {to_string(key), to_string(item)} end)

      {key, value} ->
        [{to_string(key), to_string(value)}]
    end)
  end

  @doc "Builds a relative URL with query parameters."
  def build_relative_url(path, query \\ %{}) do
    rel = "/" <> String.trim_leading(path, "/")
    query = normalize_query_params(query)

    if query == [] do
      rel
    else
      rel <> "?" <> URI.encode_query(query)
    end
  end

  @doc "Recursively strips nil values to keep JSON payloads compact."
  def to_serializable(nil), do: nil

  def to_serializable(map) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      {_k, nil}, acc -> acc
      {k, v}, acc -> Map.put(acc, k, to_serializable(v))
    end)
  end

  def to_serializable(list) when is_list(list) do
    Enum.map(list, &to_serializable/1)
  end

  def to_serializable(other), do: other
end
