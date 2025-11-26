# AI Development Guide - Elixir SDK Documentation

This guide provides a comprehensive, fast reference for AI systems to quickly develop applications using the BosBase Elixir SDK. All examples are production-ready and follow best practices.

## Table of Contents

1. [Authentication](#authentication)
2. [Initialize Collections](#initialize-collections)
3. [Define Collection Fields](#define-collection-fields)
4. [Add Data to Collections](#add-data-to-collections)
5. [Modify Collection Data](#modify-collection-data)
6. [Delete Data from Collections](#delete-data-from-collections)
7. [Query Collection Contents](#query-collection-contents)
8. [Add and Delete Fields from Collections](#add-and-delete-fields-from-collections)
9. [Query Collection Field Information](#query-collection-field-information)
10. [Upload Files](#upload-files)
11. [Query Logs](#query-logs)
12. [Send Emails](#send-emails)

---

## Authentication

### Initialize Client

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")
```

### Password Authentication

```elixir
# Authenticate with email/username and password
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password123")

# Auth data is automatically stored
store = pb.auth_store
IO.puts("Valid: #{Bosbase.AuthStore.valid?(store)}")  # true
IO.puts("Token: #{Bosbase.AuthStore.token(store)}")    # JWT token
IO.inspect(Bosbase.AuthStore.record(store))           # User record
```

### OAuth2 Authentication

```elixir
# Get OAuth2 providers
{:ok, methods} = Client.collection(pb, "users")
  |> Bosbase.RecordService.list_auth_methods()

IO.inspect(methods["oauth2"]["providers"])  # Available providers

# Authenticate with OAuth2
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_oauth2(%{
    "provider" => "google"
  })
```

### OTP Authentication

```elixir
# Request OTP
{:ok, otp_response} = Client.collection(pb, "users")
  |> Bosbase.RecordService.request_verification("user@example.com")

# Authenticate with OTP
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_otp(otp_response["otpId"], "123456")  # OTP code
```

### Check Authentication Status

```elixir
store = pb.auth_store
if Bosbase.AuthStore.valid?(store) do
  user = Bosbase.AuthStore.record(store)
  IO.puts("Authenticated as: #{user["email"]}")
else
  IO.puts("Not authenticated")
end
```

### Logout

```elixir
Bosbase.AuthStore.clear(pb.auth_store)
```

---

## Initialize Collections

### Create Base Collection

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "posts", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true}
    ]
  })

IO.puts("Collection ID: #{collection["id"]}")
```

### Create Auth Collection

```elixir
{:ok, auth_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_auth(pb, "users", %{
    "fields" => [
      %{"name" => "name", "type" => "text", "required" => false}
    ],
    "passwordAuth" => %{
      "enabled" => true,
      "identityFields" => ["email", "username"]
    }
  })
```

### Create View Collection

```elixir
{:ok, view_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_view(pb, "published_posts", 
    "SELECT * FROM posts WHERE published = true")
```

### Get Collection by ID or Name

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "posts")
# or by ID
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "_pbc_2287844090")
```

---

## Define Collection Fields

### Add Field to Collection

```elixir
{:ok, updated_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.add_field(pb, "posts", %{
    "name" => "content",
    "type" => "editor",
    "required" => false
  })
```

### Common Field Types

```elixir
# Text field
%{
  "name" => "title",
  "type" => "text",
  "required" => true,
  "min" => 10,
  "max" => 255
}

# Number field
%{
  "name" => "views",
  "type" => "number",
  "required" => false,
  "min" => 0
}

# Boolean field
%{
  "name" => "published",
  "type" => "bool",
  "required" => false
}

# Date field
%{
  "name" => "published_at",
  "type" => "date",
  "required" => false
}

# File field
%{
  "name" => "avatar",
  "type" => "file",
  "required" => false,
  "maxSelect" => 1,
  "maxSize" => 2_097_152,  # 2MB
  "mimeTypes" => ["image/jpeg", "image/png"]
}

# Relation field
%{
  "name" => "author",
  "type" => "relation",
  "required" => true,
  "collectionId" => "_pbc_users_auth_",
  "maxSelect" => 1
}

# Select field
%{
  "name" => "status",
  "type" => "select",
  "required" => true,
  "options" => %{
    "values" => ["draft", "published", "archived"]
  }
}
```

### Update Field

```elixir
{:ok, updated_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.update_field(pb, "posts", "title", %{
    "max" => 500,
    "required" => true
  })
```

### Remove Field

```elixir
{:ok, updated_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.remove_field(pb, "posts", "old_field")
```

---

## Add Data to Collections

### Create Single Record

```elixir
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "My First Post",
    "content" => "This is the content",
    "published" => true
  })

IO.puts("Created record ID: #{record["id"]}")
```

### Create Record with Relations

```elixir
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "My Post",
    "author" => "user_record_id",  # Related record ID
    "categories" => ["cat1_id", "cat2_id"]  # Multiple relations
  })
```

### Batch Create Records

```elixir
{:ok, results} = Bosbase.create_batch(pb, [
  %{
    "method" => "POST",
    "url" => "/api/collections/posts/records",
    "body" => %{"title" => "Post 1"}
  },
  %{
    "method" => "POST",
    "url" => "/api/collections/posts/records",
    "body" => %{"title" => "Post 2"}
  }
])
```

---

## Modify Collection Data

### Update Single Record

```elixir
{:ok, updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("record_id", %{
    "title" => "Updated Title",
    "content" => "Updated content"
  })
```

### Partial Update

```elixir
# Only update specific fields
{:ok, updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("record_id", %{
    "views" => 100  # Only update views
  })
```

---

## Delete Data from Collections

### Delete Single Record

```elixir
:ok = Client.collection(pb, "posts")
  |> Bosbase.RecordService.delete("record_id")
```

### Delete Multiple Records

```elixir
# Using batch
{:ok, _results} = Bosbase.create_batch(pb, [
  %{
    "method" => "DELETE",
    "url" => "/api/collections/posts/records/record_id_1"
  },
  %{
    "method" => "DELETE",
    "url" => "/api/collections/posts/records/record_id_2"
  }
])
```

### Delete All Records (Truncate)

```elixir
:ok = Bosbase.collections()
  |> Bosbase.CollectionService.truncate(pb, "posts")
```

---

## Query Collection Contents

### List Records with Pagination

```elixir
{:ok, result} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 50)

IO.puts(result["page"])        # 1
IO.puts(result["perPage"])     # 50
IO.puts(result["totalItems"])  # Total count
IO.inspect(result["items"])    # List of records
```

### Filter Records

```elixir
{:ok, result} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 50, %{
    "filter" => ~s(published = true && views > 100),
    "sort" => "-created"
  })
```

### Filter Operators

```elixir
# Equality
filter: ~s(status = "published")

# Comparison
filter: ~s(views > 100)
filter: ~s(created >= "2023-01-01")

# Text search
filter: ~s(title ~ "javascript")

# Multiple conditions
filter: ~s(status = "published" && views > 100)
filter: ~s(status = "draft" || status = "pending")

# Relation filter
filter: ~s(author.id = "user_id")
```

### Sort Records

```elixir
# Single field
sort: "-created"  # DESC
sort: "title"     # ASC

# Multiple fields
sort: "-created,title"  # DESC by created, then ASC by title
```

### Expand Relations

```elixir
{:ok, result} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 50, %{
    "expand" => "author,categories"
  })

# Access expanded data
Enum.each(result["items"], fn post ->
  IO.puts(post["expand"]["author"]["name"])
  IO.inspect(post["expand"]["categories"])
end)
```

### Get Single Record

```elixir
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("record_id", %{
    "expand" => "author"
  })
```

### Get First Matching Record

```elixir
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_first_list_item(
    ~s(slug = "my-post-slug"),
    %{"expand" => "author"}
  )
```

### Get All Records

```elixir
{:ok, all_records} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_full_list(%{
    "filter" => ~s(published = true),
    "sort" => "-created"
  })
```

---

## Add and Delete Fields from Collections

### Add Field

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.add_field(pb, "posts", %{
    "name" => "tags",
    "type" => "select",
    "options" => %{
      "values" => ["tech", "science", "art"]
    }
  })
```

### Update Field

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.update_field(pb, "posts", "tags", %{
    "options" => %{
      "values" => ["tech", "science", "art", "music"]
    }
  })
```

### Remove Field

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.remove_field(pb, "posts", "old_field")
```

### Get Field Information

```elixir
{:ok, field} = Bosbase.collections()
  |> Bosbase.CollectionService.get_field(pb, "posts", "title")

IO.puts("#{field["type"]}, #{field["required"]}, #{inspect(field["options"])}")
```

---

## Query Collection Field Information

### Get All Fields for a Collection

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "posts")

Enum.each(collection["fields"], fn field ->
  IO.puts("#{field["name"]} #{field["type"]} #{field["required"]}")
end)
```

### Get Collection Schema (Simplified)

```elixir
{:ok, schema} = Bosbase.collections()
  |> Bosbase.CollectionService.get_schema(pb, "posts")

IO.inspect(schema["fields"])  # List of field info
```

### Get All Collection Schemas

```elixir
# Get all collections first
{:ok, collections} = Bosbase.collections()
  |> Bosbase.CollectionService.get_full_list(pb, false)

# Get schema for each
schemas = Enum.map(collections, fn collection ->
  case Bosbase.collections()
       |> Bosbase.CollectionService.get_schema(pb, collection["name"]) do
    {:ok, schema} -> schema
    {:error, _} -> nil
  end
end)
|> Enum.reject(&is_nil/1)

Enum.each(schemas, fn schema ->
  IO.puts("#{schema["name"]} #{inspect(schema["fields"])}")
end)
```

---

## Upload Files

### Upload File with Record Creation

```elixir
# Note: File uploads in Elixir typically require multipart form data
# This is a conceptual example - actual implementation depends on your HTTP client

# For multipart uploads, you would typically:
# 1. Create a multipart form with the file
# 2. Send it via the client's send method

# Example with HTTPoison (conceptual):
# {:ok, file_content} = File.read("/path/to/image.jpg")
# 
# body = Multipart.new()
#   |> Multipart.add_field("title", "Post Title")
#   |> Multipart.add_file("image", file_content, filename: "image.jpg")
#
# {:ok, record} = Client.collection(pb, "posts")
#   |> Bosbase.RecordService.create(body)
```

### Get File URL

```elixir
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("record_id")

file_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"])
```

---

## Query Logs

### List Logs

```elixir
{:ok, logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50)

IO.inspect(logs["items"])  # List of log entries
```

### Filter Logs

```elixir
{:ok, logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, %{
    "filter" => ~s(level >= 400),  # Error level and above
    "sort" => "-created"
  })
```

### Get Single Log

```elixir
{:ok, log} = Bosbase.logs()
  |> Bosbase.LogService.get_one(pb, "log_id")

IO.puts("#{log["message"]} #{inspect(log["data"])}")
```

### Get Log Statistics

```elixir
{:ok, stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb, %{
    "filter" => ~s(level >= 400)
  })

Enum.each(stats, fn stat ->
  IO.puts("#{stat["date"]} #{stat["total"]}")
end)
```

### Log Levels

- `0` - Debug
- `1` - Info
- `2` - Warning
- `3` - Error
- `4` - Fatal

---

## Send Emails

**Note**: Email sending is typically handled server-side via hooks or backend code. The SDK doesn't provide direct email sending methods, but you can trigger email-related operations.

### Trigger Email Verification

```elixir
# Request verification email
:ok = Client.collection(pb, "users")
  |> Bosbase.RecordService.request_verification("user@example.com")
```

### Trigger Password Reset Email

```elixir
# Request password reset email
:ok = Client.collection(pb, "users")
  |> Bosbase.RecordService.request_password_reset("user@example.com")
```

### Email Change Request

```elixir
# Request email change
:ok = Client.collection(pb, "users")
  |> Bosbase.RecordService.request_email_change("newemail@example.com")
```

### Server-Side Email Sending

Email sending is configured in the backend settings and triggered automatically by:
- User registration (verification email)
- Password reset requests
- Email change requests
- Custom hooks

To send custom emails, you would typically:
1. Create a backend hook that uses `app.NewMailClient()`
2. Or use the admin API to configure email templates
3. Or trigger email-related record operations that automatically send emails

---

## Complete Example: Full Application Flow

```elixir
defmodule AppSetup do
  def setup(pb) do
    # 1. Authenticate
    {:ok, _auth} = Client.collection(pb, "users")
      |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
    
    # 2. Create collection
    {:ok, collection} = Bosbase.collections()
      |> Bosbase.CollectionService.create_base(pb, "posts", %{
        "fields" => [
          %{"name" => "title", "type" => "text", "required" => true},
          %{"name" => "content", "type" => "editor"},
          %{"name" => "published", "type" => "bool"}
        ]
      })
    
    # 3. Add more fields
    {:ok, _updated} = Bosbase.collections()
      |> Bosbase.CollectionService.add_field(pb, "posts", %{
        "name" => "views",
        "type" => "number",
        "min" => 0
      })
    
    # 4. Create records
    {:ok, post} = Client.collection(pb, "posts")
      |> Bosbase.RecordService.create(%{
        "title" => "Hello World",
        "content" => "My first post",
        "published" => true,
        "views" => 0
      })
    
    # 5. Query records
    {:ok, posts} = Client.collection(pb, "posts")
      |> Bosbase.RecordService.get_list(1, 10, %{
        "filter" => ~s(published = true),
        "sort" => "-created"
      })
    
    # 6. Update record
    {:ok, _updated} = Client.collection(pb, "posts")
      |> Bosbase.RecordService.update(post["id"], %{
        "views" => 100
      })
    
    # 7. Query logs
    {:ok, logs} = Bosbase.logs()
      |> Bosbase.LogService.get_list(pb, 1, 20, %{
        "filter" => ~s(level >= 400)
      })
    
    IO.puts("Application setup complete!")
  end
end

# Usage
pb = Client.new("http://localhost:8090")
AppSetup.setup(pb)
```

---

## Quick Reference

### Common Patterns

```elixir
# Check if authenticated
store = pb.auth_store
if Bosbase.AuthStore.valid?(store) do
  # ... authenticated code
end

# Get current user
store = pb.auth_store
user = Bosbase.AuthStore.record(store)

# Refresh auth token
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_refresh()

# Error handling
case Client.collection(pb, "posts")
     |> Bosbase.RecordService.create(%{"title" => "Test"}) do
  {:ok, record} ->
    IO.puts("Created: #{record["id"]}")
  {:error, %{status: 400}} ->
    IO.puts("Validation error")
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

### Field Types Reference

- `text` - Text input
- `number` - Numeric value
- `bool` - Boolean
- `email` - Email address
- `url` - URL
- `date` - Date
- `select` - Single select
- `json` - JSON data
- `file` - File upload
- `relation` - Relation to another collection
- `editor` - Rich text editor

---

## Best Practices

1. **Always handle errors**: Wrap API calls in case statements
2. **Check authentication**: Verify `Bosbase.AuthStore.valid?` before operations
3. **Use pagination**: Don't fetch all records at once for large collections
4. **Validate data**: Ensure required fields are provided
5. **Use filters**: Filter data on the server, not client-side
6. **Expand relations wisely**: Only expand what you need
7. **Handle file uploads**: Use multipart form data for file fields
8. **Refresh tokens**: Use `auth_refresh()` to maintain sessions

---

## LangChaingo Recipes

### Quick Completion

```elixir
{:ok, result} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.completions(pb, %{
    "model" => %{"provider" => "openai", "model" => "gpt-4o-mini"},
    "messages" => [
      %{"role" => "system", "content" => "Answer with one concise line."},
      %{"role" => "user", "content" => "Give me a fun fact about Mars."}
    ],
    "temperature" => 0.4
  })

IO.puts(result["content"])
```

### Retrieval-Augmented Answering

```elixir
{:ok, rag} = Bosbase.langchaingo()
  |> Bosbase.LangChaingoService.rag(pb, %{
    "collection" => "knowledge-base",
    "question" => "Why is the sky blue?",
    "topK" => 3,
    "returnSources" => true
  })

IO.puts(rag["answer"])
IO.inspect(rag["sources"])
```

---

This guide provides all essential operations for building applications with the BosBase Elixir SDK. For more detailed information, refer to the specific API documentation files.

