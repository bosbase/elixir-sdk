# Collections - Elixir SDK Documentation

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

## Collection Types

### Base Collection

Default collection type for storing any application data.

```elixir
alias Bosbase.{Client, CollectionService, RecordService}

client = Bosbase.new("http://localhost:8090")
admins = Client.collection(client, "_superusers")
{:ok, _} = RecordService.auth_with_password(admins, "admin@example.com", "password")

collections = CollectionService.new(client)
{:ok, collection} = CollectionService.create_base(collections, "articles", %{
  "fields" => [
    %{"name" => "title", "type" => "text", "required" => true},
    %{"name" => "description", "type" => "text"}
  ]
})
```

### View Collection

Read-only collection populated from a SQL SELECT statement.

```elixir
{:ok, view} = CollectionService.create_view(
  collections,
  "post_stats",
  "SELECT posts.id, posts.name, count(comments.id) as totalComments FROM posts LEFT JOIN comments on comments.postId = posts.id GROUP BY posts.id"
)
```

### Auth Collection

Base collection with authentication fields (email, password, etc.).

```elixir
{:ok, users} = CollectionService.create_auth(collections, "users", %{
  "fields" => [%{"name" => "name", "type" => "text", "required" => true}]
})
```

## Collections API

### List Collections

```elixir
{:ok, result} = CollectionService.get_list(collections, %{page: 1, per_page: 50})
{:ok, all} = CollectionService.get_full_list(collections, 200)
```

### Get Collection

```elixir
{:ok, collection} = CollectionService.get_one(collections, "articles")
```

### Create Collection

```elixir
# Using scaffolds
{:ok, base} = CollectionService.create_base(collections, "articles")
{:ok, auth} = CollectionService.create_auth(collections, "users")
{:ok, view} = CollectionService.create_view(collections, "stats", "SELECT * FROM posts")

# Manual
{:ok, collection} = CollectionService.create(collections, %{
  body: %{
    "type" => "base",
    "name" => "articles",
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true},
      # Note: created and updated fields must be explicitly added if you want to use them
      # For autodate fields, onCreate and onUpdate must be direct properties, not nested in options
      %{
        "name" => "created",
        "type" => "autodate",
        "required" => false,
        "onCreate" => true,
        "onUpdate" => false
      },
      %{
        "name" => "updated",
        "type" => "autodate",
        "required" => false,
        "onCreate" => true,
        "onUpdate" => true
      }
    ]
  }
})
```

### Update Collection

```elixir
# Update collection rules
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"listRule" => "published = true"}
})

# Update collection name
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"name" => "posts"}
})
```

### Add Fields to Collection

To add a new field to an existing collection, fetch the collection, add the field to the fields array, and update:

```elixir
# Get existing collection
{:ok, collection} = CollectionService.get_one(collections, "articles")

# Add new field to existing fields
fields = collection["fields"] ++ [%{
  "name" => "views",
  "type" => "number",
  "min" => 0,
  "onlyInt" => true
}]

# Update collection with new field
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})

# Or add multiple fields at once
new_fields = [
  %{"name" => "excerpt", "type" => "text", "max" => 500},
  %{
    "name" => "cover",
    "type" => "file",
    "maxSelect" => 1,
    "mimeTypes" => ["image/jpeg", "image/png"]
  }
]

fields = collection["fields"] ++ new_fields
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})

# Adding created and updated autodate fields to existing collection
# Note: onCreate and onUpdate must be direct properties, not nested in options
autodate_fields = [
  %{
    "name" => "created",
    "type" => "autodate",
    "required" => false,
    "onCreate" => true,
    "onUpdate" => false
  },
  %{
    "name" => "updated",
    "type" => "autodate",
    "required" => false,
    "onCreate" => true,
    "onUpdate" => true
  }
]

fields = collection["fields"] ++ autodate_fields
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})
```

### Delete Fields from Collection

To delete a field, fetch the collection, remove the field from the fields array, and update:

