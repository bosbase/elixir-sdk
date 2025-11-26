# Collection API - Elixir SDK Documentation

## Overview

The Collection API provides endpoints for managing collections (Base, Auth, and View types). All operations require superuser authentication and allow you to create, read, update, and delete collections along with their schemas and configurations.

**Key Features:**
- List and search collections
- View collection details
- Create collections (base, auth, view)
- Update collection schemas and rules
- Delete collections
- Truncate collections (delete all records)
- Import collections in bulk
- Get collection scaffolds (templates)

**Backend Endpoints:**
- `GET /api/collections` - List collections
- `GET /api/collections/{collection}` - View collection
- `POST /api/collections` - Create collection
- `PATCH /api/collections/{collection}` - Update collection
- `DELETE /api/collections/{collection}` - Delete collection
- `DELETE /api/collections/{collection}/truncate` - Truncate collection
- `PUT /api/collections/import` - Import collections
- `GET /api/collections/meta/scaffolds` - Get scaffolds

**Note**: All Collection API operations require superuser authentication.

## Authentication

All Collection API operations require superuser authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

## List Collections

Returns a paginated list of collections with support for filtering and sorting.

```elixir
# Basic list
{:ok, result} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(%{page: 1, perPage: 30})

IO.inspect(result["page"])        # 1
IO.inspect(result["perPage"])     # 30
IO.inspect(result["totalItems"])  # Total collections count
IO.inspect(result["items"])       # List of collections
```

### Advanced Filtering and Sorting

```elixir
# Filter by type
{:ok, auth_collections} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(%{
    page: 1,
    perPage: 100,
    filter: ~s(type = "auth")
  })

# Filter by name pattern
{:ok, matching} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(%{
    page: 1,
    perPage: 100,
    filter: ~s(name ~ "user")
  })

# Sort by creation date
{:ok, sorted} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(%{
    page: 1,
    perPage: 100,
    sort: "-created"
  })

# Complex filter
{:ok, filtered} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(%{
    page: 1,
    perPage: 100,
    filter: ~s(type = "base" && system = false && created >= "2023-01-01"),
    sort: "name"
  })
```

### Get Full List

```elixir
# Get all collections at once
{:ok, all_collections} = Bosbase.collections()
  |> Bosbase.CollectionService.get_full_list(false, %{
    sort: "name",
    filter: ~s(system = false)
  })
```

### Get First Matching Collection

```elixir
# Get first auth collection
{:ok, auth_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_first_list_item(~s(type = "auth"))
```

## View Collection

Retrieve a single collection by ID or name:

```elixir
# By name
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one("posts")

# By ID
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one("_pbc_2287844090")

# With field selection
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one("posts", %{
    fields: "id,name,type,fields.name,fields.type"
  })
```

## Create Collection

Create a new collection with schema fields and configuration.

**Note**: If the `created` and `updated` fields are not specified during collection initialization, BosBase will automatically create them. These system fields are added to all collections by default and track when records are created and last modified. You don't need to include them in your field definitions.

### Create Base Collection

```elixir
base_collection = %{
  "name" => "posts",
  "type" => "base",
  "fields" => [
    %{
      "name" => "title",
      "type" => "text",
      "required" => true,
      "min" => 10,
      "max" => 255
    },
    %{
      "name" => "content",
      "type" => "editor",
      "required" => false
    },
    %{
      "name" => "published",
      "type" => "bool",
      "required" => false
    },
    %{
      "name" => "author",
      "type" => "relation",
      "required" => true,
      "collectionId" => "_pbc_users_auth_",
      "maxSelect" => 1
    }
  ],
  "listRule" => "@request.auth.id != \"\"",
  "viewRule" => "@request.auth.id != \"\" || published = true",
  "createRule" => "@request.auth.id != \"\"",
  "updateRule" => "author = @request.auth.id",
  "deleteRule" => "author = @request.auth.id"
}

{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{body: base_collection})
```

### Create Auth Collection

