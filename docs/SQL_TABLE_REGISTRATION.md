# Register Existing SQL Tables with the Elixir SDK

Use the SQL table helpers to expose existing tables (or run SQL to create them) and automatically generate REST collections. Both calls are **superuser-only**.

- `register_sql_tables(tables)` – map existing tables to collections without running SQL.
- `import_sql_tables(tables)` – optionally run SQL to create tables first, then register them. Returns `%{"created" => [...], "skipped" => [...]}`.

## Requirements

- Authenticate with a `_superusers` token.
- Each table must contain a `TEXT` primary key column named `id`.
- Missing audit columns (`created`, `updated`, `createdBy`, `updatedBy`) are automatically added so the default API rules can be applied.
- Non-system columns are mapped by best effort (text, number, bool, date/time, JSON).

## Basic Usage

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Register existing tables
# Note: This functionality may need to be implemented via direct client.send calls
# as it might not be wrapped in CollectionService yet

# For now, you can use the client directly:
{:ok, collections} = pb
  |> Client.send("/api/collections/register-sql-tables", %{
    method: :post,
    body: %{
      "tables" => ["projects", "accounts"]
    }
  })

IO.inspect(Enum.map(collections, fn c -> c["name"] end))
# => ["projects", "accounts"]
```

## With Request Options

You can pass standard request options (headers, query params, etc.).

```elixir
{:ok, collections} = pb
  |> Client.send("/api/collections/register-sql-tables", %{
    method: :post,
    body: %{
      "tables" => ["legacy_orders"]
    },
    headers: %{"x-trace-id" => "reg-123"},
    query: %{"q" => 1}
  })
```

## Create-or-register flow

`import_sql_tables()` accepts table definitions with optional SQL, runs the SQL (if provided), and registers collections. Existing collection names are reported under `skipped`.

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

{:ok, result} = pb
  |> Client.send("/api/collections/import-sql-tables", %{
    method: :post,
    body: %{
      "tables" => [
        %{
          "name" => "legacy_orders",
          "sql" => """
            CREATE TABLE IF NOT EXISTS legacy_orders (
              id TEXT PRIMARY KEY,
              customer_email TEXT NOT NULL
            );
          """
        },
        %{
          "name" => "reporting_view"
          # Assumes table already exists
        }
      ]
    }
  })

IO.inspect(Enum.map(result["created"], fn c -> c["name"] end))
# => ["legacy_orders", "reporting_view"]

IO.inspect(result["skipped"])
# => collection names that already existed
```

## What It Does

- Creates BosBase collection metadata for the provided tables.
- Generates REST endpoints for CRUD against those tables.
- Applies the standard default API rules (authenticated create; update/delete scoped to the creator).
- Ensures audit columns exist (`created`, `updated`, `createdBy`, `updatedBy`) and leaves all other existing SQL schema and data untouched; no further field mutations or table syncs are performed.
- Marks created collections with `externalTable: true` so you can distinguish them from regular BosBase-managed tables.

## Troubleshooting

- 400 error: ensure `id` exists as `TEXT PRIMARY KEY` and the table name is not system-reserved (no leading `_`).
- 401/403: confirm you are authenticated as a superuser.
- Default audit fields (`created`, `updated`, `createdBy`, `updatedBy`) are auto-added if they're missing so the default owner rules validate successfully.

## Complete Example

```elixir
defmodule SQLTableImporter do
  def register_existing_tables(pb, table_names) do
    pb
    |> Client.send("/api/collections/register-sql-tables", %{
      method: :post,
      body: %{
        "tables" => table_names
      }
    })
  end

  def import_with_sql(pb, table_definitions) do
    pb
    |> Client.send("/api/collections/import-sql-tables", %{
      method: :post,
      body: %{
        "tables" => table_definitions
      }
    })
  end
end

# Usage
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Register existing tables
{:ok, collections} = SQLTableImporter.register_existing_tables(pb, ["projects", "accounts"])

# Import with SQL
{:ok, result} = SQLTableImporter.import_with_sql(pb, [
  %{
    "name" => "legacy_orders",
    "sql" => """
      CREATE TABLE IF NOT EXISTS legacy_orders (
        id TEXT PRIMARY KEY,
        customer_email TEXT NOT NULL,
        order_date TEXT,
        total REAL
      );
    """
  }
])
```

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management
- [API Rules](./API_RULES_AND_FILTERS.md) - Understanding API rules

