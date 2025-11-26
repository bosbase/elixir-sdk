# Realtime API - Elixir SDK Documentation

## Overview

The Realtime API enables real-time updates for collection records using **Server-Sent Events (SSE)**. It allows you to subscribe to changes in collections or specific records and receive instant notifications when records are created, updated, or deleted.

**Key Features:**
- Real-time notifications for record changes
- Collection-level and record-level subscriptions
- Automatic connection management and reconnection
- Authorization support
- Subscription options (expand, custom headers, query params)
- Event-driven architecture

**Backend Endpoints:**
- `GET /api/realtime` - Establish SSE connection
- `POST /api/realtime` - Set subscriptions

## How It Works

1. **Connection**: The SDK establishes an SSE connection to `/api/realtime`
2. **Client ID**: Server sends `PB_CONNECT` event with a unique `clientId`
3. **Subscriptions**: Client submits subscription topics via POST request
4. **Events**: Server sends events when matching records change
5. **Reconnection**: SDK automatically reconnects on connection loss

## Basic Usage

### Subscribe to Collection Changes

Subscribe to all changes in a collection:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Subscribe to all changes in the 'posts' collection
{:ok, unsubscribe_fn} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", fn event ->
    IO.puts("Action: #{event["action"]}")  # 'create', 'update', or 'delete'
    IO.inspect(event["record"])  # The record data
  end)

# Later, unsubscribe
unsubscribe_fn.()
```

### Subscribe to Specific Record

Subscribe to changes for a single record:

```elixir
# Subscribe to changes for a specific post
{:ok, unsubscribe_fn} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("RECORD_ID", fn event ->
    IO.puts("Record changed: #{inspect(event["record"])}")
    IO.puts("Action: #{event["action"]}")
  end)
```

### Multiple Subscriptions

You can subscribe multiple times to the same or different topics:

```elixir
# Subscribe to multiple records
{:ok, unsubscribe1} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("RECORD_ID_1", &handle_change/1)

{:ok, unsubscribe2} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("RECORD_ID_2", &handle_change/1)

{:ok, unsubscribe3} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", &handle_all_changes/1)

defp handle_change(event) do
  IO.puts("Change event: #{inspect(event)}")
end

defp handle_all_changes(event) do
  IO.puts("Collection-wide change: #{inspect(event)}")
end

# Unsubscribe individually
unsubscribe1.()
unsubscribe2.()
unsubscribe3.()
```

## Event Structure

Each event received contains:

```elixir
%{
  "action" => "create" | "update" | "delete",  # Action type
  "record" => %{                                # Record data
    "id" => "RECORD_ID",
    "collectionId" => "COLLECTION_ID",
    "collectionName" => "collection_name",
    "created" => "2023-01-01 00:00:00.000Z",
    "updated" => "2023-01-01 00:00:00.000Z",
    # ... other fields
  }
}
```

### PB_CONNECT Event

When the connection is established, you receive a `PB_CONNECT` event:

```elixir
{:ok, _unsubscribe} = Bosbase.realtime()
  |> Bosbase.RealtimeService.subscribe(pb, "PB_CONNECT", fn event ->
    IO.puts("Connected! Client ID: #{event["clientId"]}")
    # event["clientId"] - unique client identifier
  end)
```

## Subscription Topics

### Collection-Level Subscription

Subscribe to all changes in a collection:

```elixir
# Wildcard subscription - all records in collection
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler)
```

**Access Control**: Uses the collection's `ListRule` to determine if the subscriber has access to receive events.

### Record-Level Subscription

Subscribe to changes for a specific record:

```elixir
# Specific record subscription
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("RECORD_ID", handler)
```

**Access Control**: Uses the collection's `ViewRule` to determine if the subscriber has access to receive events.

## Subscription Options

You can pass additional options when subscribing:

```elixir
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler, %{
    # Query parameters (for API rule filtering)
    query: %{
      "filter" => ~s(status = "published"),
      "expand" => "author"
    },
    # Custom headers
    headers: %{
      "X-Custom-Header" => "value"
    }
  })
```

### Expand Relations

Expand relations in the event data:

```elixir
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("RECORD_ID", fn event ->
    author = get_in(event, ["record", "expand", "author"])
    IO.inspect(author)  # Author relation expanded
  end, %{
    query: %{
      "expand" => "author,categories"
    }
  })
```

### Filter with Query Parameters

Use query parameters for API rule filtering:

```elixir
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler, %{
    query: %{
      "filter" => ~s(status = "published")
    }
  })
```

## Unsubscribing

### Unsubscribe from Specific Topic

```elixir
# Remove all subscriptions for a specific record
:ok = Client.collection(pb, "posts")
  |> Bosbase.RecordService.unsubscribe("RECORD_ID")

# Remove all wildcard subscriptions for the collection
:ok = Client.collection(pb, "posts")
  |> Bosbase.RecordService.unsubscribe("*")
```

### Unsubscribe from All

```elixir
# Unsubscribe from all subscriptions in the collection
:ok = Client.collection(pb, "posts")
  |> Bosbase.RecordService.unsubscribe()