```elixir
# Get existing collection
{:ok, collection} = CollectionService.get_one(collections, "articles")

# Remove field by filtering it out
fields = Enum.reject(collection["fields"], fn field -> field["name"] == "oldFieldName" end)

# Update collection without the deleted field
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})

# Or remove multiple fields
fields_to_keep = ["title", "content", "author", "status"]
fields = Enum.filter(collection["fields"], fn field ->
  field["name"] in fields_to_keep || Map.get(field, "system", false)
end)

{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})
```

### Modify Fields in Collection

To modify an existing field (e.g., change its type, add options, etc.), fetch the collection, update the field object, and save:

```elixir
# Get existing collection
{:ok, collection} = CollectionService.get_one(collections, "articles")

# Find and modify a field
fields = Enum.map(collection["fields"], fn field ->
  if field["name"] == "title" do
    field
    |> Map.put("max", 200)  # Change max length
    |> Map.put("required", true)  # Make required
  else
    field
  end
end)

# Update the field type
fields = Enum.map(fields, fn field ->
  if field["name"] == "status" do
    # Note: Changing field types may require data migration
    field
    |> Map.put("type", "select")
    |> Map.put("options", %{"values" => ["draft", "published", "archived"]})
    |> Map.put("maxSelect", 1)
  else
    field
  end
end)

# Save changes
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})
```

### Complete Example: Managing Collection Fields

```elixir
alias Bosbase.{Client, CollectionService, RecordService}

client = Bosbase.new("http://localhost:8090")
admins = Client.collection(client, "_superusers")
{:ok, _} = RecordService.auth_with_password(admins, "admin@example.com", "password")

collections = CollectionService.new(client)

# Get existing collection
{:ok, collection} = CollectionService.get_one(collections, "articles")

# Add new fields
new_fields = [
  %{
    "name" => "tags",
    "type" => "select",
    "options" => %{"values" => ["tech", "design", "business"]},
    "maxSelect" => 5
  },
  %{"name" => "published_at", "type" => "date"}
]

fields = collection["fields"] ++ new_fields

# Remove an old field
fields = Enum.reject(fields, fn f -> f["name"] == "oldField" end)

# Modify existing field
fields = Enum.map(fields, fn field ->
  if field["name"] == "views" do
    Map.put(field, "max", 1_000_000)  # Increase max value
  else
    field
  end
end)

# Save all changes at once
{:ok, _} = CollectionService.update(collections, "articles", %{
  body: %{"fields" => fields}
})
```

### Delete Collection

```elixir
:ok = CollectionService.delete(collections, "articles")
```

## Records API

### List Records

```elixir
posts = Client.collection(client, "articles")
{:ok, result} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 20,
  filter: "published = true",
  sort: "-created",
  expand: "author"
})
```

### Get Record

```elixir
{:ok, record} = RecordService.get_one(posts, "RECORD_ID", %{
  expand: "author,category"
})
```

### Create Record

```elixir
{:ok, record} = RecordService.create(posts, %{
  body: %{
    "title" => "My Article",
    "views+" => 1  # Field modifier
  }
})
```

### Update Record

```elixir
{:ok, _} = RecordService.update(posts, "RECORD_ID", %{
  body: %{
    "title" => "Updated",
    "views+" => 1,
    "tags+" => "new-tag"
  }
})
```

### Delete Record

```elixir
:ok = RecordService.delete(posts, "RECORD_ID")
```

## Field Types

### BoolField

```elixir
%{"name" => "published", "type" => "bool", "required" => true}
{:ok, _} = RecordService.create(posts, %{body: %{"published" => true}})
```

### NumberField

```elixir
%{"name" => "views", "type" => "number", "min" => 0}
{:ok, _} = RecordService.update(posts, "ID", %{body: %{"views+" => 1}})
```

### TextField

```elixir
%{"name" => "title", "type" => "text", "required" => true, "min" => 6, "max" => 100}
{:ok, _} = RecordService.create(posts, %{body: %{"slug:autogenerate" => "article-"}})
```

### EmailField

```elixir
%{"name" => "email", "type" => "email", "required" => true}
```

### URLField

```elixir
%{"name" => "website", "type" => "url"}
```

### EditorField

```elixir
%{"name" => "content", "type" => "editor", "required" => true}
{:ok, _} = RecordService.create(posts, %{body: %{"content" => "<p>HTML content</p>"}})
```

