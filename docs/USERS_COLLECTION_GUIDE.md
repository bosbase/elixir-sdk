# Built-in Users Collection Guide - Elixir SDK Documentation

This guide explains how to use the built-in `users` collection for authentication, registration, and API rules. **The `users` collection is automatically created when BosBase is initialized and does not need to be created manually.**

## Table of Contents

1. [Overview](#overview)
2. [Users Collection Structure](#users-collection-structure)
3. [User Registration](#user-registration)
4. [User Login/Authentication](#user-loginauthentication)
5. [API Rules and Filters with Users](#api-rules-and-filters-with-users)
6. [Using Users with Other Collections](#using-users-with-other-collections)
7. [Complete Examples](#complete-examples)

---

## Overview

The `users` collection is a **built-in auth collection** that is automatically created when BosBase starts. It has:

- **Collection ID**: `_pb_users_auth_`
- **Collection Name**: `users`
- **Type**: `auth` (authentication collection)
- **Purpose**: User accounts, authentication, and authorization

**Important**: 
- ✅ **DO NOT** create a new `users` collection manually
- ✅ **DO** use the existing built-in `users` collection
- ✅ The collection already has proper API rules configured
- ✅ It supports password, OAuth2, and OTP authentication

### Getting Users Collection Information

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Get the users collection details
{:ok, users_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "users")
# or by ID
{:ok, users_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "_pb_users_auth_")

IO.inspect(users_collection["id"])
IO.inspect(users_collection["name"])
IO.inspect(users_collection["type"])
IO.inspect(users_collection["fields"])

# API Rules
IO.inspect(%{
  "listRule" => users_collection["listRule"],
  "viewRule" => users_collection["viewRule"],
  "createRule" => users_collection["createRule"],
  "updateRule" => users_collection["updateRule"],
  "deleteRule" => users_collection["deleteRule"]
})
```

---

## Users Collection Structure

### System Fields (Automatically Created)

These fields are automatically added to all auth collections (including `users`):

| Field Name | Type | Description | Required | Hidden |
|------------|------|-------------|----------|--------|
| `id` | text | Unique record identifier | Yes | No |
| `email` | email | User email address | Yes* | No |
| `username` | text | Username (optional, if enabled) | No* | No |
| `password` | password | Hashed password | Yes* | Yes |
| `tokenKey` | text | Token key for auth tokens | Yes | Yes |
| `emailVisibility` | bool | Whether email is visible to others | No | No |
| `verified` | bool | Whether email is verified | No | No |
| `created` | date | Record creation timestamp | Yes | No |
| `updated` | date | Last update timestamp | Yes | No |

*Required based on authentication method configuration (password auth, username auth, etc.)

### Custom Fields (Pre-configured)

The built-in `users` collection includes these custom fields:

| Field Name | Type | Description | Required |
|------------|------|-------------|----------|
| `name` | text | User's display name | No (max: 255 characters) |
| `avatar` | file | User avatar image | No (max: 1 file, images only) |

### Default API Rules

The `users` collection comes with these default API rules:

```elixir
%{
  "listRule" => "id = @request.auth.id",    # Users can only list themselves
  "viewRule" => "id = @request.auth.id",   # Users can only view themselves
  "createRule" => "",                       # Anyone can register (public)
  "updateRule" => "id = @request.auth.id", # Users can only update themselves
  "deleteRule" => "id = @request.auth.id"  # Users can only delete themselves
}
```

**Understanding the Rules:**

1. **`listRule: "id = @request.auth.id"`**
   - Users can only see their own record when listing
   - If not authenticated, returns empty list (not an error)
   - Superusers can see all users

2. **`viewRule: "id = @request.auth.id"`**
   - Users can only view their own record
   - If trying to view another user, returns 404
   - Superusers can view any user

3. **`createRule: ""`** (empty string)
   - **Public registration** - Anyone can create a user account
   - No authentication required
   - This enables self-registration

4. **`updateRule: "id = @request.auth.id"`**
   - Users can only update their own record
   - Prevents users from modifying other users' data
   - Superusers can update any user

5. **`deleteRule: "id = @request.auth.id"`**
   - Users can only delete their own account
   - Prevents users from deleting other users
   - Superusers can delete any user

**Note**: These rules ensure user privacy and security. Users can only access and modify their own data unless they are superusers.

---

## User Registration

### Basic Registration

Users can register by creating a record in the `users` collection. The `createRule` is set to `""` (empty string), meaning **anyone can register**.

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Register a new user
{:ok, new_user} = Client.collection(pb, "users")
  |> Bosbase.RecordService.create(%{
    "email" => "user@example.com",
    "password" => "securepassword123",
    "passwordConfirm" => "securepassword123",
    "name" => "John Doe"
  })

IO.puts("User registered: #{new_user["id"]}")
IO.puts("Email: #{new_user["email"]}")
```

### Registration with Email Verification

```elixir
# Register user (verification email sent automatically if configured)
{:ok, new_user} = Client.collection(pb, "users")
  |> Bosbase.RecordService.create(%{
    "email" => "user@example.com",
    "password" => "securepassword123",
    "passwordConfirm" => "securepassword123",
    "name" => "John Doe"
  })

# User will receive verification email
# After clicking link, verified field becomes true
IO.puts("Verified: #{new_user["verified"]}")  # false initially
```

### Registration with Username

If username authentication is enabled in the collection settings:

```elixir
{:ok, new_user} = Client.collection(pb, "users")
  |> Bosbase.RecordService.create(%{
    "email" => "user@example.com",
    "username" => "johndoe",
    "password" => "securepassword123",
    "passwordConfirm" => "securepassword123",
    "name" => "John Doe"
  })
```

### Check if Email Exists

```elixir
case Client.collection(pb, "users")
     |> Bosbase.RecordService.get_first_list_item(~s(email = "user@example.com")) do
  {:ok, existing} ->
    IO.puts("Email already exists")
  {:error, %{status: 404}} ->
    IO.puts("Email is available")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

---

## User Login/Authentication

### Password Authentication

```elixir
# Login with email and password
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password123")

# Auth data is automatically stored in auth store
IO.puts("Token: #{auth_data["token"]}")
IO.inspect(auth_data["record"])
```

### Login with Username

If username authentication is enabled:

```elixir
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("johndoe", "password123")  # username instead of email
```

### OAuth2 Authentication

```elixir
# Login with OAuth2 (e.g., Google)
# Note: OAuth2 flow typically requires browser interaction
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_oauth2(%{
    "provider" => "google"
  })

# If user doesn't exist, account is created automatically
IO.inspect(auth_data["record"])
```

### OTP Authentication

```elixir
# Step 1: Request OTP
{:ok, otp_result} = Client.collection(pb, "users")
  |> Bosbase.RecordService.request_otp("user@example.com")

# Step 2: Authenticate with OTP code from email
{:ok, auth_data} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_otp(otp_result["otpId"], "123456")  # OTP code from email
```

### Check Current Authentication

```elixir
# Check auth store
store = pb.auth_store  # Get auth store from client

if Bosbase.AuthStore.valid?(store) do
  user = Bosbase.AuthStore.record(store)
  IO.puts("Logged in as: #{user["email"]}")
  IO.puts("User ID: #{user["id"]}")
  IO.puts("Name: #{user["name"]}")
else
  IO.puts("Not authenticated")
end
```

### Refresh Auth Token

```elixir
# Refresh the authentication token
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_refresh()
```

### Logout

```elixir
# Clear auth store
Bosbase.AuthStore.clear(pb.auth_store)
```

### Get Current User

```elixir
store = pb.auth_store
current_user = Bosbase.AuthStore.record(store)

if current_user do
  IO.puts("Current user: #{current_user["email"]}")
  IO.puts("User ID: #{current_user["id"]}")
  IO.puts("Name: #{current_user["name"]}")
  IO.puts("Verified: #{current_user["verified"]}")
end
```

### Accessing User Fields

```elixir
# After authentication, access user fields
store = pb.auth_store
user = Bosbase.AuthStore.record(store)

# System fields
IO.puts(user["id"])                    # User ID
IO.puts(user["email"])                 # Email
IO.puts(user["username"])              # Username (if enabled)
IO.puts(user["verified"])              # Email verification status
IO.puts(user["emailVisibility"])       # Email visibility setting
IO.puts(user["created"])               # Creation date
IO.puts(user["updated"])               # Last update date

# Custom fields (from users collection)
IO.puts(user["name"])                  # Display name
IO.puts(user["avatar"])                # Avatar filename
```

---

## API Rules and Filters with Users

### Understanding @request.auth

The `@request.auth` identifier provides access to the currently authenticated user's data in API rules and filters.

**Available Properties:**
- `@request.auth.id` - User's record ID
- `@request.auth.email` - User's email
- `@request.auth.username` - User's username (if enabled)
- `@request.auth.*` - Any field from the user record

### Common API Rule Patterns

#### 1. Require Authentication

```elixir
# Only authenticated users can access
list_rule: ~s(@request.auth.id != "")
view_rule: ~s(@request.auth.id != "")
create_rule: ~s(@request.auth.id != "")
```

#### 2. Owner-Based Access

```elixir
# Users can only access their own records
view_rule: ~s(author = @request.auth.id)
update_rule: ~s(author = @request.auth.id)
delete_rule: ~s(author = @request.auth.id)
```

#### 3. Public with User-Specific Data

```elixir
# Public can see published, users can see their own
list_rule: ~s(@request.auth.id != "" && author = @request.auth.id || status = "published")
view_rule: ~s(@request.auth.id != "" && author = @request.auth.id || status = "published")
```

#### 4. Role-Based Access (if you add a role field)

```elixir
# Assuming you add a 'role' select field to users collection
list_rule: ~s(@request.auth.id != "" && @request.auth.role = "admin")
update_rule: ~s(@request.auth.role = "admin" || author = @request.auth.id)
```

#### 5. Verified Users Only

```elixir
# Only verified users can create
create_rule: ~s(@request.auth.id != "" && @request.auth.verified = true)
```

### Setting API Rules for Other Collections

When creating collections that relate to users:

```elixir
# Create posts collection with user-based rules
{:ok, posts_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "posts", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true},
      %{"name" => "content", "type" => "editor"},
      %{
        "name" => "author",
        "type" => "relation",
        "collectionId" => "_pb_users_auth_",  # Reference to users collection
        "maxSelect" => 1,
        "required" => true
      },
      %{
        "name" => "status",
        "type" => "select",
        "options" => %{"values" => ["draft", "published"]}
      }
    ],
    # Public can see published posts, users can see their own
    "listRule" => ~s(@request.auth.id != "" && author = @request.auth.id || status = "published"),
    "viewRule" => ~s(@request.auth.id != "" && author = @request.auth.id || status = "published"),
    # Only authenticated users can create
    "createRule" => ~s(@request.auth.id != ""),
    # Only authors can update their posts
    "updateRule" => ~s(author = @request.auth.id),
    # Only authors can delete their posts
    "deleteRule" => ~s(author = @request.auth.id)
  })
```

### Using Filters with Users

```elixir
# Get posts by current user
store = pb.auth_store
user_id = Bosbase.AuthStore.record(store)["id"]

{:ok, my_posts} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author = "#{user_id}")
  })

# Get posts by verified users only
{:ok, verified_posts} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author.verified = true),
    "expand" => "author"
  })

