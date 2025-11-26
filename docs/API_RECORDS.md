# API Records - Elixir SDK Documentation

## Overview

The Records API provides comprehensive CRUD (Create, Read, Update, Delete) operations for collection records, along with powerful search, filtering, and authentication capabilities.

**Key Features:**
- Paginated list and search with filtering and sorting
- Single record retrieval with expand support
- Create, update, and delete operations
- Batch operations for multiple records
- Authentication methods (password, OAuth2, OTP)
- Email verification and password reset
- Relation expansion up to 6 levels deep
- Field selection and excerpt modifiers

**Backend Endpoints:**
- `GET /api/collections/{collection}/records` - List records
- `GET /api/collections/{collection}/records/{id}` - View record
- `POST /api/collections/{collection}/records` - Create record
- `PATCH /api/collections/{collection}/records/{id}` - Update record
- `DELETE /api/collections/{collection}/records/{id}` - Delete record
- `POST /api/batch` - Batch operations

## CRUD Operations

### List/Search Records

Returns a paginated records list with support for sorting, filtering, and expansion.

```elixir
alias Bosbase.{Client, RecordService}

client = Bosbase.new("http://127.0.0.1:8090")
posts = Client.collection(client, "posts")

# Basic list with pagination
{:ok, result} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 50
})

IO.inspect(result["page"])        # 1
IO.inspect(result["perPage"])     # 50
IO.inspect(result["totalItems"])  # 150
IO.inspect(result["totalPages"])  # 3
IO.inspect(result["items"])       # List of records
```

#### Advanced List with Filtering and Sorting

```elixir
# Filter and sort
{:ok, result} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 50,
  filter: ~s(created >= "2022-01-01 00:00:00" && status = "published"),
  sort: "-created,title",  # DESC by created, ASC by title
  expand: "author,categories"
})

# Filter with operators
{:ok, result2} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 50,
  filter: ~s(title ~ "elixir" && views > 100),
  sort: "-views"
})
```

#### Get Full List

Fetch all records at once (useful for small collections):

```elixir
# Get all records
{:ok, all_posts} = RecordService.get_full_list(posts, 200, %{
  sort: "-created",
  filter: ~s(status = "published")
})
```

#### Get First Matching Record

Get only the first record that matches a filter:

```elixir
{:ok, post} = RecordService.get_first_list_item(posts, ~s(slug = "my-post-slug"), %{
  expand: "author,categories.tags"
})
```

### View Record

Retrieve a single record by ID:

```elixir
# Basic retrieval
{:ok, record} = RecordService.get_one(posts, "RECORD_ID")

# With expanded relations
{:ok, record} = RecordService.get_one(posts, "RECORD_ID", %{
  expand: "author,categories,tags"
})

# Nested expand
comments = Client.collection(client, "comments")
{:ok, record} = RecordService.get_one(comments, "COMMENT_ID", %{
  expand: "post.author,user"
})

# Field selection
{:ok, record} = RecordService.get_one(posts, "RECORD_ID", %{
  fields: "id,title,content,author.name"
})
```

### Create Record

Create a new record:

```elixir
# Simple create
{:ok, record} = RecordService.create(posts, %{
  body: %{
    "title" => "My First Post",
    "content" => "Lorem ipsum...",
    "status" => "draft"
  }
})

# Create with relations
{:ok, record} = RecordService.create(posts, %{
  body: %{
    "title" => "My Post",
    "author" => "AUTHOR_ID",           # Single relation
    "categories" => ["cat1", "cat2"]   # Multiple relation
  }
})

# Create with file upload
{:ok, record} = RecordService.create(posts, %{
  body: %{
    "title" => "My Post"
  },
  files: %{
    "image" => %Bosbase.FileParam{
      content: File.read!("path/to/image.jpg"),
      filename: "image.jpg",
      content_type: "image/jpeg"
    }
  }
})

# Create with expand to get related data immediately
{:ok, record} = RecordService.create(posts, %{
  body: %{
    "title" => "My Post",
    "author" => "AUTHOR_ID"
  },
  expand: "author"
})
```

### Update Record

Update an existing record:

```elixir
# Simple update
{:ok, record} = RecordService.update(posts, "RECORD_ID", %{
  body: %{
    "title" => "Updated Title",
    "status" => "published"
  }
})

# Update with relations
{:ok, _} = RecordService.update(posts, "RECORD_ID", %{
  body: %{
    "categories+" => "NEW_CATEGORY_ID",  # Append
    "tags-" => "OLD_TAG_ID"              # Remove
  }
})

# Update with file upload
{:ok, record} = RecordService.update(posts, "RECORD_ID", %{
  body: %{
    "title" => "Updated Title"
  },
  files: %{
    "image" => %Bosbase.FileParam{
      content: File.read!("path/to/new_image.jpg"),
      filename: "new_image.jpg",
      content_type: "image/jpeg"
    }
  }
})

# Update with expand
{:ok, record} = RecordService.update(posts, "RECORD_ID", %{
  body: %{
    "title" => "Updated"
  },
  expand: "author,categories"
})
```

