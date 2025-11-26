# Collections - Elixir SDK Documentation

This document provides comprehensive documentation for working with Collections and Fields in the BosBase Elixir SDK. This documentation is designed to be AI-readable and includes practical examples for all operations.

## Table of Contents

- [Overview](#overview)
- [Collection Types](#collection-types)
- [Collections API](#collections-api)
- [Records API](#records-api)
- [Field Types](#field-types)
- [Examples](#examples)

## Overview

**Collections** represent your application data. Under the hood they are backed by plain SQLite tables that are generated automatically with the collection **name** and **fields** (columns).

A single entry of a collection is called a **record** (a single row in the SQL table).

You can manage your **collections** from the Dashboard, or with the Elixir SDK using the `collections` service.

Similarly, you can manage your **records** from the Dashboard, or with the Elixir SDK using the `collection(name)` method which returns a `RecordService` instance.

## Collection Types

Currently there are 3 collection types: **Base**, **View** and **Auth**.

### Base Collection

**Base collection** is the default collection type and it could be used to store any application data (articles, products, posts, etc.).

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Create a base collection
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "articles", %{
    "fields" => [
      %{
        "name" => "title",
        "type" => "text",
        "required" => true,
        "min" => 6,
        "max" => 100
      },
      %{
        "name" => "description",
        "type" => "text"
      }
    ],
    "listRule" => ~s(@request.auth.id != '' || status = 'public'),
    "viewRule" => ~s(@request.auth.id != '' || status = 'public')
  })
```

### View Collection

**View collection** is a read-only collection type where the data is populated from a plain SQL `SELECT` statement, allowing users to perform aggregations or any other custom queries.

For example, the following query will create a read-only collection with 3 _posts_ fields - _id_, _name_ and _totalComments_:

```elixir
# Create a view collection
{:ok, view_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_view(pb, "post_stats", 
    "SELECT posts.id, posts.name, count(comments.id) as totalComments 
     FROM posts 
     LEFT JOIN comments on comments.postId = posts.id 
     GROUP BY posts.id")
```

**Note**: View collections don't receive realtime events because they don't have create/update/delete operations.

### Auth Collection

**Auth collection** has everything from the **Base collection** but with some additional special fields to help you manage your app users and also provide various authentication options.

Each Auth collection has the following special system fields: `email`, `emailVisibility`, `verified`, `password` and `tokenKey`. They cannot be renamed or deleted but can be configured using their specific field options.

```elixir
# Create an auth collection
{:ok, users_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_auth(pb, "users", %{
    "fields" => [
      %{
        "name" => "name",
        "type" => "text",
        "required" => true
      },
      %{
        "name" => "role",
        "type" => "select",
        "options" => %{
          "values" => ["employee", "staff", "admin"]
        }
      }
    ]
  })
```

You can have as many Auth collections as you want (users, managers, staffs, members, clients, etc.) each with their own set of fields, separate login and records managing endpoints.

## Collections API

### Initialize Client

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Authenticate as superuser (required for collection management)
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

### List Collections

```elixir
# Get paginated list
{:ok, result} = Bosbase.collections()
  |> Bosbase.CollectionService.get_list(pb, 1, 50)

# Get all collections
{:ok, all_collections} = Bosbase.collections()
  |> Bosbase.CollectionService.get_full_list(pb, false)
```

### Get Collection

```elixir
# By ID or name
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "articles")
# or
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "COLLECTION_ID")
```

### Create Collection

#### Using Scaffolds (Recommended)

```elixir
# Create base collection
{:ok, base} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "articles", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true}
    ]
  })

# Create auth collection
{:ok, auth} = Bosbase.collections()
  |> Bosbase.CollectionService.create_auth(pb, "users", %{})

# Create view collection
{:ok, view} = Bosbase.collections()
  |> Bosbase.CollectionService.create_view(pb, "stats", 
    "SELECT id, name FROM posts")
```

### Update Collection

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "articles", %{
    "listRule" => ~s(@request.auth.id != '' || published = true && status = 'public')
  })
```

### Delete Collection

```elixir
# Warning: This will delete the collection and all its records
:ok = Bosbase.collections()
  |> Bosbase.CollectionService.delete(pb, "articles")
```

### Truncate Collection

Deletes all records but keeps the collection structure:

```elixir
:ok = Bosbase.collections()
  |> Bosbase.CollectionService.truncate(pb, "articles")
```

## Field Types

All collection fields (with exception of the `JSONField`) are **non-nullable and use a zero-default** for their respective type as fallback value when missing (empty string for `text`, 0 for `number`, etc.).

### BoolField

Stores a single `false` (default) or `true` value.

```elixir
# Create field
%{
  "name" => "published",
  "type" => "bool",
  "required" => true
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{"published" => true})
```

### NumberField

Stores numeric/float64 value: `0` (default), `2`, `-1`, `1.5`.

**Available modifiers:**
- `fieldName+` - adds number to the existing record value
- `fieldName-` - subtracts number from the existing record value

```elixir
# Create field
%{
  "name" => "views",
  "type" => "number",
  "min" => 0,
  "max" => 1_000_000,
  "onlyInt" => false  # Allow decimals
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{"views" => 0})

# Increment
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"views+" => 1})

# Decrement
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"views-" => 5})
```

### TextField

Stores string values: `""` (default), `"example"`.

```elixir
# Create field
%{
  "name" => "title",
  "type" => "text",
  "required" => true,
  "min" => 6,
  "max" => 100,
  "pattern" => "^[A-Z]"  # Must start with uppercase
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{"title" => "My Article"})
```

### EmailField

Stores a single email string address: `""` (default), `"john@example.com"`.

```elixir
# Create field
%{
  "name" => "email",
  "type" => "email",
  "required" => true
}

# Usage
{:ok, record} = Client.collection(pb, "users")
  |> Bosbase.RecordService.create(%{"email" => "user@example.com"})
```

### URLField

Stores a single URL string value: `""` (default), `"https://example.com"`.

```elixir
# Create field
%{
  "name" => "website",
  "type" => "url",
  "required" => false
}

# Usage
{:ok, record} = Client.collection(pb, "users")
  |> Bosbase.RecordService.create(%{"website" => "https://example.com"})
```

### EditorField

Stores HTML formatted text: `""` (default), `<p>example</p>`.

```elixir
# Create field
%{
  "name" => "content",
  "type" => "editor",
  "required" => true,
  "maxSize" => 10_485_760  # 10MB
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "content" => "<p>This is HTML content</p><p>With multiple paragraphs</p>"
  })
```

### DateField

Stores a single datetime string value: `""` (default), `"2022-01-01 00:00:00.000Z"`.

All BosBase dates follow the RFC3339 format `Y-m-d H:i:s.uZ` (e.g. `2024-11-10 18:45:27.123Z`).

```elixir
# Create field
%{
  "name" => "published_at",
  "type" => "date",
  "required" => false
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "published_at" => "2024-11-10 18:45:27.123Z"
  })

# Filter by date
{:ok, records} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(created >= '2024-11-19 00:00:00.000Z' && created <= '2024-11-19 23:59:59.999Z')
  })
```

### AutodateField

Similar to DateField but its value is auto set on record create/update. Usually used for timestamp fields like "created" and "updated".

**Important Note:** Bosbase does not initialize `created` and `updated` fields by default. To use these fields, you must explicitly add them when initializing the collection with the proper options:

```elixir
# Create field with proper options
%{
  "name" => "created",
  "type" => "autodate",
  "required" => false,
  "options" => %{
    "onCreate" => true,  # Set on record creation
    "onUpdate" => false  # Don't update on record update
  }
}

# For updated field
%{
  "name" => "updated",
  "type" => "autodate",
  "required" => false,
  "options" => %{
    "onCreate" => true,  # Set on record creation
    "onUpdate" => true   # Update on record update
  }
}

# The value is automatically set by the backend based on the options
```

### SelectField

Stores single or multiple string values from a predefined list.

For **single** `select` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"optionA"`.

For **multiple** `select` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["optionA", "optionB"]`.

**Available modifiers:**
- `fieldName+` - appends one or more values
- `+fieldName` - prepends one or more values
- `fieldName-` - subtracts/removes one or more values

```elixir
# Single select
%{
  "name" => "status",
  "type" => "select",
  "options" => %{
    "values" => ["draft", "published", "archived"]
  },
  "maxSelect" => 1
}

# Multiple select
%{
  "name" => "tags",
  "type" => "select",
  "options" => %{
    "values" => ["tech", "design", "business", "marketing"]
  },
  "maxSelect" => 5
}

# Usage - Single
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{"status" => "published"})

# Usage - Multiple
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{"tags" => ["tech", "design"]})

# Modify - Append
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"tags+" => "marketing"})

# Modify - Remove
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"tags-" => "tech"})
```

### FileField

Manages record file(s). BosBase stores in the database only the file name. The file itself is stored either on the local disk or in S3.

For **single** `file` (the `MaxSelect` option is <= 1) the stored value is a string: `""`, `"file1_Ab24ZjL.png"`.

For **multiple** `file` (the `MaxSelect` option is >= 2) the stored value is an array: `[]`, `["file1_Ab24ZjL.png", "file2_Frq24ZjL.txt"]`.

**Available modifiers:**
- `fieldName+` - appends one or more files
- `+fieldName` - prepends one or more files
- `fieldName-` - deletes one or more files

```elixir
# Single file
%{
  "name" => "cover",
  "type" => "file",
  "maxSelect" => 1,
  "maxSize" => 5_242_880,  # 5MB
  "mimeTypes" => ["image/jpeg", "image/png"]
}

# Multiple files
%{
  "name" => "documents",
  "type" => "file",
  "maxSelect" => 10,
  "maxSize" => 10_485_760,  # 10MB
  "mimeTypes" => ["application/pdf", "application/docx"]
}

# Note: File uploads in Elixir typically require multipart form data
# See FILES.md for detailed file upload examples
```

### RelationField

Stores single or multiple collection record references.

For **single** `relation` (the `MaxSelect` option is <= 1) the field value is a string: `""`, `"RECORD_ID"`.

For **multiple** `relation` (the `MaxSelect` option is >= 2) the field value is an array: `[]`, `["RECORD_ID1", "RECORD_ID2"]`.

**Available modifiers:**
- `fieldName+` - appends one or more ids
- `+fieldName` - prepends one or more ids
- `fieldName-` - subtracts/removes one or more ids

```elixir
# Single relation
%{
  "name" => "author",
  "type" => "relation",
  "options" => %{
    "collectionId" => "users",
    "cascadeDelete" => false
  },
  "maxSelect" => 1
}

# Multiple relation
%{
  "name" => "categories",
  "type" => "relation",
  "options" => %{
    "collectionId" => "categories"
  },
  "maxSelect" => 5
}

# Usage - Single
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "title" => "My Article",
    "author" => "USER_RECORD_ID"
  })

# Usage - Multiple
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "title" => "My Article",
    "categories" => ["CAT_ID1", "CAT_ID2"]
  })

# Modify - Add relation
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"categories+" => "CAT_ID3"})

# Modify - Remove relation
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update("RECORD_ID", %{"categories-" => "CAT_ID1"})

# Expand relations when fetching
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_one("RECORD_ID", %{
    "expand" => "author,categories"
  })
# record["expand"]["author"] - full author record
# record["expand"]["categories"] - array of category records
```

### JSONField

Stores any serialized JSON value, including `null` (default). This is the only nullable field type.

```elixir
# Create field
%{
  "name" => "metadata",
  "type" => "json",
  "required" => false
}

# Usage
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "title" => "My Article",
    "metadata" => %{
      "seo" => %{
        "title" => "SEO Title",
        "description" => "SEO Description"
      },
      "custom" => %{
        "tags" => ["tag1", "tag2"],
        "priority" => 10
      }
    }
  })

# Can also store arrays
{:ok, record} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "title" => "My Article",
    "metadata" => [1, 2, 3, %{"nested" => "object"}]
  })
```

### GeoPointField

Stores geographic coordinates (longitude, latitude) as a serialized json object.

The default/zero value of a `geoPoint` is the "Null Island", aka. `{"lon":0,"lat":0}`.

```elixir
# Create field
%{
  "name" => "location",
  "type" => "geoPoint",
  "required" => false
}

# Usage
{:ok, record} = Client.collection(pb, "places")
  |> Bosbase.RecordService.create(%{
    "name" => "Tokyo Tower",
    "location" => %{
      "lon" => 139.6917,
      "lat" => 35.6586
    }
  })
```

## Related Documentation

- [Collections](./COLLECTIONS.md) - Main collections documentation
- [API Records](./API_RECORDS.md) - Working with records
- [Relations](./RELATIONS.md) - Working with relations
- [Files](./FILES.md) - File uploads and handling

