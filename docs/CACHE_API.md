# Cache API - Elixir SDK Documentation

BosBase caches combine in-memory [FreeCache](https://github.com/coocood/freecache) storage with persistent database copies. Each cache instance is safe to use in single-node or multi-node (cluster) mode: nodes read from FreeCache first, fall back to the database if an item is missing or expired, and then reload FreeCache automatically.

The Elixir SDK exposes the cache endpoints through `Bosbase.caches()`. Typical use cases include:

- Caching AI prompts/responses that must survive restarts.
- Quickly sharing feature flags and configuration between workers.
- Preloading expensive vector search results for short periods.

> **Timeouts & TTLs:** Each cache defines a default TTL (in seconds). Individual entries may provide their own `ttlSeconds`. A value of `0` keeps the entry until it is manually deleted.

## List available caches

The `list/3` function allows you to query and retrieve all currently available caches, including their names and capacities. This is particularly useful for AI systems to discover existing caches before creating new ones, avoiding duplicate cache creation.

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("root@example.com", "hunter2")

# Query all available caches
{:ok, caches} = Bosbase.caches()
  |> Bosbase.CacheService.list(pb)

# Each cache map contains:
# - "name": string - The cache identifier
# - "sizeBytes": number - The cache capacity in bytes
# - "defaultTTLSeconds": number - Default expiration time
# - "readTimeoutMs": number - Read timeout in milliseconds
# - "created": string - Creation timestamp (RFC3339)
# - "updated": string - Last update timestamp (RFC3339)

# Example: Find a cache by name and check its capacity
target_cache = Enum.find(caches, fn c -> c["name"] == "ai-session" end)

if target_cache do
  IO.puts("Cache \"#{target_cache["name"]}\" has capacity of #{target_cache["sizeBytes"]} bytes")
  # Use the existing cache directly
else
  IO.puts("Cache not found, create a new one if needed")
end
```

## Manage cache configurations

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("root@example.com", "hunter2")

# List all available caches (including name and capacity).
# This is useful for AI to discover existing caches before creating new ones.
{:ok, caches} = Bosbase.caches()
  |> Bosbase.CacheService.list(pb)

IO.inspect(caches, label: "Available caches")
# Output example:
# [
#   %{
#     "name" => "ai-session",
#     "sizeBytes" => 67_108_864,
#     "defaultTTLSeconds" => 300,
#     "readTimeoutMs" => 25,
#     "created" => "2024-01-15T10:30:00Z",
#     "updated" => "2024-01-15T10:30:00Z"
#   },
#   %{
#     "name" => "query-cache",
#     "sizeBytes" => 33_554_432,
#     "defaultTTLSeconds" => 600,
#     "readTimeoutMs" => 50,
#     "created" => "2024-01-14T08:00:00Z",
#     "updated" => "2024-01-14T08:00:00Z"
#   }
# ]

# Find an existing cache by name
existing_cache = Enum.find(caches, fn c -> c["name"] == "ai-session" end)

if existing_cache do
  IO.puts("Found cache \"#{existing_cache["name"]}\" with capacity #{existing_cache["sizeBytes"]} bytes")
  # Use the existing cache directly without creating a new one
else
  # Create a new cache only if it doesn't exist
  {:ok, _cache} = Bosbase.caches()
    |> Bosbase.CacheService.create(pb, "ai-session", 64 * 1024 * 1024, 300, 25)
end

# Update limits later (eg. shrink TTL to 2 minutes).
{:ok, _updated} = Bosbase.caches()
  |> Bosbase.CacheService.update(pb, "ai-session", %{"defaultTTLSeconds" => 120})

# Delete the cache (DB rows + FreeCache).
:ok = Bosbase.caches()
  |> Bosbase.CacheService.delete(pb, "ai-session")
```

Field reference:

| Field | Description |
|-------|-------------|
| `sizeBytes` | Approximate FreeCache size. Values too small (<512KB) or too large (>512MB) are clamped. |
| `defaultTTLSeconds` | Default expiration for entries. `0` means no expiration. |
| `readTimeoutMs` | Optional lock timeout while reading FreeCache. When exceeded, the value is fetched from the database instead. |

## Work with cache entries

```elixir
# Store an object in cache. The same payload is serialized into the DB.
{:ok, _} = Bosbase.caches()
  |> Bosbase.CacheService.set_entry(
    pb,
    "ai-session",
    "dialog:42",
    %{
      "prompt" => "describe Saturn",
      "embedding" => [/* vector */]
    },
    90  # per-entry TTL in seconds
  )

# Read from cache. `source` indicates where the hit came from.
{:ok, entry} = Bosbase.caches()
  |> Bosbase.CacheService.get_entry(pb, "ai-session", "dialog:42")

IO.inspect(entry["source"])   # "cache" or "database"
IO.inspect(entry["expiresAt"]) # RFC3339 timestamp or nil

# Renew an entry's TTL without changing its value.
# This extends the expiration time by the specified TTL (or uses the cache's default TTL if omitted).
{:ok, renewed} = Bosbase.caches()
  |> Bosbase.CacheService.renew_entry(pb, "ai-session", "dialog:42", 120)  # extend by 120 seconds

IO.inspect(renewed["expiresAt"]) # new expiration time

# Delete an entry.
:ok = Bosbase.caches()
  |> Bosbase.CacheService.delete_entry(pb, "ai-session", "dialog:42")
```

### Cluster-aware behaviour

1. **Write-through persistence** – every `set_entry` writes to FreeCache and the `_cache_entries` table so other nodes (or a restarted node) can immediately reload values.
2. **Read path** – FreeCache is consulted first. If a lock cannot be acquired within `readTimeoutMs` or if the entry is missing/expired, BosBase queries the database copy and repopulates FreeCache in the background.
3. **Automatic cleanup** – expired entries are ignored and removed from the database when fetched, preventing stale data across nodes.

Use caches whenever you need fast, transient data that must still be recoverable or shareable across BosBase nodes.