# Get posts where author name contains "John"
{:ok, posts} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author.name ~ "John"),
    "expand" => "author"
  })
```

---

## Using Users with Other Collections

### Creating Relations to Users

When creating collections that need to reference users:

```elixir
# Create a posts collection with author relation
{:ok, posts_collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "posts", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true},
      %{
        "name" => "author",
        "type" => "relation",
        "collectionId" => "_pb_users_auth_",  # Users collection ID
        # OR use collection name
        # "collectionName" => "users",
        "maxSelect" => 1,
        "required" => true
      }
    ]
  })
```

### Creating Records with User Relations

```elixir
# Authenticate first
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password")

# Get current user ID
store = pb.auth_store
user_id = Bosbase.AuthStore.record(store)["id"]

# Create a post with current user as author
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "My First Post",
    "author" => user_id  # Current user's ID
  })
```

### Querying with User Relations

```elixir
# Get posts with author information
{:ok, result} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "expand" => "author"  # Expand the author relation
  })

Enum.each(result["items"], fn post ->
  IO.puts("Post: #{post["title"]}")
  IO.puts("Author: #{post["expand"]["author"]["name"]}")
  IO.puts("Author Email: #{post["expand"]["author"]["email"]}")
end)

# Filter posts by author
{:ok, user_posts} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author = "USER_ID"),
    "expand" => "author"
  })
