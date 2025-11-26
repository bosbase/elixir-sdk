# API Rules Documentation - Elixir SDK

API Rules are collection access controls and data filters that determine who can perform actions on your collections and what data they can access.

## Overview

Each collection has 5 standard API rules, corresponding to specific API actions:

- **`listRule`** - Controls read/list access
- **`viewRule`** - Controls read/view access  
- **`createRule`** - Controls create access
- **`updateRule`** - Controls update access
- **`deleteRule`** - Controls delete access

Auth collections have two additional rules:

- **`manageRule`** - Admin-like permissions for managing auth records
- **`authRule`** - Additional constraints applied during authentication

## Rule Values

Each rule can be set to one of three values:

### 1. `null` (Locked)
Only authorized superusers can perform the action.

```elixir
# Set list rule to locked (superuser only)
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => nil
  })
```

### 2. `""` (Empty String - Public)
Anyone (superusers, authorized users, and guests) can perform the action.

```elixir
# Set list rule to public
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ""
  })
```

### 3. Non-empty String (Filter Expression)
Only users satisfying the filter expression can perform the action.

```elixir
# Set list rule with filter expression
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != "")
  })
```

## Default Permissions

When you create a base collection without specifying rules, BosBase applies opinionated defaults:

- `listRule` and `viewRule` default to an empty string (`""`), so guests and authenticated users can query records.
- `createRule` defaults to `@request.auth.id != ""`, restricting writes to authenticated users or superusers.
- `updateRule` and `deleteRule` default to `@request.auth.id != "" && createdBy = @request.auth.id`, which limits mutations to the record creator (superusers still bypass rules).

Every base collection now includes hidden system fields named `createdBy` and `updatedBy`. BosBase adds those fields automatically when a collection is created and manages their values server-side: `createdBy` always captures the authenticated actor that inserted the record (or stays empty for anonymous writes) and cannot be overridden later, while `updatedBy` is overwritten on each write (or cleared for anonymous writes). View collections inherit the public read defaults, and system collections such as `users`, `_superusers`, `_authOrigins`, `_externalAuths`, `_mfas`, and `_otps` keep their custom API rules.

## Setting Rules

### Individual Rules

Set individual rules when creating or updating a collection:

```elixir
# Create collection with rules
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.create_base(pb, "products", %{
    "fields" => [
      %{"name" => "name", "type" => "text", "required" => true}
    ],
    "listRule" => ~s(@request.auth.id != ""),
    "viewRule" => ~s(@request.auth.id != ""),
    "createRule" => ~s(@request.auth.id != ""),
    "updateRule" => ~s(@request.auth.id != "" && author.id ?= @request.auth.id),
    "deleteRule" => nil  # Only superusers
  })

# Update rules
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != "" && status = "active")
  })
```

### Bulk Rule Updates

Set multiple rules at once:

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != ""),
    "viewRule" => ~s(@request.auth.id != ""),
    "createRule" => ~s(@request.auth.id != ""),
    "updateRule" => ~s(@request.auth.id != "" && author.id ?= @request.auth.id),
    "deleteRule" => nil  # Only superusers
  })
```

### Getting Rules

Retrieve all rules for a collection:

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "products")

IO.puts(collection["listRule"])
IO.puts(collection["viewRule"])
```

## Filter Syntax

Rules use the same filter syntax as API queries. The syntax follows: `OPERAND OPERATOR OPERAND`

### Operators

- `=` - Equal
- `!=` - NOT equal
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal
- `~` - Like/Contains (auto-wraps string in `%` for wildcard)
- `!~` - NOT Like/Contains
- `?=` - Any/At least one of Equal
- `?!=` - Any/At least one of NOT equal
- `?>` - Any/At least one of Greater than
- `?>=` - Any/At least one of Greater than or equal
- `?<` - Any/At least one of Less than
- `?<=` - Any/At least one of Less than or equal
- `?~` - Any/At least one of Like/Contains
- `?!~` - Any/At least one of NOT Like/Contains

