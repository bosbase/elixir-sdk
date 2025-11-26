# Vector Database API - Elixir SDK Documentation

Vector database operations for semantic search, RAG (Retrieval-Augmented Generation), and AI applications.

> **Note**: Vector operations are currently implemented using sqlite-vec but are designed with abstraction in mind to support future vector database providers.

## Overview

The Vector API provides a unified interface for working with vector embeddings, enabling you to:
- Store and search vector embeddings
- Perform similarity search
- Build RAG applications
- Create recommendation systems
- Enable semantic search capabilities

## Getting Started

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Authenticate as superuser (vectors require superuser auth)
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

## Types

### VectorEmbedding
List of numbers representing a vector embedding.

```elixir
# Example: [0.1, 0.2, 0.3, 0.4]
vector = [0.1, 0.2, 0.3, 0.4]
```

### VectorDocument
A vector document with embedding, metadata, and optional content.

```elixir
%{
  "id" => "doc_001",                    # Unique identifier (auto-generated if not provided)
  "vector" => [0.1, 0.2, 0.3, 0.4],     # The vector embedding
  "metadata" => %{"category" => "tech"}, # Optional metadata (key-value pairs)
  "content" => "Document text"           # Optional text content
}
```

### VectorSearchOptions
Options for vector similarity search.

```elixir
%{
  "queryVector" => [0.1, 0.2, 0.3, 0.4],  # Query vector to search for
  "limit" => 10,                          # Max results (default: 10, max: 100)
  "filter" => %{"category" => "tech"},    # Optional metadata filter
  "minScore" => 0.7,                      # Minimum similarity score threshold
  "maxDistance" => 0.3,                   # Maximum distance threshold
  "includeDistance" => true,              # Include distance in results
  "includeContent" => true                # Include full document content
}
```

## Collection Management

### Create Collection

Create a new vector collection with specified dimension and distance metric.

```elixir
# With custom dimension and distance
{:ok, _collection} = Bosbase.vectors()
  |> Bosbase.VectorService.create_collection(pb, "documents", %{
    "dimension" => 384,      # Vector dimension (default: 384)
    "distance" => "cosine"   # Distance metric: 'cosine' (default), 'l2', 'dot'
  })

# Minimal example (uses defaults)
{:ok, _collection} = Bosbase.vectors()
  |> Bosbase.VectorService.create_collection(pb, "documents", %{})
```

**Parameters:**
- `name` (string): Collection name
- `config` (map, optional):
  - `dimension` (integer, optional): Vector dimension. Default: 384
  - `distance` (string, optional): Distance metric. Default: 'cosine'
  - Options: 'cosine', 'l2', 'dot'

### List Collections

Get all available vector collections.

```elixir
{:ok, collections} = Bosbase.vectors()
  |> Bosbase.VectorService.list_collections(pb)

Enum.each(collections, fn collection ->
  IO.puts("#{collection["name"]}: #{collection["count"]} vectors")
end)
```

### Update Collection

Update a vector collection configuration (distance metric and options).
Note: Collection name and dimension cannot be changed after creation.

```elixir
# Change distance metric
{:ok, _updated} = Bosbase.vectors()
  |> Bosbase.VectorService.update_collection(pb, "documents", %{
    "distance" => "l2"  # Change from cosine to L2
  })

# Update with options
{:ok, _updated} = Bosbase.vectors()
  |> Bosbase.VectorService.update_collection(pb, "documents", %{
    "distance" => "inner_product",
    "options" => %{"customOption" => "value"}
  })
```

### Delete Collection

Delete a vector collection and all its data.

```elixir
:ok = Bosbase.vectors()
  |> Bosbase.VectorService.delete_collection(pb, "documents")
```

**⚠️ Warning**: This permanently deletes the collection and all vectors in it!

## Document Operations

### Insert Document

Insert a single vector document.

```elixir
# With custom ID
{:ok, result} = Bosbase.vectors()
  |> Bosbase.VectorService.insert(pb, %{
    "id" => "doc_001",
    "vector" => [0.1, 0.2, 0.3, 0.4],
    "metadata" => %{"category" => "tech", "tags" => ["AI", "ML"]},
    "content" => "Document about machine learning"
  }, "documents")

IO.puts("Inserted: #{result["id"]}")

# Without ID (auto-generated)
{:ok, result2} = Bosbase.vectors()
  |> Bosbase.VectorService.insert(pb, %{
    "vector" => [0.5, 0.6, 0.7, 0.8],
    "content" => "Another document"
  }, "documents")
```

### Batch Insert

Insert multiple vector documents efficiently.

```elixir
{:ok, result} = Bosbase.vectors()
  |> Bosbase.VectorService.batch_insert(pb, %{
    "documents" => [
      %{"vector" => [0.1, 0.2, 0.3], "metadata" => %{"cat" => "A"}, "content" => "Doc A"},
      %{"vector" => [0.4, 0.5, 0.6], "metadata" => %{"cat" => "B"}, "content" => "Doc B"},
      %{"vector" => [0.7, 0.8, 0.9], "metadata" => %{"cat" => "A"}, "content" => "Doc C"}
    ],
    "skipDuplicates" => true  # Skip documents with duplicate IDs
  }, "documents")

IO.puts("Inserted: #{result["insertedCount"]}")
IO.puts("Failed: #{result["failedCount"]}")
IO.inspect(result["ids"])
```

### Get Document

Retrieve a vector document by ID.

```elixir
{:ok, doc} = Bosbase.vectors()
  |> Bosbase.VectorService.get(pb, "doc_001", "documents")

IO.puts("Vector: #{inspect(doc["vector"])}")
IO.puts("Content: #{doc["content"]}")
IO.inspect(doc["metadata"])
```