```

### Updating User Profile

```elixir
# Users can update their own profile
store = pb.auth_store
user_id = Bosbase.AuthStore.record(store)["id"]

{:ok, _updated} = Client.collection(pb, "users")
  |> Bosbase.RecordService.update(user_id, %{
    "name" => "Updated Name"
  })
```

---

## Complete Examples

### Example 1: User Registration and Login Flow

```elixir
defmodule UserAuth do
  def register_and_login(pb) do
    try do
      # 1. Register new user
      {:ok, new_user} = Client.collection(pb, "users")
        |> Bosbase.RecordService.create(%{
          "email" => "newuser@example.com",
          "password" => "securepassword123",
          "passwordConfirm" => "securepassword123",
          "name" => "New User"
        })
      
      IO.puts("Registration successful: #{new_user["id"]}")
      
      # 2. Login with credentials
      {:ok, auth_data} = Client.collection(pb, "users")
        |> Bosbase.RecordService.auth_with_password(
          "newuser@example.com",
          "securepassword123"
        )
      
      IO.puts("Login successful")
      IO.puts("Token: #{auth_data["token"]}")
      IO.inspect(auth_data["record"])
      
      {:ok, auth_data}
    rescue
      error ->
        IO.puts("Error: #{inspect(error)}")
        {:error, error}
    end
  end
