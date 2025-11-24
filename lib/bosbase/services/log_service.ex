defmodule Bosbase.LogService do
  @moduledoc "Access to server logs."

  alias Bosbase.ClientResponseError

  def get_list(
        client,
        page \\ 1,
        per_page \\ 30,
        filter \\ "",
        sort \\ "",
        query \\ %{},
        headers \\ %{}
      ) do
    page = if page <= 0, do: 1, else: page
    per_page = if per_page <= 0, do: 30, else: per_page

    params =
      query
      |> Map.new()
      |> Map.put("page", page)
      |> Map.put("perPage", per_page)
      |> maybe_put("filter", filter)
      |> maybe_put("sort", sort)

    client.send("/api/logs", %{query: params, headers: headers})
  end

  def get_one(client, log_id, query \\ %{}, headers \\ %{})

  def get_one(client, log_id, _query, _headers) when log_id in [nil, ""],
    do:
      {:error,
       %ClientResponseError{
         url: client.build_url("/api/logs/", %{}),
         status: 404,
         response: %{"code" => 404, "message" => "Missing required log id.", "data" => %{}}
       }}

  def get_one(client, log_id, query, headers) do
    client.send("/api/logs/#{log_id}", %{query: query, headers: headers})
  end

  def get_stats(client, query \\ %{}, headers \\ %{}) do
    client.send("/api/logs/stats", %{query: query, headers: headers})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