### Logical Operators

- `&&` - AND
- `||` - OR
- `(...)` - Grouping parentheses

### Field Access

#### Collection Schema Fields

Access fields from your collection schema:

```elixir
# Filter by status field
list_rule: ~s(status = "active")

# Access nested relation fields
list_rule: ~s(author.status != "banned")

# Access relation IDs
list_rule: ~s(author.id ?= @request.auth.id)
```

#### Request Context (`@request.*`)

Access current request data:

```elixir
# Authentication state
list_rule: ~s(@request.auth.id != "")  # User is authenticated
list_rule: ~s(@request.auth.id = "")   # User is guest

# Request context
list_rule: ~s(@request.context != "oauth2")  # Not an OAuth2 request

# HTTP method
update_rule: ~s(@request.method = "PATCH")

# Request headers (normalized: lowercase, "-" replaced with "_")
list_rule: ~s(@request.headers.x_token = "test")

# Query parameters
list_rule: ~s(@request.query.page = "1")

# Body parameters
create_rule: ~s(@request.body.title != "")
update_rule: ~s(@request.body.status:isset = false)  # Prevent changing status
```

#### Other Collections (`@collection.*`)

Target other collections that share common field values:

```elixir
# Check if user has access in related collection
list_rule: ~s(@collection.permissions.user ?= @request.auth.id && @collection.permissions.resource = id)

# Using aliases for multiple joins
list_rule: ~s(
  @request.auth.id != "" &&
  @collection.courseRegistrations.user ?= id &&
  @collection.courseRegistrations:auth.user ?= @request.auth.id &&
  @collection.courseRegistrations.courseGroup ?= @collection.courseRegistrations:auth.courseGroup
)
```

### Field Modifiers

#### `:isset` Modifier

Check if a request field was submitted:

```elixir
# Prevent changing role field
update_rule: ~s(@request.body.role:isset = false)
```

#### `:length` Modifier

Check the number of items in an array field:

```elixir
# At least 2 items in select field
create_rule: ~s(@request.body.tags:length > 1)

# Check existing relation field length
list_rule: ~s(someRelationField:length = 2)
```

#### `:each` Modifier

Apply condition to each item in a multiple field:

```elixir
# All select options contain "create"
create_rule: ~s(@request.body.someSelectField:each ~ "create")

# All fields have "pb_" prefix
list_rule: ~s(someSelectField:each ~ "pb_%")
```

#### `:lower` Modifier

Perform case-insensitive string comparisons:

```elixir
# Case-insensitive title check
create_rule: ~s(@request.body.title:lower = "test")

# Case-insensitive existing field match
list_rule: ~s(title:lower ~ "test")
```

### DateTime Macros

All macros are UTC-based:

```elixir
# Current datetime
"@now"

# Date components
"@second"    # 0-59
"@minute"    # 0-59
"@hour"      # 0-23
"@weekday"   # 0-6
"@day"       # Day number
"@month"     # Month number
"@year"      # Year number

# Relative dates
"@yesterday"
"@tomorrow"
"@todayStart"  # Beginning of current day
"@todayEnd"    # End of current day
"@monthStart"  # Beginning of current month
"@monthEnd"    # End of current month
"@yearStart"   # Beginning of current year
"@yearEnd"     # End of current year
```

Example:

```elixir
list_rule: ~s(@request.body.publicDate >= @now)
list_rule: ~s(created >= @todayStart && created <= @todayEnd)
```

### Functions

#### `geoDistance(lonA, latA, lonB, latB)`

Calculate Haversine distance between two geographic points in kilometres:

```elixir
# Offices within 25km
list_rule: ~s(geoDistance(address.lon, address.lat, 23.32, 42.69) < 25)
```

## Common Examples

### Allow Only Registered Users

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != "")
  })
```

### Filter by Status

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(status = "active")
  })
```

### Combine Conditions

```elixir
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(@request.auth.id != "" && (status = "active" || status = "pending"))
  })
```

### Filter by Relation

```elixir
# Only show records where user is the author
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(@request.auth.id != "" && author.id ?= @request.auth.id)
  })

# Only show records where user is in allowed_users relation
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "documents", %{
    "listRule" => ~s(@request.auth.id != "" && allowed_users.id ?= @request.auth.id)
  })
```

### Public Access with Filter

```elixir
# Allow anyone, but only show active items
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "products", %{
    "listRule" => ~s(status = "active")
  })

# Allow anyone, filter by title prefix
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "articles", %{
    "listRule" => ~s(title ~ "Lorem%")
  })
```

### Owner-Based Update/Delete

```elixir
# Users can only update/delete their own records
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "updateRule" => ~s(@request.auth.id != "" && author.id = @request.auth.id),
    "deleteRule" => ~s(@request.auth.id != "" && author.id = @request.auth.id)
  })
```

### Prevent Field Modification

```elixir
# Prevent changing role field
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "updateRule" => ~s(@request.auth.id != "" && @request.body.role:isset = false)
  })
```

### Date-Based Rules

```elixir
# Only show future events
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "events", %{
    "listRule" => ~s(startDate >= @now)
  })

# Only show items created today
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "listRule" => ~s(created >= @todayStart && created <= @todayEnd)
  })
```

### Array Field Validation

```elixir
# Require at least one tag
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "createRule" => ~s(@request.body.tags:length > 0)
  })

# Require all tags to start with "pb_"
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{
    "createRule" => ~s(@request.body.tags:each ~ "pb_%")
  })
```

### Geographic Distance

```elixir
# Only show offices within 25km of location
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "offices", %{
    "listRule" => ~s(geoDistance(address.lon, address.lat, 23.32, 42.69) < 25)
  })
```

## Auth Collection Rules

### Auth Rule

Controls who can authenticate:

```elixir
# Only verified users can authenticate
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "authRule" => ~s(verified = true)
  })

# Allow all users to authenticate
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "authRule" => ""  # Empty string = allow all
  })

# Disable authentication (only superusers can auth)
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "authRule" => nil  # null = disabled
  })
```

### Manage Rule

Gives admin-like permissions for managing auth records:

```elixir
# Allow users to manage other users' records if they have permission
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "manageRule" => ~s(@collection.user_permissions.user ?= @request.auth.id && @collection.user_permissions.target ?= id)
  })

# Allow specific role to manage all users
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "users", %{
    "manageRule" => ~s(@request.auth.role = "admin")
  })
```

## Best Practices

1. **Start with locked rules** (null) for security, then gradually open access as needed
2. **Use relation checks** for owner-based access patterns
3. **Combine multiple conditions** using `&&` and `||` for complex scenarios
4. **Test rules thoroughly** before deploying to production
5. **Document your rules** in code comments explaining the business logic
6. **Use empty string (`""`)** only when you truly want public access
7. **Leverage modifiers** (`:isset`, `:length`, `:each`) for validation

## Error Responses

API Rules also act as data filters. When a request doesn't satisfy a rule:

- **listRule** - Returns `200` with empty items (filters out records)
- **createRule** - Returns `400` Bad Request
- **viewRule** - Returns `404` Not Found
- **updateRule** - Returns `404` Not Found
- **deleteRule** - Returns `404` Not Found
- **All rules** - Return `403` Forbidden if locked (null) and user is not superuser

## Notes

- **Superusers bypass all rules** - Rules are ignored when the action is performed by an authorized superuser
- **Rules are evaluated server-side** - Client-side validation is not enough
- **Comments are supported** - Use `//` for single-line comments in rules
- **System fields protection** - Some fields may be protected regardless of rules

## Related Documentation

- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Detailed filter syntax and examples
- [Users Collection Guide](./USERS_COLLECTION_GUIDE.md) - Using `@request.auth` with users

