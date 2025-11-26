# API Rules and Filters - Elixir SDK Documentation

## Overview

API Rules are your collection access controls and data filters. They control who can perform actions on your collections and what data they can access.

Each collection has 5 rules, corresponding to specific API actions:
- `listRule` - Controls who can list records
- `viewRule` - Controls who can view individual records
- `createRule` - Controls who can create records
- `updateRule` - Controls who can update records
- `deleteRule` - Controls who can delete records

Auth collections have an additional `manageRule` that allows one user to fully manage another user's data.

## Rule Values

Each rule can be set to:

- **`null` (locked)** - Only authorized superusers can perform the action (default)
- **Empty string `""`** - Anyone can perform the action (superusers, authenticated users, and guests)
- **Non-empty string** - Only users that satisfy the filter expression can perform the action

## Important Notes

1. **Rules act as filters**: API Rules also act as record filters. For example, setting `listRule` to `status = "active"` will only return active records.
2. **HTTP Status Codes**: 
   - `200` with empty items for unsatisfied `listRule`
   - `400` for unsatisfied `createRule`
   - `404` for unsatisfied `viewRule`, `updateRule`, `deleteRule`
   - `403` for locked rules when not a superuser
3. **Superuser bypass**: API Rules are ignored when the action is performed by an authorized superuser.

## Setting Rules via SDK

### Elixir SDK

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Create collection with rules
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "articles", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true},
      %{
        "name" => "status",
        "type" => "select",
        "options" => %{"values" => ["draft", "published"]},
        "maxSelect" => 1
      },
      %{
        "name" => "author",
        "type" => "relation",
        "options" => %{"collectionId" => "users"},
        "maxSelect" => 1
      }
    ],
    "listRule" => ~s(@request.auth.id != "" || status = "published"),
    "viewRule" => ~s(@request.auth.id != "" || status = "published"),
    "createRule" => ~s(@request.auth.id != ""),
    "updateRule" => ~s(author = @request.auth.id || @request.auth.role = "admin"),
    "deleteRule" => ~s(author = @request.auth.id || @request.auth.role = "admin")
  })

# Update rules
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "articles", %{
    "listRule" => ~s(@request.auth.id != "" && (status = "published" || status = "draft"))
  })

# Remove rule (set to empty string for public access)
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "articles", %{
    "listRule" => ""  # Anyone can list
  })

# Lock rule (set to null for superuser only)
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "articles", %{
    "deleteRule" => nil  # Only superusers can delete
  })
```

## Filter Syntax

The syntax follows: `OPERAND OPERATOR OPERAND`

### Operators

**Comparison Operators:**
- `=` - Equal
- `!=` - NOT equal
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal

**String Operators:**
- `~` - Like/Contains (auto-wraps right operand in `%` for wildcard match)
- `!~` - NOT Like/Contains

**Array Operators (Any/At least one of):**
- `?=` - Any Equal
- `?!=` - Any NOT equal
- `?>` - Any Greater than
- `?>=` - Any Greater than or equal
- `?<` - Any Less than
- `?<=` - Any Less than or equal
- `?~` - Any Like/Contains
- `?!~` - Any NOT Like/Contains

**Logical Operators:**
- `&&` - AND
- `||` - OR
- `()` - Grouping
- `//` - Single line comments

## Special Identifiers

### @request.*

Access current request data:

**@request.context** - The context where the rule is used
```elixir
list_rule: ~s(@request.context != "oauth2")
```

**@request.method** - HTTP request method
```elixir
update_rule: ~s(@request.method = "PATCH")
```

**@request.headers.*** - Request headers (normalized to lowercase, `-` replaced with `_`)
```elixir
list_rule: ~s(@request.headers.x_token = "test")
```

**@request.query.*** - Query parameters
```elixir
list_rule: ~s(@request.query.page = "1")
```

**@request.auth.*** - Current authenticated user
```elixir
list_rule: ~s(@request.auth.id != "")
view_rule: ~s(@request.auth.email = "admin@example.com")
update_rule: ~s(@request.auth.role = "admin")
```

