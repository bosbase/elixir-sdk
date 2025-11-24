defmodule Bosbase.FileService do
  @moduledoc "Utilities for working with files."
  alias Bosbase.Utils

  @doc """
  Builds the download URL for a record file.
  """
  def get_url(client, record, filename, opts \\ %{}) do
    record_id = record[:id] || record["id"]

    collection =
      record[:collectionId] || record["collectionId"] ||
        record[:collectionName] || record["collectionName"] || ""

    cond do
      is_nil(record_id) or record_id == "" ->
        ""

      filename in [nil, ""] ->
        ""

      true ->
        params = Map.new(opts[:query] || opts["query"] || %{})

        params =
          params
          |> maybe_put(opts, [:thumb, "thumb"], "thumb")
          |> maybe_put(opts, [:token, "token"], "token")
          |> maybe_put(opts, [:download, "download"], "download")

        client.build_url(
          "/api/files/#{Utils.encode_path_segment(collection)}/#{Utils.encode_path_segment(record_id)}/#{Utils.encode_path_segment(filename)}",
          params
        )
    end
  end

  @doc "Requests a temporary file token."
  def get_token(client, body \\ %{}, query \\ %{}, headers \\ %{}) do
    client.send("/api/files/token", %{method: :post, body: body, query: query, headers: headers})
  end

  defp maybe_put(params, _opts, _keys, _target) when params == nil, do: params

  defp maybe_put(params, opts, keys, target) do
    case Enum.find_value(keys, fn k -> Map.get(opts, k) end) do
      nil -> params
      "" -> params
      value -> Map.put(params, target, value)
    end
  end
end