```elixir
auth_collection = %{
  "name" => "users",
  "type" => "auth",
  "fields" => [
    %{
      "name" => "name",
      "type" => "text",
      "required" => false
    },
    %{
      "name" => "avatar",
      "type" => "file",
      "required" => false,
      "maxSelect" => 1,
      "maxSize" => 2_097_152,
      "mimeTypes" => ["image/jpeg", "image/png"]
    }
  ],
  "listRule" => nil,
  "viewRule" => "@request.auth.id = id",
  "createRule" => nil,
  "updateRule" => "@request.auth.id = id",
  "deleteRule" => "@request.auth.id = id",
  "manageRule" => nil,
  "authRule" => "verified = true",
  "passwordAuth" => %{
    "enabled" => true,
    "identityFields" => ["email", "username"]
  },
  "authToken" => %{
    "duration" => 604_800
  }
}

{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{body: auth_collection})
```

### Create View Collection

```elixir
view_collection = %{
  "name" => "published_posts",
  "type" => "view",
  "listRule" => "@request.auth.id != \"\"",
  "viewRule" => "@request.auth.id != \"\"",
  "viewQuery" => """
    SELECT 
      p.id,
      p.title,
      p.content,
      p.created,
      u.name as author_name,
      u.email as author_email
    FROM posts p
    LEFT JOIN users u ON p.author = u.id
    WHERE p.published = true
  """
}

{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{body: view_collection})
```

### Create from Scaffold

Use predefined scaffolds as a starting point:

```elixir
# Get available scaffolds
{:ok, scaffolds} = Bosbase.collections()
  |> Bosbase.CollectionService.get_scaffolds()

# Create base collection from scaffold
{:ok, base_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base("my_posts", %{
    "fields" => [
      %{
        "name" => "title",
        "type" => "text",
        "required" => true
      }
    ]
  })

# Create auth collection from scaffold
{:ok, auth_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_auth("my_users", %{
    "passwordAuth" => %{
      "enabled" => true,
      "identityFields" => ["email"]
    }
  })

# Create view collection from scaffold
{:ok, view_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_view("my_view", "SELECT id, title FROM posts", %{
    "listRule" => "@request.auth.id != \"\""
  })
```

### Accessing Collection ID After Creation

When a collection is successfully created, the returned map includes the `"id"` key, which contains the unique identifier assigned by the backend. You can access it immediately after creation:

```elixir
# Create a collection and access its ID
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{
    body: %{
      "name" => "posts",
      "type" => "base",
      "fields" => [
        %{
          "name" => "title",
          "type" => "text",
          "required" => true
        }
      ]
    }
  })

# Access the collection ID
IO.inspect(collection["id"]) # e.g., "_pbc_2287844090"

# Use the ID for subsequent operations
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(collection["id"], %{
    body: %{"listRule" => "@request.auth.id != \"\""}
  })
```

## Update Collection

Update an existing collection's schema, fields, or rules:

```elixir
# Update collection name and rules
{:ok, updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update("posts", %{
    body: %{
      "name" => "articles",
      "listRule" => "@request.auth.id != \"\" || status = \"public\"",
      "viewRule" => "@request.auth.id != \"\" || status = \"public\""
    }
  })

# Add new field
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one("posts")

updated_fields = collection["fields"] ++ [
  %{
    "name" => "tags",
    "type" => "select",
    "options" => %{
      "values" => ["tech", "science", "art"]
    }
  }
]

{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update("posts", %{
    body: Map.put(collection, "fields", updated_fields)
  })
```

## Manage Indexes

BosBase stores collection indexes as SQL expressions on the `indexes` property of a collection. The Elixir SDK provides dedicated helpers so you don't have to manually craft the SQL or resend the full collection payload every time you want to adjust an index.

### Add or Update Indexes

```elixir
# Create a unique slug index (index names are optional)
{:ok, _collection} = Bosbase.collections()
  |> Bosbase.CollectionService.add_index("posts", ["slug"], true, "idx_posts_slug_unique")

# Composite (non-unique) index; defaults to idx_{collection}_{columns}
{:ok, _collection} = Bosbase.collections()
  |> Bosbase.CollectionService.add_index("posts", ["status", "published"])
```

- `collection` can be either the collection name or internal id.
- `columns` must reference existing columns (system fields such as `id`, `created`, and `updated` are allowed).
- `unique` (default `false`) controls whether `CREATE UNIQUE INDEX` or `CREATE INDEX` is generated.
- `index_name` is optional; omit it to let the SDK generate `idx_{collection}_{column1}_{column2}` automatically.