end

# Usage
pb = Client.new("http://localhost:8090")
UserAuth.register_and_login(pb)
```

### Example 2: Creating User-Related Collections

```elixir
defmodule UserCollections do
  def setup(pb) do
    # Authenticate as superuser to create collections
    {:ok, _auth} = Client.collection(pb, "_superusers")
      |> Bosbase.RecordService.auth_with_password("admin@example.com", "adminpassword")
    
    # Create posts collection linked to users
    {:ok, posts_collection} = Bosbase.collections()
      |> Bosbase.CollectionService.create_base(pb, "posts", %{
        "fields" => [
          %{"name" => "title", "type" => "text", "required" => true},
          %{"name" => "content", "type" => "editor"},
          %{
            "name" => "author",
            "type" => "relation",
            "collectionId" => "_pb_users_auth_",  # Link to users
            "maxSelect" => 1,
            "required" => true
          },
          %{
            "name" => "status",
            "type" => "select",
            "options" => %{"values" => ["draft", "published"]}
          }
        ],
        # API rules using users collection
        "listRule" => ~s(@request.auth.id != "" && author = @request.auth.id || status = "published"),
        "viewRule" => ~s(@request.auth.id != "" && author = @request.auth.id || status = "published"),
        "createRule" => ~s(@request.auth.id != ""),
        "updateRule" => ~s(author = @request.auth.id),
        "deleteRule" => ~s(author = @request.auth.id)
      })
    
    IO.puts("Collections created successfully")
  end
end
```

## Best Practices

1. **Always use the built-in `users` collection** - Don't create a new one
2. **Use `_pb_users_auth_` as collectionId** when creating relations
3. **Check authentication** before user-specific operations
4. **Use `@request.auth.id`** in API rules for user-based access control
5. **Expand user relations** when you need user information
6. **Respect emailVisibility** - Don't expose emails unless user allows it
7. **Handle verification** - Check `verified` field for email verification status
8. **Use proper error handling** for registration/login failures

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - Detailed authentication guide
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules
- [Relations](./RELATIONS.md) - Working with relations

