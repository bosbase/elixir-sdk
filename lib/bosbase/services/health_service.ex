defmodule Bosbase.HealthService do
  @moduledoc "Health check endpoints."

  def check(client, query \\ %{}, headers \\ %{}) do
    client.send("/api/health", %{query: query, headers: headers})
  end
end
