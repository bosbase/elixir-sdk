defmodule Bosbase.SQLService do
  @moduledoc "Superuser SQL execution helpers."

  alias Bosbase.{Client, ClientResponseError}

  @doc """
  Executes a SQL statement via `/api/sql/execute`.

  Only superusers can call this endpoint.
  """
  def execute(client, query, query_params \\ %{}, headers \\ %{}, timeout_ms \\ nil) do
    trimmed = String.trim(to_string(query || ""))

    if trimmed == "" do
      {:error,
       %ClientResponseError{
         status: 400,
         response: %{"message" => "query is required"}
       }}
    else
      Client.send(client, "/api/sql/execute", %{
        method: :post,
        body: %{"query" => trimmed},
        query: query_params,
        headers: headers,
        timeout: timeout_ms
      })
    end
  end
end