### Delete Record

Delete a record:

```elixir
# Simple delete
:ok = RecordService.delete(posts, "RECORD_ID")

# Note: Returns :ok on success
# Returns {:error, error} if record doesn't exist or permission denied
```

## Filter Syntax

The filter parameter supports a powerful query syntax:

### Comparison Operators

```elixir
# Equal
filter: ~s(status = "published")

# Not equal
filter: ~s(status != "draft")

# Greater than / Less than
filter: ~s(views > 100)
filter: ~s(created < "2023-01-01")

# Greater/Less than or equal
filter: ~s(age >= 18)
filter: ~s(price <= 99.99)
```

### String Operators

```elixir
# Contains (like)
filter: ~s(title ~ "elixir")
# Equivalent to: title LIKE "%elixir%"

# Not contains
filter: ~s(title !~ "deprecated")

# Exact match (case-sensitive)
filter: ~s(email = "user@example.com")
```

### Array Operators (for multiple relations/files)

```elixir
# Any of / At least one
filter: ~s(tags.id ?= "TAG_ID")         # Any tag matches
filter: ~s(tags.name ?~ "important")     # Any tag name contains "important"

# All must match
filter: ~s(tags.id = "TAG_ID" && tags.id = "TAG_ID2")
```

### Logical Operators

```elixir
# AND
filter: ~s(status = "published" && views > 100)

# OR
filter: ~s(status = "published" || status = "featured")

# Parentheses for grouping
filter: ~s((status = "published" || featured = true) && views > 50)
```

## Sorting

Sort records using the `sort` parameter:

```elixir
# Single field (ASC)
sort: "created"

# Single field (DESC)
sort: "-created"

# Multiple fields
sort: "-created,title"  # DESC by created, then ASC by title

# Supported fields
sort: "@random"         # Random order
sort: "@rowid"          # Internal row ID
sort: "id"              # Record ID
sort: "fieldName"       # Any collection field

# Relation field sorting
sort: "author.name"     # Sort by related author's name
```

## Field Selection

Control which fields are returned:

```elixir
# Specific fields
fields: "id,title,content"

# All fields at level
fields: "*"

# Nested field selection
fields: "*,author.name,author.email"

# Excerpt modifier for text fields
fields: "*,content:excerpt(200,true)"
# Returns first 200 characters with ellipsis if truncated

# Combined
fields: "*,content:excerpt(200),author.name,author.email"
```

## Expanding Relations

Expand related records without additional API calls:

```elixir
# Single relation
expand: "author"

# Multiple relations
expand: "author,categories,tags"

# Nested relations (up to 6 levels)
expand: "author.profile,categories.tags"

# Back-relations
expand: "comments_via_post.user"
```

See [Relations Documentation](./RELATIONS.md) for detailed information.

## Pagination Options

```elixir
# Skip total count (faster queries)
{:ok, result} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 50,
  skip_total: true,  # totalItems and totalPages will be -1
  filter: ~s(status = "published")
})

# Get Full List with batch processing
{:ok, all_posts} = RecordService.get_full_list(posts, 200, %{
  sort: "-created"
})
# Processes in batches of 200 to avoid memory issues
```

## Batch Operations

Execute multiple operations in a single transaction:

```elixir
# Create a batch
batch = Client.create_batch(client)

# Add operations
Bosbase.BatchService.collection(batch, "posts")
|> Bosbase.BatchService.create(%{"title" => "Post 1", "author" => "AUTHOR_ID"})

Bosbase.BatchService.collection(batch, "posts")
|> Bosbase.BatchService.create(%{"title" => "Post 2", "author" => "AUTHOR_ID"})

Bosbase.BatchService.collection(batch, "tags")
|> Bosbase.BatchService.update("TAG_ID", %{"name" => "Updated Tag"})

Bosbase.BatchService.collection(batch, "categories")
|> Bosbase.BatchService.delete("CAT_ID")

# Send batch request
{:ok, results} = Bosbase.BatchService.send(batch)

# Results is a list matching the order of operations
Enum.each(results, fn result ->
  if result["status"] >= 400 do
    IO.inspect("Operation failed: #{inspect(result["body"])}")
  else
    IO.inspect("Operation succeeded: #{inspect(result["body"])}")
  end
end)
```

**Note**: Batch operations must be enabled in Dashboard > Settings > Application.

## Authentication Actions

### List Auth Methods

