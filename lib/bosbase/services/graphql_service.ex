defmodule Bosbase.GraphQLService do
  @moduledoc "Simple GraphQL helper."

  def query(
        client,
        query_string,
        variables \\ %{},
        operation_name \\ nil,
        query_params \\ %{},
        headers \\ %{},
        timeout_ms \\ nil
      ) do
    payload = %{
      "query" => query_string,
      "variables" => Map.new(variables || %{})
    }

    payload =
      if operation_name in [nil, ""] do
        payload
      else
        Map.put(payload, "operationName", operation_name)
      end

    client.send("/api/graphql", %{
      method: :post,
      body: payload,
      query: query_params,
      headers: headers,
      timeout: timeout_ms
    })
  end
end
