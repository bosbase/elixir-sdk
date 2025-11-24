defmodule Bosbase.BatchService do
  @moduledoc """
  Builds transactional batch requests.

  Functional API: chain operations on the returned struct, then call `send/4`.
  """

  alias Bosbase.Utils

  defstruct [:client, requests: []]

  @type t :: %__MODULE__{client: any(), requests: list()}

  def new(client), do: %__MODULE__{client: client, requests: []}

  def create(
        %__MODULE__{} = batch,
        collection,
        body \\ %{},
        query \\ %{},
        files \\ %{},
        headers \\ %{},
        expand \\ nil,
        fields \\ nil
      ) do
    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    url =
      Utils.build_relative_url(
        "/api/collections/#{Utils.encode_path_segment(collection)}/records",
        params
      )

    add_request(batch, "POST", url, headers, body, files)
  end

  def upsert(
        %__MODULE__{} = batch,
        collection,
        body \\ %{},
        query \\ %{},
        files \\ %{},
        headers \\ %{},
        expand \\ nil,
        fields \\ nil
      ) do
    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    url =
      Utils.build_relative_url(
        "/api/collections/#{Utils.encode_path_segment(collection)}/records",
        params
      )

    add_request(batch, "PUT", url, headers, body, files)
  end

  def update(
        %__MODULE__{} = batch,
        collection,
        record_id,
        body \\ %{},
        query \\ %{},
        files \\ %{},
        headers \\ %{},
        expand \\ nil,
        fields \\ nil
      ) do
    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    url =
      Utils.build_relative_url(
        "/api/collections/#{Utils.encode_path_segment(collection)}/records/#{Utils.encode_path_segment(record_id)}",
        params
      )

    add_request(batch, "PATCH", url, headers, body, files)
  end

  def delete(
        %__MODULE__{} = batch,
        collection,
        record_id,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    url =
      Utils.build_relative_url(
        "/api/collections/#{Utils.encode_path_segment(collection)}/records/#{Utils.encode_path_segment(record_id)}",
        query
      )

    add_request(batch, "DELETE", url, headers, body, %{})
  end

  def send(%__MODULE__{client: client} = batch, body \\ %{}, query \\ %{}, headers \\ %{}) do
    {requests_payload, attachments} =
      Enum.with_index(batch.requests)
      |> Enum.reduce({[], %{}}, fn {req, idx}, {list, files} ->
        req_payload = %{
          "method" => req.method,
          "url" => req.url,
          "headers" => req.headers,
          "body" => req.body
        }

        merged_files =
          Enum.reduce(req.files || %{}, files, fn {field, file}, acc ->
            Map.put(acc, "requests.#{idx}.#{field}", file)
          end)

        {[req_payload | list], merged_files}
      end)

    payload =
      body
      |> Map.new()
      |> Map.put("requests", Enum.reverse(requests_payload))

    case client.send("/api/batch", %{
           method: :post,
           body: payload,
           query: query,
           headers: headers,
           files: attachments
         }) do
      {:ok, result} ->
        {:ok, result, %__MODULE__{batch | requests: []}}

      other ->
        other
    end
  end

  defp add_request(%__MODULE__{} = batch, method, url, headers, body, files) do
    req = %{
      method: method,
      url: url,
      headers: Map.new(headers || %{}),
      body: body,
      files: files || %{}
    }

    %{batch | requests: batch.requests ++ [req]}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