Get available authentication methods for a collection:

```elixir
{:ok, methods} = RecordService.list_auth_methods(users)

IO.inspect(methods["password"]["enabled"])      # true/false
IO.inspect(methods["oauth2"]["enabled"])         # true/false
IO.inspect(methods["oauth2"]["providers"])      # List of OAuth2 providers
IO.inspect(methods["otp"]["enabled"])            # true/false
IO.inspect(methods["mfa"]["enabled"])            # true/false
```

### Auth with Password

```elixir
{:ok, auth_data} = RecordService.auth_with_password(
  users,
  "user@example.com",  # username or email
  "password123"
)

# Auth data is automatically stored in client.auth_store
IO.inspect(Bosbase.AuthStore.valid?(client.auth_store))    # true
IO.inspect(Bosbase.AuthStore.token(client.auth_store))      # JWT token
IO.inspect(Bosbase.AuthStore.record(client.auth_store))     # User record

# With expand
{:ok, auth_data} = RecordService.auth_with_password(
  users,
  "user@example.com",
  "password123",
  %{"expand" => "profile"}
)
```

### Auth with OAuth2

```elixir
# Step 1: Get OAuth2 URL (usually done in UI)
{:ok, methods} = RecordService.list_auth_methods(users)
provider = Enum.find(methods["oauth2"]["providers"], fn p -> p["name"] == "google" end)

# Step 2: After redirect, exchange code for token
{:ok, auth_data} = RecordService.auth_with_oauth2_code(
  users,
  "google",                    # Provider name
  "AUTHORIZATION_CODE",        # From redirect URL
  provider["codeVerifier"],    # From step 1
  "https://yourapp.com/callback", # Redirect URL
  %{                           # Optional data for new accounts
    "name" => "John Doe"
  }
)
```

### Auth with OTP (One-Time Password)

```elixir
# Step 1: Request OTP
{:ok, otp_request} = RecordService.request_otp(users, "user@example.com")
# Returns: %{"otpId" => "..."}

# Step 2: User enters OTP from email
# Step 3: Authenticate with OTP
{:ok, auth_data} = RecordService.auth_with_otp(
  users,
  otp_request["otpId"],
  "123456"  # OTP from email
)
```

### Auth Refresh

Refresh the current auth token and get updated user data:

```elixir
# Refresh auth (useful on page reload)
{:ok, auth_data} = RecordService.auth_refresh(users)

# Check if still valid
if Bosbase.AuthStore.valid?(client.auth_store) do
  IO.puts("User is authenticated")
else
  IO.puts("Token expired or invalid")
end
```

### Email Verification

```elixir
# Request verification email
:ok = RecordService.request_verification(users, "user@example.com")

# Confirm verification (on verification page)
:ok = RecordService.confirm_verification(users, "VERIFICATION_TOKEN")
```

### Password Reset

```elixir
# Request password reset email
:ok = RecordService.request_password_reset(users, "user@example.com")

# Confirm password reset (on reset page)
# Note: This invalidates all previous auth tokens
:ok = RecordService.confirm_password_reset(
  users,
  "RESET_TOKEN",
  "newpassword123",
  "newpassword123"  # Confirm
)
```

### Email Change

```elixir
# Must be authenticated first
{:ok, _} = RecordService.auth_with_password(users, "user@example.com", "password")

# Request email change
:ok = RecordService.request_email_change(users, "newemail@example.com")

# Confirm email change (on confirmation page)
# Note: This invalidates all previous auth tokens
:ok = RecordService.confirm_email_change(
  users,
  "EMAIL_CHANGE_TOKEN",
  "currentpassword"
)
```

### Impersonate (Superuser Only)

Generate a token to authenticate as another user:

```elixir
# Must be authenticated as superuser
admins = Client.collection(client, "_superusers")
{:ok, _} = RecordService.auth_with_password(admins, "admin@example.com", "password")

# Impersonate a user
{:ok, impersonate_client} = RecordService.impersonate(users, "USER_ID", 3600)
# Returns a new client instance with impersonated user's token

# Use the impersonate client
impersonate_posts = Client.collection(impersonate_client, "posts")
{:ok, posts} = RecordService.get_full_list(impersonate_posts)

# Access the token
IO.inspect(Bosbase.AuthStore.token(impersonate_client.auth_store))
IO.inspect(Bosbase.AuthStore.record(impersonate_client.auth_store))
```

## Complete Examples

### Example 1: Blog Post Search with Filters