### DateField

```elixir
%{"name" => "published_at", "type" => "date"}
{:ok, _} = RecordService.create(posts, %{
  body: %{"published_at" => "2024-11-10 18:45:27.123Z"}
})
```

### AutodateField

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection. For autodate fields, `onCreate` and `onUpdate` must be direct properties of the field object, not nested in an `options` object:

```elixir
# Create field with proper structure
%{
  "name" => "created",
  "type" => "autodate",
  "required" => false,
  "onCreate" => true,  # Set on record creation (direct property)
  "onUpdate" => false  # Don't update on record update (direct property)
}

# For updated field
%{
  "name" => "updated",
  "type" => "autodate",
  "required" => false,
  "onCreate" => true,  # Set on record creation (direct property)
  "onUpdate" => true   # Update on record update (direct property)
}

# The value is automatically set by the backend based on onCreate and onUpdate properties
```

### SelectField

```elixir
# Single select
%{
  "name" => "status",
  "type" => "select",
  "options" => %{"values" => ["draft", "published"]},
  "maxSelect" => 1
}
{:ok, _} = RecordService.create(posts, %{body: %{"status" => "published"}})

# Multiple select
%{
  "name" => "tags",
  "type" => "select",
  "options" => %{"values" => ["tech", "design"]},
  "maxSelect" => 5
}
{:ok, _} = RecordService.update(posts, "ID", %{body: %{"tags+" => "marketing"}})
```

### FileField

```elixir
# Single file
%{
  "name" => "cover",
  "type" => "file",
  "maxSelect" => 1,
  "mimeTypes" => ["image/jpeg"]
}
{:ok, _} = RecordService.create(posts, %{
  files: %{
    "cover" => %Bosbase.FileParam{
      content: File.read!("path/to/image.jpg"),
      filename: "image.jpg",
      content_type: "image/jpeg"
    }
  }
})
```

### RelationField

```elixir
%{
  "name" => "author",
  "type" => "relation",
  "options" => %{"collectionId" => "users"},
  "maxSelect" => 1
}
{:ok, _} = RecordService.create(posts, %{body: %{"author" => "USER_ID"}})
{:ok, record} = RecordService.get_one(posts, "ID", %{expand: "author"})
```

### JSONField

```elixir
%{"name" => "metadata", "type" => "json"}
{:ok, _} = RecordService.create(posts, %{
  body: %{"metadata" => %{"seo" => %{"title" => "SEO Title"}}}
})
```

### GeoPointField

```elixir
%{"name" => "location", "type" => "geoPoint"}
{:ok, _} = RecordService.create(places, %{
  body: %{"location" => %{"lon" => 139.6917, "lat" => 35.6586}}
})
```

## Complete Example

```elixir
alias Bosbase.{Client, CollectionService, RecordService}

client = Bosbase.new("http://localhost:8090")
admins = Client.collection(client, "_superusers")
{:ok, _} = RecordService.auth_with_password(admins, "admin@example.com", "password")

collections = CollectionService.new(client)

# Create collections
{:ok, users} = CollectionService.create_auth(collections, "users")
{:ok, articles} = CollectionService.create_base(collections, "articles", %{
  "fields" => [
    %{"name" => "title", "type" => "text", "required" => true},
    %{
      "name" => "author",
      "type" => "relation",
      "options" => %{"collectionId" => users["id"]},
      "maxSelect" => 1
    }
  ]
})

# Create and authenticate user
users_collection = Client.collection(client, "users")
{:ok, user} = RecordService.create(users_collection, %{
  body: %{
    "email" => "user@example.com",
    "password" => "password123",
    "passwordConfirm" => "password123"
  }
})
{:ok, _} = RecordService.auth_with_password(users_collection, "user@example.com", "password123")

# Create article
articles_collection = Client.collection(client, "articles")
{:ok, article} = RecordService.create(articles_collection, %{
  body: %{
    "title" => "My Article",
    "author" => user["id"]
  }
})

# Subscribe to changes
RecordService.subscribe(articles_collection, "*", fn e ->
  IO.inspect(e["action"])
  IO.inspect(e["record"])
end)
```

