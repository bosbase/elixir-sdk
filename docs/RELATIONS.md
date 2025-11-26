# Working with Relations - Elixir SDK Documentation

## Overview

Relations allow you to link records between collections. BosBase supports both single and multiple relations, and provides powerful features for expanding related records and working with back-relations.

**Key Features:**
- Single and multiple relations
- Expand related records without additional requests
- Nested relation expansion (up to 6 levels)
- Back-relations for reverse lookups
- Field modifiers for append/prepend/remove operations

**Relation Field Types:**
- **Single Relation**: Links to one record (MaxSelect <= 1)
- **Multiple Relation**: Links to multiple records (MaxSelect > 1)

**Backend Behavior:**
- Relations are stored as record IDs or arrays of IDs
- Expand only includes relations the client can view (satisfies View API Rule)
- Back-relations use format: `collectionName_via_fieldName`
- Back-relation expand limited to 1000 records per field

## Setting Up Relations

### Creating a Relation Field

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Get collection
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "posts")

# Add single relation field
new_fields = collection["fields"] ++ [
  %{
    "name" => "user",
    "type" => "relation",
    "collectionId" => "users",  # ID of related collection
    "maxSelect" => 1,           # Single relation
    "required" => true
  }
]

# Add multiple relation field
updated_fields = new_fields ++ [
  %{
    "name" => "tags",
    "type" => "relation",
    "collectionId" => "tags",
    "maxSelect" => 10,          # Multiple relation (max 10)
    "minSelect" => 1,           # Minimum 1 required
    "cascadeDelete" => false    # Don't delete post when tags deleted
  }
]

# Update collection
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "posts", %{"fields" => updated_fields})
```

## Creating Records with Relations

### Single Relation

```elixir
# Create a post with a single user relation
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "My Post",
    "user" => "USER_ID"  # Single relation ID
  })
```

### Multiple Relations

```elixir
# Create a post with multiple tags
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "My Post",
    "tags" => ["TAG_ID1", "TAG_ID2", "TAG_ID3"]  # Array of IDs
  })
```

### Mixed Relations

```elixir
# Create a comment with both single and multiple relations
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.create(%{
    "message" => "Great post!",
    "post" => "POST_ID",        # Single relation
    "user" => "USER_ID",        # Single relation
    "tags" => ["TAG1", "TAG2"]  # Multiple relation
  })
```

## Updating Relations

### Replace All Relations

```elixir
# Replace all tags
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags" => ["NEW_TAG1", "NEW_TAG2"]
  })
```

### Append Relations (Using + Modifier)

```elixir
# Append tags to existing ones
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags+" => "NEW_TAG_ID"  # Append single tag
  })

# Append multiple tags
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags+" => ["TAG_ID1", "TAG_ID2"]  # Append multiple tags
  })
```

### Prepend Relations (Using + Prefix)

```elixir
# Prepend tags (tags will appear first)
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "+tags" => "PRIORITY_TAG"  # Prepend single tag
  })

# Prepend multiple tags
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "+tags" => ["TAG1", "TAG2"]  # Prepend multiple tags
  })
```

### Remove Relations (Using - Modifier)

```elixir
# Remove single tag
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags-" => "TAG_ID_TO_REMOVE"
  })

# Remove multiple tags
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags-" => ["TAG1", "TAG2"]
  })
```

### Complete Example

```elixir
# Get existing post
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID")

IO.inspect(post["tags"])  # ['tag1', 'tag2']

# Remove one tag, add two new ones
{:ok, _updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.update("POST_ID", %{
    "tags-" => "tag1",           # Remove
    "tags+" => ["tag3", "tag4"]  # Append
  })

{:ok, updated} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID")

IO.inspect(updated["tags"])  # ['tag2', 'tag3', 'tag4']
```

## Expanding Relations

The `expand` parameter allows you to fetch related records in a single request, eliminating the need for multiple API calls.

### Basic Expand

```elixir
# Get comment with expanded user
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.get_one("COMMENT_ID", %{
    "expand" => "user"
  })

IO.puts(comment["expand"]["user"]["name"])  # "John Doe"
IO.puts(comment["user"])                    # Still the ID: "USER_ID"
```

### Expand Multiple Relations

```elixir
# Expand multiple relations (comma-separated)
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.get_one("COMMENT_ID", %{
    "expand" => "user,post"
  })

IO.puts(comment["expand"]["user"]["name"])   # "John Doe"
IO.puts(comment["expand"]["post"]["title"])  # "My Post"
```

### Nested Expand (Dot Notation)

You can expand nested relations up to 6 levels deep using dot notation:

```elixir
# Expand post and its tags, and user
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.get_one("COMMENT_ID", %{
    "expand" => "user,post.tags"
  })

# Access nested expands
IO.inspect(comment["expand"]["post"]["expand"]["tags"])
# Array of tag records

# Expand even deeper
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "user,comments.user"
  })

# Access: post["expand"]["comments"][0]["expand"]["user"]
```

### Expand with List Requests

```elixir
# List comments with expanded users
{:ok, result} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "expand" => "user"
  })

Enum.each(result["items"], fn comment ->
  IO.puts(comment["message"])
  IO.puts(comment["expand"]["user"]["name"])
end)
```

### Expand Single vs Multiple Relations

```elixir
# Single relation - expand.user is a map
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "user"
  })

IO.inspect(is_map(post["expand"]["user"]))  # true

# Multiple relation - expand.tags is a list
{:ok, post_with_tags} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "tags"
  })

IO.inspect(is_list(post_with_tags["expand"]["tags"]))  # true
```

### Expand Permissions

**Important**: Only relations that satisfy the related collection's `viewRule` will be expanded. If you don't have permission to view a related record, it won't appear in the expand.

```elixir
# If you don't have view permission for user, expand.user will be nil
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.get_one("COMMENT_ID", %{
    "expand" => "user"
  })

if comment["expand"]["user"] do
  IO.puts(comment["expand"]["user"]["name"])
else
  IO.puts("User not accessible or not found")
end
```

## Back-Relations

Back-relations allow you to query and expand records that reference the current record through a relation field.

### Back-Relation Syntax

The format is: `collectionName_via_fieldName`

- `collectionName`: The collection that contains the relation field
- `fieldName`: The name of the relation field that points to your record

### Example: Posts with Comments

```elixir
# Get a post and expand all comments that reference it
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "comments_via_post"
  })

# comments_via_post is always a list (even if original field is single)
IO.inspect(post["expand"]["comments_via_post"])
# List of comment records
```

### Back-Relation with Nested Expand

```elixir
# Get post with comments, and expand each comment's user
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "comments_via_post.user"
  })

# Access nested expands
Enum.each(post["expand"]["comments_via_post"], fn comment ->
  IO.puts(comment["message"])
  IO.puts(comment["expand"]["user"]["name"])
end)
```

### Filtering with Back-Relations

```elixir
# List posts that have at least one comment containing "hello"
{:ok, result} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_list(1, 20, %{
    "filter" => ~s(comments_via_post.message ?~ "hello"),
    "expand" => "comments_via_post.user"
  })

Enum.each(result["items"], fn post ->
  IO.puts(post["title"])
  Enum.each(post["expand"]["comments_via_post"], fn comment ->
    IO.puts("  - #{comment["message"]} by #{comment["expand"]["user"]["name"]}")
  end)
end)
```

### Back-Relation Caveats

1. **Always Multiple**: Back-relations are always treated as lists, even if the original relation field is single. This is because one record can be referenced by multiple records.

   ```elixir
   # Even if comments.post is single, comments_via_post is always a list
   {:ok, post} = Client.collection(pb, "posts")
     |> Bosbase.RecordService.get_one("POST_ID", %{
       "expand" => "comments_via_post"
     })
   
   # Always a list
   IO.inspect(is_list(post["expand"]["comments_via_post"]))  # true
   ```

2. **1000 Record Limit**: Back-relation expand is limited to 1000 records per field. For larger datasets, use separate paginated requests:

   ```elixir
   # Instead of expanding all comments (if > 1000)
   {:ok, post} = Client.collection(pb, "posts")
     |> Bosbase.RecordService.get_one("POST_ID")
   
   # Fetch comments separately with pagination
   {:ok, comments} = Client.collection(pb, "comments")
     |> Bosbase.RecordService.get_list(1, 100, %{
       "filter" => ~s(post = "#{post["id"]}"),
       "expand" => "user",
       "sort" => "-created"
     })
   ```

## Complete Examples

### Example 1: Blog Post with Author and Tags

```elixir
# Create a blog post with relations
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.create(%{
    "title" => "Getting Started with BosBase",
    "content" => "Lorem ipsum...",
    "author" => "AUTHOR_ID",           # Single relation
    "tags" => ["tag1", "tag2", "tag3"] # Multiple relation
  })

# Retrieve with all relations expanded
{:ok, full_post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one(post["id"], %{
    "expand" => "author,tags"
  })

IO.puts(full_post["title"])
IO.puts("Author: #{full_post["expand"]["author"]["name"]}")
IO.puts("Tags:")
Enum.each(full_post["expand"]["tags"], fn tag ->
  IO.puts("  - #{tag["name"]}")
end)
```

### Example 2: Comment System with Nested Relations

```elixir
# Create a comment on a post
{:ok, comment} = Client.collection(pb, "comments")
  |> Bosbase.RecordService.create(%{
    "message" => "Great article!",
    "post" => "POST_ID",
    "user" => "USER_ID"
  })

# Get post with all comments and their authors
{:ok, post} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("POST_ID", %{
    "expand" => "author,comments_via_post.user"
  })

IO.puts("Post: #{post["title"]}")
IO.puts("Author: #{post["expand"]["author"]["name"]}")
IO.puts("Comments (#{length(post["expand"]["comments_via_post"])}):")
Enum.each(post["expand"]["comments_via_post"], fn comment ->
  IO.puts("  #{comment["expand"]["user"]["name"]}: #{comment["message"]}")
end)
```

### Example 3: Dynamic Tag Management

```elixir
defmodule PostManager do
  def add_tag(pb, post_id, tag_id) do
    Client.collection(pb, "posts")
      |> Bosbase.RecordService.update(post_id, %{
        "tags+" => tag_id
      })
  end

  def remove_tag(pb, post_id, tag_id) do
    Client.collection(pb, "posts")
      |> Bosbase.RecordService.update(post_id, %{
        "tags-" => tag_id
      })
  end

  def get_post_with_tags(pb, post_id) do
    Client.collection(pb, "posts")
      |> Bosbase.RecordService.get_one(post_id, %{
        "expand" => "tags"
      })
  end
end

# Usage
PostManager.add_tag(pb, "POST_ID", "NEW_TAG_ID")
{:ok, post} = PostManager.get_post_with_tags(pb, "POST_ID")
```

## Best Practices

1. **Use Expand Wisely**: Only expand relations you actually need to reduce response size and improve performance.

2. **Handle Missing Expands**: Always check if expand data exists before accessing:

   ```elixir
   if record["expand"]["user"] do
     IO.puts(record["expand"]["user"]["name"])
   end
   ```

3. **Pagination for Large Back-Relations**: If you expect more than 1000 related records, fetch them separately with pagination.

4. **Cache Expansion**: Consider caching expanded data on the client side to reduce API calls.

5. **Error Handling**: Handle cases where related records might not be accessible due to API rules.

6. **Nested Limit**: Remember that nested expands are limited to 6 levels deep.

## Performance Considerations

- **Expand Cost**: Expanding relations doesn't require additional round trips, but increases response payload size
- **Back-Relation Limit**: The 1000 record limit for back-relations prevents extremely large responses
- **Permission Checks**: Each expanded relation is checked against the collection's `viewRule`
- **Nested Depth**: Limit nested expands to avoid performance issues (max 6 levels supported)

## Related Documentation

- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Filtering and querying related records