```elixir
defmodule PostSearch do
  alias Bosbase.{Client, RecordService}

  def search_posts(client, query, category_id, min_views) do
    posts = Client.collection(client, "posts")
    
    filter = ~s(title ~ "#{query}" || content ~ "#{query}")
    
    filter = if category_id do
      filter <> ~s( && categories.id ?= "#{category_id}")
    else
      filter
    end
    
    filter = if min_views do
      filter <> ~s( && views >= #{min_views})
    else
      filter
    end
    
    {:ok, result} = RecordService.get_list(posts, %{
      page: 1,
      per_page: 20,
      filter: filter,
      sort: "-created",
      expand: "author,categories"
    })
    
    result["items"]
  end
end

# Usage
client = Bosbase.new("http://localhost:8090")
posts = PostSearch.search_posts(client, "elixir", "cat123", 100)
```

### Example 2: User Dashboard with Related Content

```elixir
defmodule UserDashboard do
  alias Bosbase.{Client, RecordService}

  def get_user_dashboard(client, user_id) do
    posts = Client.collection(client, "posts")
    comments = Client.collection(client, "comments")
    
    # Get user's posts
    {:ok, posts_result} = RecordService.get_list(posts, %{
      page: 1,
      per_page: 10,
      filter: ~s(author = "#{user_id}"),
      sort: "-created",
      expand: "categories"
    })
    
    # Get user's comments
    {:ok, comments_result} = RecordService.get_list(comments, %{
      page: 1,
      per_page: 10,
      filter: ~s(user = "#{user_id}"),
      sort: "-created",
      expand: "post"
    })
    
    %{
      posts: posts_result["items"],
      comments: comments_result["items"]
    }
  end
end
```

### Example 3: Advanced Filtering

```elixir
{:ok, result} = RecordService.get_list(posts, %{
  page: 1,
  per_page: 50,
  filter: ~s(
    (status = "published" || featured = true) &&
    created >= "2023-01-01" &&
    (tags.id ?= "important" || categories.id = "news") &&
    views > 100 &&
    author.email != ""
  ),
  sort: "-views,created",
  expand: "author.profile,tags,categories",
  fields: "*,content:excerpt(300),author.name,author.email"
})
```

### Example 4: Batch Create Posts

```elixir
defmodule BatchPosts do
  alias Bosbase.{Client, BatchService}

  def create_multiple_posts(client, posts_data) do
    batch = Client.create_batch(client)
    
    Enum.each(posts_data, fn post_data ->
      BatchService.collection(batch, "posts")
      |> BatchService.create(post_data)
    end)
    
    {:ok, results} = BatchService.send(batch)
    
    # Check for failures
    failures = results
    |> Enum.with_index()
    |> Enum.filter(fn {result, _index} -> result["status"] >= 400 end)
    
    if length(failures) > 0 do
      IO.inspect("Some posts failed to create: #{inspect(failures)}")
    end
    
    Enum.map(results, fn r -> r["body"] end)
  end
end
```

### Example 5: Pagination Helper

```elixir
defmodule PaginationHelper do
  alias Bosbase.{Client, RecordService}

  def get_all_records_paginated(client, collection_name, opts \\ %{}) do
    collection = Client.collection(client, collection_name)
    all_records = []
    page = 1
    has_more = true
    
    while has_more do
      {:ok, result} = RecordService.get_list(collection, Map.merge(opts, %{
        page: page,
        per_page: 500,
        skip_total: true  # Skip count for performance
      }))
      
      items = result["items"] || []
      all_records = all_records ++ items
      has_more = length(items) == 500
      page = page + 1
    end
    
    all_records
  end
  
  defp while(condition, fun) do
    if condition do
      fun.()
      while(condition, fun)
    end
  end
end
```

## Error Handling

```elixir
case RecordService.create(posts, %{body: %{"title" => "My Post"}}) do
  {:ok, record} ->
    IO.inspect("Record created: #{inspect(record)}")
    
  {:error, %{status: 400}} ->
    # Validation error
    IO.inspect("Validation errors")
    
  {:error, %{status: 403}} ->
    # Permission denied
    IO.inspect("Access denied")
    
  {:error, %{status: 404}} ->
    # Not found
    IO.inspect("Collection or record not found")
    
  {:error, error} ->
    IO.inspect("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Use Pagination**: Always use pagination for large datasets
2. **Skip Total When Possible**: Use `skip_total: true` for better performance when you don't need counts
3. **Batch Operations**: Use batch for multiple operations to reduce round trips
4. **Field Selection**: Only request fields you need to reduce payload size
5. **Expand Wisely**: Only expand relations you actually use
6. **Filter Before Sort**: Apply filters before sorting for better performance
7. **Cache Auth Tokens**: Auth tokens are automatically stored in `auth_store`, no need to manually cache
8. **Handle Errors**: Always handle authentication and permission errors gracefully

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection configuration
- [Relations](./RELATIONS.md) - Working with relations
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filter syntax details
- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [Files](./FILES.md) - File uploads and handling