**@request.body.*** - Submitted body parameters
```elixir
create_rule: ~s(@request.body.title != "")
update_rule: ~s(@request.body.status:isset = false)  # Prevent changing status
```

### @collection.*

Target other collections that aren't directly related:

```elixir
# Check if user has access to related collection
list_rule: ~s(@request.auth.id != "" && @collection.news.categoryId ?= categoryId && @collection.news.author ?= @request.auth.id)

# Using aliases for multiple joins
list_rule: ~s(
  @request.auth.id != "" &&
  @collection.courseRegistrations.user ?= id &&
  @collection.courseRegistrations:auth.user ?= @request.auth.id &&
  @collection.courseRegistrations.courseGroup ?= @collection.courseRegistrations:auth.courseGroup
)
```

### @ Macros (Datetime)

All macros are UTC-based:

- `@now` - Current datetime as string
- `@second` - Current second (0-59)
- `@minute` - Current minute (0-59)
- `@hour` - Current hour (0-23)
- `@weekday` - Current weekday (0-6)
- `@day` - Current day
- `@month` - Current month
- `@year` - Current year
- `@yesterday` - Yesterday datetime
- `@tomorrow` - Tomorrow datetime
- `@todayStart` - Beginning of current day
- `@todayEnd` - End of current day
- `@monthStart` - Beginning of current month
- `@monthEnd` - End of current month
- `@yearStart` - Beginning of current year
- `@yearEnd` - End of current year

**Example:**
```elixir
list_rule: ~s(@request.body.publicDate >= @now)
list_rule: ~s(created >= @todayStart && created <= @todayEnd)
```

## Field Modifiers

### :isset

Check if a field was submitted in the request (only for `@request.*` fields):

```elixir
# Prevent changing role field
update_rule: ~s(@request.body.role:isset = false)

# Require email field
create_rule: ~s(@request.body.email:isset = true)
```

### :length

Check the number of items in an array field (multiple file, select, relation):

```elixir
# Check submitted array length
create_rule: ~s(@request.body.tags:length > 1 && @request.body.tags:length <= 5)

# Check existing record array length
list_rule: ~s(categories:length = 2)
list_rule: ~s(documents:length >= 1)
```

### :each

Apply condition on each item in an array field:

```elixir
# Check if all submitted select options contain "create"
create_rule: ~s(@request.body.permissions:each ~ "create")

# Check if all existing field values have "pb_" prefix
list_rule: ~s(tags:each ~ "pb_%")
```

### :lower

Perform case-insensitive string comparisons:

```elixir
# Case-insensitive comparison
list_rule: ~s(@request.body.title:lower = "test")
update_rule: ~s(status:lower ~ "active")
```

## geoDistance Function

Calculate Haversine distance between two geographic points in kilometers:

```elixir
# Offices within 25km of location
list_rule: ~s(geoDistance(address.lon, address.lat, 23.32, 42.69) < 25)

# Using request data
list_rule: ~s(geoDistance(location.lon, location.lat, @request.query.lon, @request.query.lat) < @request.query.radius)
```

## Common Rule Examples

### Allow Only Authenticated Users

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != ""),
    "viewRule" => ~s(@request.auth.id != ""),
    "createRule" => ~s(@request.auth.id != ""),
    "updateRule" => ~s(@request.auth.id != ""),
    "deleteRule" => ~s(@request.auth.id != "")
  })
```

### Owner-Based Access

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "viewRule" => ~s(@request.auth.id != "" && author = @request.auth.id),
    "updateRule" => ~s(@request.auth.id != "" && author = @request.auth.id),
    "deleteRule" => ~s(@request.auth.id != "" && author = @request.auth.id)
  })
```

### Role-Based Access

```elixir
# Assuming users have a "role" select field
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && @request.auth.role = "admin"),
    "updateRule" => ~s(@request.auth.role = "admin" || author = @request.auth.id)
  })
```

### Public with Authentication

```elixir
# Public can view published, authenticated can view all
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" || status = "published"),
    "viewRule" => ~s(@request.auth.id != "" || status = "published")
  })
```