### Update Document

Update an existing vector document.

```elixir
# Update all fields
{:ok, _updated} = Bosbase.vectors()
  |> Bosbase.VectorService.update(pb, "doc_001", %{
    "vector" => [0.9, 0.8, 0.7, 0.6],
    "metadata" => %{"updated" => true},
    "content" => "Updated content"
  }, "documents")

# Partial update (only metadata and content)
{:ok, _updated} = Bosbase.vectors()
  |> Bosbase.VectorService.update(pb, "doc_001", %{
    "metadata" => %{"category" => "updated"},
    "content" => "New content"
  }, "documents")
```

### Delete Document

Delete a vector document.

```elixir
:ok = Bosbase.vectors()
  |> Bosbase.VectorService.delete(pb, "doc_001", "documents")
```

### List Documents

List all documents in a collection with pagination.

```elixir
# Get first page
{:ok, result} = Bosbase.vectors()
  |> Bosbase.VectorService.list(pb, "documents", 1, 100)

IO.puts("Page #{result["page"]} of #{result["totalPages"]}")
Enum.each(result["items"], fn item ->
  IO.puts("#{item["id"]} - #{item["content"]}")
end)
```

## Vector Search

### Basic Search

Perform similarity search on vectors.

```elixir
{:ok, results} = Bosbase.vectors()
  |> Bosbase.VectorService.search(pb, %{
    "queryVector" => [0.1, 0.2, 0.3, 0.4],
    "limit" => 10
  }, "documents")

Enum.each(results["results"], fn result ->
  IO.puts("Score: #{result["score"]} - #{result["document"]["content"]}")
end)
```

### Advanced Search

```elixir
{:ok, results} = Bosbase.vectors()
  |> Bosbase.VectorService.search(pb, %{
    "queryVector" => [0.1, 0.2, 0.3, 0.4],
    "limit" => 20,
    "minScore" => 0.7,              # Minimum similarity threshold
    "maxDistance" => 0.3,           # Maximum distance threshold
    "includeDistance" => true,       # Include distance metric
    "includeContent" => true,        # Include full content
    "filter" => %{"category" => "tech"}  # Filter by metadata
  }, "documents")

IO.puts("Found #{results["totalMatches"]} matches in #{results["queryTime"]}ms")
Enum.each(results["results"], fn r ->
  IO.puts("Score: #{r["score"]}, Distance: #{r["distance"]}")
  IO.puts("Content: #{r["document"]["content"]}")
end)
```

## Common Use Cases

### Semantic Search

```elixir
defmodule SemanticSearch do
  def index_documents(pb, documents) do
    Enum.each(documents, fn doc ->
      # Generate embedding using your model
      embedding = generate_embedding(doc["text"])
      
      Bosbase.vectors()
        |> Bosbase.VectorService.insert(pb, %{
          "id" => doc["id"],
          "vector" => embedding,
          "content" => doc["text"],
          "metadata" => %{"type" => "tutorial"}
        }, "articles")
    end)
  end

  def search(pb, query_text) do
    query_embedding = generate_embedding(query_text)
    
    {:ok, results} = Bosbase.vectors()
      |> Bosbase.VectorService.search(pb, %{
        "queryVector" => query_embedding,
        "limit" => 5,
        "minScore" => 0.75
      }, "articles")
    
    Enum.map(results["results"], fn r ->
      %{"score" => r["score"], "content" => r["document"]["content"]}
    end)
  end
end
```

### RAG (Retrieval-Augmented Generation)

```elixir
def retrieve_context(pb, query, limit \\ 5) do
  query_embedding = generate_embedding(query)
  
  {:ok, results} = Bosbase.vectors()
    |> Bosbase.VectorService.search(pb, %{
      "queryVector" => query_embedding,
      "limit" => limit,
      "minScore" => 0.75,
      "includeContent" => true
    }, "knowledge_base")
  
  Enum.map(results["results"], fn r -> r["document"]["content"] end)
end

# Use with your LLM
context = retrieve_context(pb, "What are best practices for security?")
# answer = llm.generate(context, user_query)
```

## Best Practices

### Vector Dimensions

Choose the right dimension for your use case:

- **OpenAI embeddings**: 1536 (`text-embedding-3-large`)
- **Sentence Transformers**: 384-768
  - `all-MiniLM-L6-v2`: 384
  - `all-mpnet-base-v2`: 768
- **Custom models**: Match your model's output

### Distance Metrics

| Metric | Best For | Notes |
|--------|----------|-------|
| `cosine` | Text embeddings | Works well with normalized vectors |
| `l2` | General similarity | Euclidean distance |
| `dot` | Performance | Requires normalized vectors |

### Performance Tips

1. **Use batch insert** for multiple vectors
2. **Set appropriate limits** to avoid excessive results
3. **Use metadata filtering** to narrow search space
4. **Enable indexes** (automatic with sqlite-vec)

### Security

- All vector endpoints require superuser authentication
- Never expose credentials in client-side code
- Use environment variables for sensitive data

## Error Handling

```elixir
case Bosbase.vectors()
     |> Bosbase.VectorService.search(pb, %{
       "queryVector" => [0.1, 0.2, 0.3]
     }, "documents") do
  {:ok, results} ->
    IO.inspect(results)
  {:error, %{status: 404}} ->
    IO.puts("Collection not found")
  {:error, %{status: 400}} ->
    IO.puts("Invalid request")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Related Documentation

- [LangChaingo API](./LANGCHAINGO_API.md) - RAG workflows
- [LLM Documents](./LLM_DOCUMENTS.md) - Document management