# Or unsubscribe from everything
:ok = Bosbase.realtime()
  |> Bosbase.RealtimeService.unsubscribe(pb)
```

### Unsubscribe Using Returned Function

```elixir
{:ok, unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler)

# Later...
unsubscribe.()  # Removes this specific subscription
```

## Connection Management

### Connection Status

Check if the realtime connection is established:

```elixir
# The SDK manages connection state internally
# Connection is established automatically when subscribing
```

### Disconnect Handler

Handle disconnection events:

```elixir
# The SDK automatically handles reconnection
# You can monitor connection state through event callbacks
```

### Automatic Reconnection

The SDK automatically:
- Reconnects when the connection is lost
- Resubmits all active subscriptions
- Handles network interruptions gracefully
- Closes connection after 5 minutes of inactivity (server-side timeout)

## Authorization

### Authenticated Subscriptions

Subscriptions respect authentication. If you're authenticated, events are filtered based on your permissions:

```elixir
# Authenticate first
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password")

# Now subscribe - events will respect your permissions
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler)
```

### Authorization Rules

- **Collection-level (`*`)**: Uses `ListRule` to determine access
- **Record-level**: Uses `ViewRule` to determine access
- **Superusers**: Can receive all events (if rules allow)
- **Guests**: Only receive events they have permission to see

### Auth State Changes

When authentication state changes, you may need to resubscribe:

```elixir
# After login/logout, resubscribe to update permissions
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password")

# Re-subscribe to update auth state in realtime connection
{:ok, _unsubscribe} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.subscribe("*", handler)
```

## Complete Examples

### Example 1: Real-time Chat

```elixir
defmodule ChatRoom do
  def subscribe_to_room(pb, room_id) do
    {:ok, unsubscribe} = Client.collection(pb, "messages")
      |> Bosbase.RecordService.subscribe("*", fn event ->
        # Filter for this room only
        if event["record"]["roomId"] == room_id do
          case event["action"] do
            "create" -> display_message(event["record"])
            "delete" -> remove_message(event["record"]["id"])
            _ -> :ok
          end
        end
      end, %{
        query: %{
          "filter" => ~s(roomId = "#{room_id}")
        }
      })
    
    unsubscribe
  end
end

# Usage
unsubscribe = ChatRoom.subscribe_to_room(pb, "ROOM_ID")

# Cleanup
unsubscribe.()
```

### Example 2: Real-time Dashboard

```elixir
defmodule Dashboard do
  def setup(pb) do
    # Posts updates
    {:ok, _unsub1} = Client.collection(pb, "posts")
      |> Bosbase.RecordService.subscribe("*", fn event ->
        case event["action"] do
          "create" -> add_post_to_feed(event["record"])
          "update" -> update_post_in_feed(event["record"])
          _ -> :ok
        end
      end, %{
        query: %{
          "filter" => ~s(status = "published"),
          "expand" => "author"
        }
      })

    # Comments updates
    {:ok, _unsub2} = Client.collection(pb, "comments")
      |> Bosbase.RecordService.subscribe("*", fn event ->
        update_comments_count(event["record"]["postId"])
      end, %{
        query: %{
          "expand" => "user"
        }
      })
  end
end

Dashboard.setup(pb)
```

## Error Handling

```elixir
case Client.collection(pb, "posts")
     |> Bosbase.RecordService.subscribe("*", handler) do
  {:ok, unsubscribe} ->
    # Subscription successful
    unsubscribe
  {:error, %{status: 403}} ->
    IO.puts("Permission denied")
    nil
  {:error, %{status: 404}} ->
    IO.puts("Collection not found")
    nil
  {:error, error} ->
    IO.puts("Subscription error: #{inspect(error)}")
    nil
end
```

## Best Practices

1. **Unsubscribe When Done**: Always unsubscribe when components unmount or subscriptions are no longer needed
2. **Handle Disconnections**: The SDK handles reconnection automatically
3. **Filter Server-Side**: Use query parameters to filter events server-side when possible
4. **Limit Subscriptions**: Don't subscribe to more collections than necessary
5. **Use Record-Level When Possible**: Prefer record-level subscriptions over collection-level when you only need specific records
6. **Monitor Connection**: Track connection state for debugging and user feedback
7. **Handle Errors**: Wrap subscriptions in error handling
8. **Respect Permissions**: Understand that events respect API rules and permissions

## Limitations

- **Maximum Subscriptions**: Up to 1000 subscriptions per client
- **Topic Length**: Maximum 2500 characters per topic
- **Idle Timeout**: Connection closes after 5 minutes of inactivity
- **Network Dependency**: Requires stable network connection
- **SSE Support**: Requires SSE support in HTTP client

## Related Documentation

- [API Records](./API_RECORDS.md) - CRUD operations
- [Collections](./COLLECTIONS.md) - Collection configuration
- [API Rules and Filters](./API_RULES_AND_FILTERS.md) - Understanding API rules