### Filtered Results

```elixir
# Only show active records
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(status = "active")
  })

# Only show records from last 30 days
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(created >= @yesterday)
  })

# Only show records matching user's organization
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && organization = @request.auth.organization)
  })
```

### Complex Rules

```elixir
# Multiple conditions
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && (status = "published" || status = "draft") && author = @request.auth.id)
  })

# Nested relations
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && author.role = "staff")
  })

# Back relations
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && comments_via_author.id != "")
  })
```

## Using Filters in Queries

Filters can also be used in regular queries (not just rules):

```elixir
# List with filter
{:ok, result} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(status = "published" && created >= @todayStart)
  })

# Complex filter
{:ok, result} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s((title ~ "test" || description ~ "test") && status = "published")
  })

# Using relation filters
{:ok, result} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author.role = "admin" && categories.id ?= "CAT_ID")
  })

# Geo distance filter
{:ok, result} = Client.collection(pb, "offices")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(geoDistance(location.lon, location.lat, 23.32, 42.69) < 25)
  })
```

## Complete Example

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Create users collection with role field
{:ok, users} = Bosbase.collections()
  |> Bosbase.CollectionService.create_auth(pb, "users", %{
    "fields" => [
      %{"name" => "name", "type" => "text", "required" => true},
      %{
        "name" => "role",
        "type" => "select",
        "options" => %{"values" => ["user", "staff", "admin"]},
        "maxSelect" => 1
      }
    ]
  })

# Create articles collection with comprehensive rules
{:ok, articles} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "articles", %{
    "fields" => [
      %{"name" => "title", "type" => "text", "required" => true},
      %{"name" => "content", "type" => "editor", "required" => true},
      %{
        "name" => "status",
        "type" => "select",
        "options" => %{"values" => ["draft", "published", "archived"]},
        "maxSelect" => 1
      },
      %{
        "name" => "author",
        "type" => "relation",
        "options" => %{"collectionId" => users["id"]},
        "maxSelect" => 1,
        "required" => true
      },
      %{
        "name" => "categories",
        "type" => "relation",
        "options" => %{"collectionId" => "categories"},
        "maxSelect" => 5
      },
      %{"name" => "published_at", "type" => "date"}
    ],
    # Public can see published, authenticated can see their own or published
    "listRule" => ~s(@request.auth.id != "" && (author = @request.auth.id || status = "published") || status = "published"),
    
    # Same logic for viewing
    "viewRule" => ~s(@request.auth.id != "" && (author = @request.auth.id || status = "published") || status = "published"),
    
    # Only authenticated users can create
    "createRule" => ~s(@request.auth.id != ""),
    
    # Owners or admins can update, but prevent changing status after publishing
    "updateRule" => ~s(@request.auth.id != "" && (author = @request.auth.id || @request.auth.role = "admin") && (@request.body.status:isset = false || status != "published")),
    
    # Only owners or admins can delete
    "deleteRule" => ~s(@request.auth.id != "" && (author = @request.auth.id || @request.auth.role = "admin"))
  })

# Authenticate as regular user
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password123")

# User can create article
store = pb.auth_store
user_id = Bosbase.AuthStore.record(store)["id"]

{:ok, article} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.create(%{
    "title" => "My Article",
    "content" => "<p>Content</p>",
    "status" => "draft",
    "author" => user_id
  })

# User can update their own article
{:ok, _updated} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.update(article["id"], %{
    "title" => "Updated Title"
  })

# User can list their own articles or published ones
{:ok, my_articles} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(author = @request.auth.id)
  })

# User can also query with additional filters
{:ok, published} = Client.collection(pb, "articles")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(status = "published" && created >= @todayStart)
  })
```

## Related Documentation

- [API Rules](./api-rules.md) - Detailed API rules documentation
- [Users Collection Guide](./USERS_COLLECTION_GUIDE.md) - Using `@request.auth` with users
- [API Records](./API_RECORDS.md) - Working with records and filters

