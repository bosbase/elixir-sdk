# LangChaingo API - Elixir SDK Documentation

BosBase exposes the `/api/langchaingo` endpoints so you can run LangChainGo powered workflows without leaving the platform. The Elixir SDK wraps these endpoints with the `Bosbase.langchaingo()` service.

The service exposes four high-level methods:

| Method | HTTP Endpoint | Description |
| --- | --- | --- |
| `Bosbase.LangChaingoService.completions()` | `POST /api/langchaingo/completions` | Runs a chat/completion call using the configured LLM provider. |
| `Bosbase.LangChaingoService.rag()` | `POST /api/langchaingo/rag` | Runs a retrieval-augmented generation pass over an `llmDocuments` collection. |
| `Bosbase.LangChaingoService.query_documents()` | `POST /api/langchaingo/documents/query` | Asks an OpenAI-backed chain to answer questions over `llmDocuments` and optionally return matched sources. |
| `Bosbase.LangChaingoService.sql()` | `POST /api/langchaingo/sql` | Lets OpenAI draft and execute SQL against your BosBase database, then returns the results. |

Each method accepts an optional `model` configuration:

```elixir
%{
  "provider" => "openai",  # or "ollama" or other string
  "model" => "gpt-4o-mini",
  "apiKey" => "optional-api-key",
  "baseUrl" => "optional-base-url"
}
```

If you omit the `model` section, BosBase defaults to `provider: "openai"` and `model: "gpt-4o-mini"` with credentials read from the server environment. Passing an `apiKey` lets you override server defaults on a per-request basis.

## Text + Chat Completions

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

request = %{
  "model" => %{
    "provider" => "openai",
    "model" => "gpt-4o-mini"
  },
  "messages" => [
    %{"role" => "system", "content" => "Answer in one sentence."},
    %{"role" => "user", "content" => "Explain Rayleigh scattering."}
  ],
  "temperature" => 0.2
}

{:ok, completion} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.completions(pb, request)

IO.puts(completion["content"])
```

The completion response mirrors the LangChainGo `ContentResponse` shape, so you can inspect the `functionCall`, `toolCalls`, or `generationInfo` fields when you need more than plain text.

## Retrieval-Augmented Generation (RAG)

Pair the LangChaingo endpoints with the `/api/llm-documents` store to build RAG workflows. The backend automatically uses the chromem-go collection configured for the target LLM collection.

```elixir
request = %{
  "collection" => "knowledge-base",
  "question" => "Why is the sky blue?",
  "topK" => 4,
  "returnSources" => true,
  "filters" => %{
    "where" => %{"topic" => "physics"}
  }
}

{:ok, answer} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.rag(pb, request)

IO.puts(answer["answer"])

if answer["sources"] do
  Enum.each(answer["sources"], fn source ->
    score = if source["score"], do: :erlang.float_to_binary(source["score"], decimals: 3), else: "N/A"
    title = get_in(source, ["metadata", "title"]) || "No title"
    IO.puts("#{score} #{title}")
  end)
end
```

Set `promptTemplate` when you want to control how the retrieved context is stuffed into the answer prompt:

```elixir
request = %{
  "collection" => "knowledge-base",
  "question" => "Summarize the explanation below in 2 sentences.",
  "promptTemplate" => "Context:\n{{.context}}\n\nQuestion: {{.question}}\nSummary:"
}

{:ok, answer} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.rag(pb, request)
```

## LLM Document Queries

> **Note**: This interface is only available to superusers.

When you want to pose a question to a specific `llmDocuments` collection and have LangChaingo+OpenAI synthesize an answer, use `query_documents`. It mirrors the RAG arguments but takes a `query` field:

```elixir
request = %{
  "collection" => "knowledge-base",
  "query" => "List three bullet points about Rayleigh scattering.",
  "topK" => 3,
  "returnSources" => true
}

{:ok, response} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.query_documents(pb, request)

IO.puts(response["answer"])
IO.inspect(response["sources"])
```

## SQL Generation + Execution

> **Important Notes**:
> - This interface is only available to superusers. Requests authenticated with regular `users` tokens return a `401 Unauthorized`.
> - It is recommended to execute query statements (SELECT) only.
> - **Do not use this interface for adding or modifying table structures.** Collection interfaces should be used instead for managing database schema.
> - Directly using this interface for initializing table structures and adding or modifying database tables will cause errors that prevent the automatic generation of APIs.

Superuser tokens (`_superusers` records) can ask LangChaingo to have OpenAI propose a SQL statement, execute it, and return both the generated SQL and execution output.

```elixir
# Authenticate as superuser first
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

request = %{
  "query" => "Add a demo project row if it doesn't exist, then list the 5 most recent projects.",
  "tables" => ["projects"],  # optional hint to limit which tables the model sees
  "topK" => 5
}

{:ok, result} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.sql(pb, request)

IO.puts(result["sql"])    # Generated SQL
IO.puts(result["answer"]) # Model's summary of the execution
IO.inspect(result["columns"])
IO.inspect(result["rows"])
```

Use `tables` to restrict which table definitions and sample rows are passed to the model, and `topK` to control how many rows the model should target when building queries. You can also pass the optional `model` block described above to override the default OpenAI model or key for this call.

## Complete Examples

### Example 1: Simple Chat Completion

```elixir
defmodule ChatCompletion do
  def ask(pb, question) do
    request = %{
      "model" => %{
        "provider" => "openai",
        "model" => "gpt-4o-mini"
      },
      "messages" => [
        %{"role" => "system", "content" => "Answer concisely."},
        %{"role" => "user", "content" => question}
      ],
      "temperature" => 0.4
    }

    case Bosbase.langchaingo()
         |> Bosbase.LangChaingoService.completions(pb, request) do
      {:ok, completion} ->
        completion["content"]
      {:error, error} ->
        "Error: #{inspect(error)}"
    end
  end
end

# Usage
pb = Client.new("http://localhost:8090")
answer = ChatCompletion.ask(pb, "Give me a fun fact about Mars.")
IO.puts(answer)
```

### Example 2: RAG Workflow

```elixir
defmodule RAGService do
  def ask_question(pb, collection, question) do
    request = %{
      "collection" => collection,
      "question" => question,
      "topK" => 3,
      "returnSources" => true
    }

    case Bosbase.langchaingo()
         |> Bosbase.LangChaingoService.rag(pb, request) do
      {:ok, result} ->
        %{
          "answer" => result["answer"],
          "sources" => result["sources"] || []
        }
      {:error, error} ->
        %{"error" => inspect(error)}
    end
  end
end

# Usage
pb = Client.new("http://localhost:8090")
result = RAGService.ask_question(pb, "knowledge-base", "Why is the sky blue?")

IO.puts(result["answer"])
Enum.each(result["sources"] || [], fn source ->
  IO.puts("Source: #{get_in(source, ["metadata", "title"])}")
end)
```

## Error Handling

```elixir
case Bosbase.langchaingo()
     |> Bosbase.LangChaingoService.completions(pb, request) do
  {:ok, completion} ->
    IO.puts(completion["content"])
  {:error, %{status: 401}} ->
    IO.puts("Authentication required")
  {:error, %{status: 400} = error} ->
    IO.puts("Invalid request: #{inspect(error)}")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Related Documentation

- [LLM Documents API](./LLM_DOCUMENTS.md) - Managing LLM document collections
- [Vector API](./VECTOR_API.md) - Vector database operations
- [Authentication](./AUTHENTICATION.md) - User authentication