Calling `add_index` twice with the same name replaces the definition on the backend, making it easy to iterate on your schema.

### Remove Indexes

```elixir
# Remove the index that targets the slug column
{:ok, _collection} = Bosbase.collections()
  |> Bosbase.CollectionService.remove_index("posts", ["slug"])
```

`remove_index` looks for indexes that contain all of the provided columns (in any order) and drops them from the collection. This deletes the actual database index when the collection is saved.

### List Indexes

```elixir
{:ok, indexes} = Bosbase.collections()
  |> Bosbase.CollectionService.get_indexes("posts")

Enum.each(indexes, fn idx -> IO.puts(idx) end)
# => CREATE UNIQUE INDEX `idx_posts_slug_unique` ON `posts` (`slug`)
```

`get_indexes` returns the raw SQL strings stored on the collection so you can audit existing indexes or decide whether you need to create new ones.

## Delete Collection

Delete a collection (including all records and files):

```elixir
# Delete by name
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.delete("old_collection")

# Delete by ID
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.delete("_pbc_2287844090")

# Using deleteCollection method (alias)
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.delete_collection("old_collection")
```

**Warning**: This operation is destructive and will:
- Delete the collection schema
- Delete all records in the collection
- Delete all associated files
- Remove all indexes

**Note**: Collections referenced by other collections cannot be deleted.

## Truncate Collection

Delete all records in a collection while keeping the collection schema:

```elixir
# Truncate collection (delete all records)
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.truncate("posts")
```

**Warning**: This operation is destructive and cannot be undone. It's useful for:
- Clearing test data
- Resetting collections
- Bulk data removal

**Note**: View collections cannot be truncated.

## Import Collections

Bulk import multiple collections at once:

```elixir
collections_to_import = [
  %{
    "name" => "posts",
    "type" => "base",
    "fields" => [
      %{
        "name" => "title",
        "type" => "text",
        "required" => true
      },
      %{
        "name" => "content",
        "type" => "editor"
      }
    ],
    "listRule" => "@request.auth.id != \"\""
  },
  %{
    "name" => "categories",
    "type" => "base",
    "fields" => [
      %{
        "name" => "name",
        "type" => "text",
        "required" => true
      }
    ]
  }
]

# Import without deleting existing collections
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.import_collections(collections_to_import, false)

# Import and delete collections not in the import list
{:ok, _} = Bosbase.collections()
  |> Bosbase.CollectionService.import_collections(collections_to_import, true)
```

### Import Options

- **`delete_missing: false`** (default): Only create/update collections in the import list
- **`delete_missing: true`**: Delete all collections not present in the import list

**Warning**: Using `delete_missing: true` will permanently delete collections and all their data.

## Get Scaffolds

Get collection templates for creating new collections:

```elixir
{:ok, scaffolds} = Bosbase.collections()
  |> Bosbase.CollectionService.get_scaffolds()

# Available scaffold types
IO.inspect(scaffolds["base"])   # Base collection template
IO.inspect(scaffolds["auth"])   # Auth collection template
IO.inspect(scaffolds["view"])   # View collection template

# Use scaffold as starting point
base_template = scaffolds["base"]
new_collection = base_template
  |> Map.put("name", "my_collection")
  |> Map.put("fields", (base_template["fields"] || []) ++ [
    %{
      "name" => "custom_field",
      "type" => "text"
    }
  ])

{:ok, _collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{body: new_collection})
```

## Filter Syntax

Collections support filtering with the same syntax as records:

### Supported Fields

- `id` - Collection ID
- `created` - Creation date
- `updated` - Last update date
- `name` - Collection name
- `type` - Collection type (`base`, `auth`, `view`)
- `system` - System collection flag (boolean)

### Filter Examples

```elixir
# Filter by type
filter: ~s(type = "auth")

# Filter by name pattern
filter: ~s(name ~ "user")

# Filter non-system collections
filter: ~s(system = false)

# Multiple conditions
filter: ~s(type = "base" && system = false && created >= "2023-01-01")

# Complex filter
filter: ~s((type = "auth" || type = "base") && name !~ "test")
```

