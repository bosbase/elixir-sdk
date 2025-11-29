defmodule Bosbase.HealthService do
  @moduledoc "Health check endpoints."
  alias Bosbase.Client

  def check(client, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/health", %{query: query, headers: headers})
  end
end
