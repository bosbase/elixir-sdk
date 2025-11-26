# Schema Query API - Elixir SDK Documentation

## Overview

The Schema Query API provides lightweight interfaces to retrieve collection field information without fetching full collection definitions. This is particularly useful for AI systems that need to understand the structure of collections and the overall system architecture.

**Key Features:**
- Get schema for a single collection by name or ID
- Get schemas for all collections in the system
- Lightweight response with only essential field information
- Support for all collection types (base, auth, view)
- Fast and efficient queries

**Backend Endpoints:**
- `GET /api/collections/{collection}/schema` - Get single collection schema
- `GET /api/collections/schemas` - Get all collection schemas

**Note**: All Schema Query API operations require superuser authentication.

## Authentication

All Schema Query API operations require superuser authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

## Type Definitions

### CollectionFieldSchemaInfo

Simplified field information returned by schema queries:

```elixir
%{
  "name" => "string",        # Field name
  "type" => "string",        # Field type (e.g., "text", "number", "email", "relation")
  "required" => true,        # Whether the field is required (optional)
  "system" => false,         # Whether the field is a system field (optional)
  "hidden" => false          # Whether the field is hidden (optional)
}
```

### CollectionSchemaInfo

Schema information for a single collection:

```elixir
%{
  "name" => "string",                        # Collection name
  "type" => "string",                        # Collection type ("base", "auth", "view")
  "fields" => [%{...}, ...]                   # List of field information maps
}
```

## Get Single Collection Schema

Retrieves the schema (fields and types) for a single collection by name or ID.

### Basic Usage

```elixir
# Get schema for a collection by name
{:ok, schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "demo1")

IO.inspect(schema["name"])    # "demo1"
IO.inspect(schema["type"])    # "base"
IO.inspect(schema["fields"])  # List of field information

# Iterate through fields
Enum.each(schema["fields"], fn field ->
  required = if field["required"], do: " (required)", else: ""
  IO.puts("#{field["name"]}: #{field["type"]}#{required}")
end)
```

### Using Collection ID

```elixir
# Get schema for a collection by ID
{:ok, schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "_pbc_base_123")

IO.inspect(schema["name"])  # "demo1"
```

### Handling Different Collection Types

```elixir
# Base collection
{:ok, base_schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "demo1")
IO.inspect(base_schema["type"])  # "base"

# Auth collection
{:ok, auth_schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "users")
IO.inspect(auth_schema["type"])  # "auth"

# View collection
{:ok, view_schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "view1")
IO.inspect(view_schema["type"])  # "view"
```

### Error Handling

```elixir
case Bosbase.collections()
     |> Bosbase.CollectionService.get_schema(pb, "nonexistent") do
  {:ok, schema} ->
    IO.inspect(schema)
  {:error, %{status: 404}} ->
    IO.puts("Collection not found")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Get All Collection Schemas

Retrieves the schema (fields and types) for all collections in the system.

### Basic Usage

```elixir
# Get schemas for all collections
# Note: This endpoint may need to be called directly via client.send
# as it might not be wrapped in CollectionService yet

# For now, you can get all collections and then get their schemas
{:ok, collections} = Bosbase.collections()
  |> Bosbase.CollectionService.get_full_list(pb, false)

# Get schema for each collection
schemas = Enum.map(collections, fn collection ->
  case Bosbase.collections()
       |> Bosbase.CollectionService.get_schema(pb, collection["name"]) do
    {:ok, schema} -> schema
    {:error, _} -> nil
  end
end)
|> Enum.reject(&is_nil/1)

# Iterate through all collections
Enum.each(schemas, fn schema ->
  IO.puts("Collection: #{schema["name"]} (#{schema["type"]})")
  IO.puts("Fields: #{length(schema["fields"])}")
  
  # List all fields
  Enum.each(schema["fields"], fn field ->
    IO.puts("  - #{field["name"]}: #{field["type"]}")
  end)
end)
```

### Filtering Collections by Type

```elixir
# Filter to only base collections
base_collections = Enum.filter(schemas, fn s -> s["type"] == "base" end)

# Filter to only auth collections
auth_collections = Enum.filter(schemas, fn s -> s["type"] == "auth" end)

# Filter to only view collections
view_collections = Enum.filter(schemas, fn s -> s["type"] == "view" end)
```

### Building a Field Index

```elixir
# Build a map of all field names and types across all collections
field_index = Enum.reduce(schemas, %{}, fn schema, acc ->
  Enum.reduce(schema["fields"], acc, fn field, field_acc ->
    key = "#{schema["name"]}.#{field["name"]}"
    Map.put(field_acc, key, %{
      "collection" => schema["name"],
      "collectionType" => schema["type"],
      "fieldName" => field["name"],
      "fieldType" => field["type"],
      "required" => field["required"] || false,
      "system" => field["system"] || false,
      "hidden" => field["hidden"] || false
    })
  end)
end)

