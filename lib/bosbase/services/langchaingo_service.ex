defmodule Bosbase.LangChaingoService do
  @moduledoc "LangChaingo helpers (completions, RAG, SQL)."
  alias Bosbase.Client

  def completions(client, request, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/langchaingo/completions", %{
      method: :post,
      body: request,
      query: query,
      headers: headers
    })
  end

  def rag(client, request, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/langchaingo/rag", %{
      method: :post,
      body: request,
      query: query,
      headers: headers
    })
  end

  def query_documents(client, request, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/langchaingo/documents/query", %{
      method: :post,
      body: request,
      query: query,
      headers: headers
    })
  end

  def sql(client, request, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/langchaingo/sql", %{
      method: :post,
      body: request,
      query: query,
      headers: headers
    })
  end
end