## Sort Options

Supported sort fields:

- `@random` - Random order
- `id` - Collection ID
- `created` - Creation date
- `updated` - Last update date
- `name` - Collection name
- `type` - Collection type
- `system` - System flag

```elixir
# Sort examples
sort: "name"           # ASC by name
sort: "-created"       # DESC by creation date
sort: "type,-created"  # ASC by type, then DESC by created
```

## Complete Examples

### Example 1: Setup Blog Collections

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Create posts collection
{:ok, posts} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{
    body: %{
      "name" => "posts",
      "type" => "base",
      "fields" => [
        %{
          "name" => "title",
          "type" => "text",
          "required" => true,
          "min" => 10,
          "max" => 255
        },
        %{
          "name" => "slug",
          "type" => "text",
          "required" => true,
          "options" => %{
            "pattern" => "^[a-z0-9-]+$"
          }
        },
        %{
          "name" => "content",
          "type" => "editor",
          "required" => true
        },
        %{
          "name" => "featured_image",
          "type" => "file",
          "maxSelect" => 1,
          "maxSize" => 5_242_880,
          "mimeTypes" => ["image/jpeg", "image/png"]
        },
        %{
          "name" => "published",
          "type" => "bool",
          "required" => false
        },
        %{
          "name" => "author",
          "type" => "relation",
          "collectionId" => "_pbc_users_auth_",
          "maxSelect" => 1
        },
        %{
          "name" => "categories",
          "type" => "relation",
          "collectionId" => "categories",
          "maxSelect" => 5
        }
      ],
      "listRule" => "@request.auth.id != \"\" || published = true",
      "viewRule" => "@request.auth.id != \"\" || published = true",
      "createRule" => "@request.auth.id != \"\"",
      "updateRule" => "author = @request.auth.id",
      "deleteRule" => "author = @request.auth.id"
    }
  })

# Create categories collection
{:ok, categories} = Bosbase.collections()
  |> Bosbase.CollectionService.create(%{
    body: %{
      "name" => "categories",
      "type" => "base",
      "fields" => [
        %{
          "name" => "name",
          "type" => "text",
          "required" => true,
          "unique" => true
        },
        %{
          "name" => "slug",
          "type" => "text",
          "required" => true
        },
        %{
          "name" => "description",
          "type" => "text",
          "required" => false
        }
      ],
      "listRule" => "@request.auth.id != \"\"",
      "viewRule" => "@request.auth.id != \"\""
    }
  })

# Access collection IDs immediately after creation
IO.puts("Posts collection ID: #{posts["id"]}")
IO.puts("Categories collection ID: #{categories["id"]}")
```

## Error Handling

```elixir
case Bosbase.collections()
  |> Bosbase.CollectionService.create(%{
    body: %{
      "name" => "test",
      "type" => "base",
      "fields" => []
    }
  }) do
  {:ok, collection} ->
    IO.puts("Collection created: #{collection["id"]}")
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, %{status: 403}} ->
    IO.puts("Not a superuser")
  {:error, %{status: 400} = error} ->
    IO.puts("Validation error: #{inspect(error)}")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Always Authenticate**: Ensure you're authenticated as a superuser before making requests
2. **Backup Before Import**: Always backup existing collections before using `import_collections` with `delete_missing: true`
3. **Validate Schema**: Validate collection schemas before creating/updating
4. **Use Scaffolds**: Use scaffolds as starting points for consistency
5. **Test Rules**: Test API rules thoroughly before deploying to production
6. **Index Important Fields**: Add indexes for frequently queried fields
7. **Document Schemas**: Keep documentation of your collection schemas
8. **Version Control**: Store collection schemas in version control for migration tracking

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **System Collections**: System collections cannot be deleted or renamed
- **View Collections**: Cannot be truncated (they don't store records)
- **Relations**: Collections referenced by others cannot be deleted
- **Field Modifications**: Some field type changes may require data migration

## Related Documentation

- [Collections Guide](./COLLECTIONS.md) - Working with collections and records
- [API Records](./API_RECORDS.md) - Record CRUD operations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules

