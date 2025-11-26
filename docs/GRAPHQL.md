# GraphQL - Elixir SDK Documentation

Use `Bosbase.GraphQLService.query()` to call `/api/graphql` with your current auth token. It returns `%{"data" => data, "errors" => errors, "extensions" => extensions}`.

> Authentication: the GraphQL endpoint is **superuser-only**. Authenticate as a superuser before calling GraphQL, e.g. `Bosbase.RecordService.auth_with_password(pb, "_superusers", email, password)`.

## Single-table query

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

query = """
  query ActiveUsers($limit: Int!) {
    records(collection: "users", perPage: $limit, filter: "status = true") {
      items { id data }
    }
  }
"""

variables = %{"limit" => 5}

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, query, variables)

IO.inspect(result["data"])
IO.inspect(result["errors"])
```

## Multi-table join via expands

```elixir
query = """
  query PostsWithAuthors {
    records(
      collection: "posts",
      expand: ["author", "author.profile"],
      sort: "-created"
    ) {
      items {
        id
        data  # expanded relations live under data.expand
      }
    }
  }
"""

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, query)

# Access expanded data
Enum.each(result["data"]["records"]["items"], fn item ->
  author = get_in(item, ["data", "expand", "author"])
  IO.puts("Author: #{author["name"]}")
end)
```

## Conditional query with variables

```elixir
query = """
  query FilteredOrders($minTotal: Float!, $state: String!) {
    records(
      collection: "orders",
      filter: "total >= $minTotal && status = $state",
      sort: "created"
    ) {
      items { id data }
    }
  }
"""

variables = %{
  "minTotal" => 100.0,
  "state" => "paid"
}

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, query, variables)
```

Use the `filter`, `sort`, `page`, `perPage`, and `expand` arguments to mirror REST list behavior while keeping query logic in GraphQL.

## Create a record

```elixir
mutation = """
  mutation CreatePost($data: JSON!) {
    createRecord(collection: "posts", data: $data, expand: ["author"]) {
      id
      data
    }
  }
"""

data = %{
  "title" => "Hello",
  "author" => "USER_ID"
}

variables = %{"data" => data}

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, mutation, variables)

IO.inspect(result["data"]["createRecord"])
```

## Update a record

```elixir
mutation = """
  mutation UpdatePost($id: ID!, $data: JSON!) {
    updateRecord(collection: "posts", id: $id, data: $data) {
      id
      data
    }
  }
"""

variables = %{
  "id" => "POST_ID",
  "data" => %{"title" => "Updated title"}
}

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, mutation, variables)
```

## Delete a record

```elixir
mutation = """
  mutation DeletePost($id: ID!) {
    deleteRecord(collection: "posts", id: $id)
  }
"""

variables = %{"id" => "POST_ID"}

{:ok, result} = Bosbase.graphql()
  |> Bosbase.GraphQLService.query(pb, mutation, variables)
```

## Complete Examples

### Example 1: Complex Query with Relations

```elixir
defmodule GraphQLQueries do
  def get_posts_with_authors(pb) do
    query = """
      query PostsWithDetails {
        records(
          collection: "posts",
          expand: ["author", "categories"],
          filter: "published = true",
          sort: "-created",
          perPage: 10
        ) {
          items {
            id
            data
          }
          totalItems
        }
      }
    """

    case Bosbase.graphql()
         |> Bosbase.GraphQLService.query(pb, query) do
      {:ok, result} ->
        result["data"]["records"]["items"]
      {:error, error} ->
        IO.puts("Error: #{inspect(error)}")
        []
    end
  end
end

# Usage
pb = Client.new("http://127.0.0.1:8090")
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

posts = GraphQLQueries.get_posts_with_authors(pb)
Enum.each(posts, fn post ->
  IO.puts("Post: #{get_in(post, ["data", "title"])}")
end)
```

## Error Handling

```elixir
case Bosbase.graphql()
     |> Bosbase.GraphQLService.query(pb, query, variables) do
  {:ok, result} ->
    if result["errors"] do
      IO.puts("GraphQL errors: #{inspect(result["errors"])}")
    else
      IO.inspect(result["data"])
    end
  {:error, %{status: 401}} ->
    IO.puts("Authentication required")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Related Documentation

- [API Records](./API_RECORDS.md) - REST API for records
- [Authentication](./AUTHENTICATION.md) - User authentication