# Use the index
IO.inspect(field_index["demo1.title"])  # Field information
```

## Complete Examples

### Example 1: AI System Understanding Collection Structure

```elixir
defmodule SchemaAnalyzer do
  def get_system_overview(pb) do
    # Get all collections
    {:ok, collections} = Bosbase.collections()
      |> Bosbase.CollectionService.get_full_list(pb, false)
    
    # Get schema for each collection
    schemas = Enum.map(collections, fn collection ->
      case Bosbase.collections()
           |> Bosbase.CollectionService.get_schema(pb, collection["name"]) do
        {:ok, schema} -> schema
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    # Create comprehensive system overview
    Enum.map(schemas, fn schema ->
      %{
        "name" => schema["name"],
        "type" => schema["type"],
        "fields" => Enum.map(schema["fields"], fn field ->
          %{
            "name" => field["name"],
            "type" => field["type"],
            "required" => field["required"] || false
          }
        end)
      }
    end)
  end
end

# Usage
overview = SchemaAnalyzer.get_system_overview(pb)

Enum.each(overview, fn collection ->
  IO.puts("\n#{collection["name"]} (#{collection["type"]}):")
  Enum.each(collection["fields"], fn field ->
    required = if field["required"], do: " [required]", else: ""
    IO.puts("  #{field["name"]}: #{field["type"]}#{required}")
  end)
end)
```

### Example 2: Validating Field Existence Before Query

```elixir
def check_field_exists(pb, collection_name, field_name) do
  case Bosbase.collections()
       |> Bosbase.CollectionService.get_schema(pb, collection_name) do
    {:ok, schema} ->
      Enum.any?(schema["fields"], fn field -> field["name"] == field_name end)
    {:error, _} ->
      false
  end
end

# Usage
has_title_field = check_field_exists(pb, "demo1", "title")

if has_title_field do
  # Safe to query the field
  {:ok, records} = Client.collection(pb, "demo1")
    |> Bosbase.RecordService.get_list(%{
      fields: "id,title"
    })
end
```

### Example 3: Dynamic Form Generation

```elixir
def generate_form_fields(pb, collection_name) do
  case Bosbase.collections()
       |> Bosbase.CollectionService.get_schema(pb, collection_name) do
    {:ok, schema} ->
      schema["fields"]
      |> Enum.reject(fn field -> 
        field["system"] || field["hidden"]
      end)
      |> Enum.map(fn field ->
        %{
          "name" => field["name"],
          "type" => field["type"],
          "required" => field["required"] || false,
          "label" => field["name"]
            |> String.capitalize()
        }
      end)
    {:error, _} ->
      []
  end
end

# Usage
form_fields = generate_form_fields(pb, "demo1")
IO.inspect(form_fields)
# [
#   %{"name" => "title", "type" => "text", "required" => true, "label" => "Title"},
#   %{"name" => "description", "type" => "text", "required" => false, "label" => "Description"},
#   ...
# ]
```

## Response Structure

### Single Collection Schema Response

```json
{
  "name": "demo1",
  "type": "base",
  "fields": [
    {
      "name": "id",
      "type": "text",
      "required": true,
      "system": true,
      "hidden": false
    },
    {
      "name": "title",
      "type": "text",
      "required": true,
      "system": false,
      "hidden": false
    },
    {
      "name": "description",
      "type": "text",
      "required": false,
      "system": false,
      "hidden": false
    }
  ]
}
```

## Use Cases

### 1. AI System Design
AI systems can query all collection schemas to understand the overall database structure and design queries or operations accordingly.

### 2. Code Generation
Generate client-side code, types, or form components based on collection schemas.

### 3. Documentation Generation
Automatically generate API documentation or data dictionaries from collection schemas.

### 4. Schema Validation
Validate queries or operations before execution by checking field existence and types.

### 5. Migration Planning
Compare schemas between environments or versions to plan migrations.

### 6. Dynamic UI Generation
Create dynamic forms, tables, or interfaces based on collection field definitions.

## Performance Considerations

- **Lightweight**: Schema queries return only essential field information, not full collection definitions
- **Efficient**: Much faster than fetching full collection objects
- **Cached**: Results can be cached for better performance
- **Batch**: Use `get_full_list` then `get_schema` for each to get all schemas

## Error Handling

```elixir
case Bosbase.collections()
     |> Bosbase.CollectionService.get_schema(pb, "demo1") do
  {:ok, schema} ->
    IO.inspect(schema)
  {:error, %{status: 401}} ->
    IO.puts("Authentication required")
  {:error, %{status: 403}} ->
    IO.puts("Superuser access required")
  {:error, %{status: 404}} ->
    IO.puts("Collection not found")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Cache Results**: Schema information rarely changes, so cache results when appropriate
2. **Error Handling**: Always handle 404 errors for non-existent collections
3. **Filter System Fields**: When building UI, filter out system and hidden fields
4. **Batch Queries**: Get all collections first, then get schemas for each
5. **Type Safety**: Use pattern matching for better type safety

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Full collection management API
- [Records API](./API_RECORDS.md) - Record CRUD operations

