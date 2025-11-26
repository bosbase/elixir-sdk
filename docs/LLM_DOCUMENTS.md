# LLM Document API - Elixir SDK Documentation

The `LLMDocumentService` wraps the `/api/llm-documents` endpoints that are backed by the embedded chromem-go vector store (persisted in rqlite). Each document contains text content, optional metadata and an embedding vector that can be queried with semantic search.

## Getting Started

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Create a logical namespace for your documents
{:ok, _collection} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.create_collection(pb, "knowledge-base", %{
    "domain" => "internal"
  })
```

## Insert Documents

```elixir
# Insert document without ID (auto-generated)
{:ok, doc} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.insert(pb, "knowledge-base", %{
    "content" => "Leaves are green because chlorophyll absorbs red and blue light.",
    "metadata" => %{"topic" => "biology"}
  })

# Insert document with custom ID
{:ok, doc} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.insert(pb, "knowledge-base", %{
    "id" => "sky",
    "content" => "The sky is blue because of Rayleigh scattering.",
    "metadata" => %{"topic" => "physics"}
  })
```

## Query Documents

```elixir
options = %{
  "queryText" => "Why is the sky blue?",
  "limit" => 3,
  "where" => %{"topic" => "physics"}
}

{:ok, result} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.query(pb, "knowledge-base", options)

Enum.each(result["results"] || [], fn match ->
  IO.puts("#{match["id"]} - similarity: #{match["similarity"]}")
end)
```

## Manage Documents

```elixir
# Update a document
{:ok, _updated} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.update(
    pb,
    "knowledge-base",
    "sky",
    %{"metadata" => %{"topic" => "physics", "reviewed" => "true"}}
  )

# List documents with pagination
{:ok, page} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.list(pb, "knowledge-base", 1, 25)

IO.inspect(page["items"])
IO.inspect(page["totalItems"])

# Delete unwanted entries
:ok = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.delete(pb, "knowledge-base", "sky")
```

## Collection Management

```elixir
# List all collections
{:ok, collections} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.list_collections(pb)

# Create collection
{:ok, _collection} = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.create_collection(pb, "my-collection", %{
    "domain" => "public"
  })

# Delete collection
:ok = Bosbase.llm_documents()
  |> Bosbase.LLMDocumentService.delete_collection(pb, "my-collection")
```

## Complete Examples

### Example 1: Knowledge Base Management

```elixir
defmodule KnowledgeBase do
  def setup(pb) do
    # Create collection
    {:ok, _} = Bosbase.llm_documents()
      |> Bosbase.LLMDocumentService.create_collection(pb, "knowledge-base", %{
        "domain" => "internal"
      })
  end

  def add_document(pb, id, content, metadata \\ %{}) do
    Bosbase.llm_documents()
      |> Bosbase.LLMDocumentService.insert(pb, "knowledge-base", %{
        "id" => id,
        "content" => content,
        "metadata" => metadata
      })
  end

  def search(pb, query, limit \\ 5) do
    options = %{
      "queryText" => query,
      "limit" => limit
    }

    case Bosbase.llm_documents()
         |> Bosbase.LLMDocumentService.query(pb, "knowledge-base", options) do
      {:ok, result} ->
        result["results"] || []
      {:error, _} ->
        []
    end
  end
end

# Usage
pb = Client.new("http://localhost:8090")
KnowledgeBase.setup(pb)

KnowledgeBase.add_document(
  pb,
  "doc1",
  "Elixir is a functional programming language.",
  %{"topic" => "programming", "language" => "elixir"}
)

results = KnowledgeBase.search(pb, "What is Elixir?", 3)
Enum.each(results, fn result ->
  IO.puts("#{result["id"]}: #{result["similarity"]}")
end)
```

## HTTP Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| `GET /api/llm-documents/collections` | List collections |
| `POST /api/llm-documents/collections/{name}` | Create collection |
| `DELETE /api/llm-documents/collections/{name}` | Delete collection |
| `GET /api/llm-documents/{collection}` | List documents |
| `POST /api/llm-documents/{collection}` | Insert document |
| `GET /api/llm-documents/{collection}/{id}` | Fetch document |
| `PATCH /api/llm-documents/{collection}/{id}` | Update document |
| `DELETE /api/llm-documents/{collection}/{id}` | Delete document |
| `POST /api/llm-documents/{collection}/documents/query` | Query by semantic similarity |

## Related Documentation

- [LangChaingo API](./LANGCHAINGO_API.md) - RAG and LLM workflows
- [Vector API](./VECTOR_API.md) - Vector database operations

