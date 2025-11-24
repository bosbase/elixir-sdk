# BosBase Elixir SDK

Elixir client that mirrors the JavaScript SDK surface: collections and records, auth flows, realtime subscriptions, pub/sub websockets, batch requests, files, vectors, LangChaingo, LLM documents, cache, cron, backups, GraphQL, settings, logs, and health endpoints.

## Installation

Add the dependency to your `mix.exs`:

```elixir
def deps do
  [
    {:bosbase, "~> 0.1.0"}
  ]
end
```

The application starts a shared Finch pool and Task Supervisor via `Bosbase.Application`.

## Quick start

```elixir
alias Bosbase.{CollectionService, RecordService}

client = Bosbase.new("http://127.0.0.1:8090")

# authenticate against an auth collection
{:ok, auth} =
  RecordService.new(client, "users")
  |> RecordService.auth_with_password("test@example.com", "123456")

# list records
{:ok, page} =
  RecordService.new(client, "example")
  |> RecordService.get_list(%{page: 1, per_page: 10})

# upload a file to a record
file = %Bosbase.FileParam{filename: "avatar.png", content: File.read!("avatar.png"), content_type: "image/png"}
{:ok, created} =
  RecordService.new(client, "profiles")
  |> RecordService.create(%{body: %{"name" => "demo"}, files: %{"avatar" => file}})
```

## Services overview

- `Bosbase.RecordService` – CRUD helpers, auth flows (password, OAuth2 code, OTP, refresh), impersonation, realtime subscriptions.
- `Bosbase.CollectionService` – manage collections, scaffolds, indexes, truncate/import, schema.
- `Bosbase.BatchService` – transactional batch create/update/upsert/delete payloads.
- `Bosbase.FileService` – file URLs and token retrieval.
- `Bosbase.SettingsService`, `HealthService`, `LogService`, `BackupService`, `CronService`.
- `Bosbase.VectorService` – vector collections, search/insert/update/delete.
- `Bosbase.LLMDocumentService` – semantic document store helpers.
- `Bosbase.LangChaingoService` – completions, RAG, SQL helpers.
- `Bosbase.CacheService` – named caches and entries.
- `Bosbase.GraphQLService` – single-call GraphQL query helper.
- `Bosbase.RealtimeService` – SSE subscriptions (server events).
- `Bosbase.PubSubService` – WebSocket pub/sub publish + subscribe.

Each helper takes a `Bosbase.Client` (from `Bosbase.new/2`) as the first argument.

## Hooks and headers

`Bosbase.Client` supports `:before_send` and `:after_send` options to mutate requests or responses. The client automatically injects `Accept-Language`, `User-Agent`, and `Authorization` headers (when the auth store has a valid token).

## Testing locally

```bash
cd elixir-sdk
mix test
```

The test suite only checks client helpers; API calls require a running BosBase backend.
