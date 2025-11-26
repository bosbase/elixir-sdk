# Pub/Sub API - Elixir SDK Documentation

BosBase now exposes a lightweight WebSocket-based publish/subscribe channel so SDK users can push and receive custom messages. The Go backend uses the `ws` transport and persists each published payload in the `_pubsub_messages` table so every node in a cluster can replay and fan-out messages to its local subscribers.

- Endpoint: `/api/pubsub` (WebSocket)
- Auth: the SDK automatically forwards `authStore.token` as a `token` query parameter; cookie-based auth also works. Anonymous clients may subscribe, but publishing requires an authenticated token.
- Reliability: automatic reconnect with topic re-subscription; messages are stored in the database and broadcasted to all connected nodes.

## Quick Start

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Subscribe to a topic
{:ok, unsubscribe_fn} = Bosbase.pubsub()
  |> Bosbase.PubSubService.subscribe(pb, "chat/general", fn msg ->
    IO.inspect(msg["topic"])
    IO.inspect(msg["data"])
  end)

# Publish to a topic (resolves when the server stores and accepts it)
{:ok, ack} = Bosbase.pubsub()
  |> Bosbase.PubSubService.publish(pb, "chat/general", %{"text" => "Hello team!"})

IO.puts("Published at: #{ack["created"]}")

# Later, stop listening
unsubscribe_fn.()
```

## API Surface

- `Bosbase.PubSubService.publish(client, topic, data)` → `{:ok, %{"id" => id, "topic" => topic, "created" => created}}`
- `Bosbase.PubSubService.subscribe(client, topic, handler)` → `{:ok, fn -> :ok end}` (returns unsubscribe function)
- `Bosbase.PubSubService.unsubscribe(client, topic)` → `:ok` (omit `topic` to drop all topics)

## Notes for Clusters

- Messages are written to `_pubsub_messages` with a timestamp; every running node polls the table and pushes new rows to its connected WebSocket clients.
- Old pub/sub rows are cleaned up automatically after a day to keep the table small.
- If a node restarts, it resumes from the latest message and replays new rows as they are inserted, so connected clients on other nodes stay in sync.

## Complete Examples

### Example 1: Chat Application

```elixir
defmodule ChatClient do
  def start(pb, room) do
    # Subscribe to chat room
    {:ok, unsubscribe} = Bosbase.pubsub()
      |> Bosbase.PubSubService.subscribe(pb, "chat/#{room}", fn msg ->
        handle_message(msg)
      end)
    
    # Return unsubscribe function for cleanup
    unsubscribe
  end

  def send_message(pb, room, text) do
    {:ok, ack} = Bosbase.pubsub()
      |> Bosbase.PubSubService.publish(pb, "chat/#{room}", %{
        "text" => text,
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      })
    
    IO.puts("Message sent at: #{ack["created"]}")
  end

  defp handle_message(msg) do
    IO.puts("[#{msg["topic"]}] #{msg["data"]["text"]}")
  end
end

# Usage
pb = Client.new("http://127.0.0.1:8090")
unsubscribe = ChatClient.start(pb, "general")
ChatClient.send_message(pb, "general", "Hello everyone!")
# ... later
unsubscribe.()
```

### Example 2: Real-time Notifications

```elixir
defmodule NotificationService do
  def subscribe_to_user_notifications(pb, user_id, callback) do
    topic = "notifications/#{user_id}"
    
    {:ok, unsubscribe} = Bosbase.pubsub()
      |> Bosbase.PubSubService.subscribe(pb, topic, fn msg ->
        callback.(msg["data"])
      end)
    
    unsubscribe
  end

  def send_notification(pb, user_id, notification) do
    topic = "notifications/#{user_id}"
    
    {:ok, _ack} = Bosbase.pubsub()
      |> Bosbase.PubSubService.publish(pb, topic, notification)
  end
end

# Usage
pb = Client.new("http://127.0.0.1:8090")

# Subscribe to notifications
unsubscribe = NotificationService.subscribe_to_user_notifications(
  pb,
  "user123",
  fn notification ->
    IO.puts("New notification: #{notification["title"]}")
  end
)

# Send notification
NotificationService.send_notification(pb, "user123", %{
  "title" => "New message",
  "body" => "You have a new message",
  "type" => "message"
})
```

### Example 3: Multi-topic Subscription

```elixir
defmodule MultiTopicSubscriber do
  def subscribe_to_multiple_topics(pb, topics, handler) do
    unsubscribers = Enum.map(topics, fn topic ->
      {:ok, unsubscribe} = Bosbase.pubsub()
        |> Bosbase.PubSubService.subscribe(pb, topic, handler)
      unsubscribe
    end)
    
    # Return a function that unsubscribes from all topics
    fn ->
      Enum.each(unsubscribers, fn unsubscribe -> unsubscribe.() end)
    end
  end
end

# Usage
pb = Client.new("http://127.0.0.1:8090")

unsubscribe_all = MultiTopicSubscriber.subscribe_to_multiple_topics(
  pb,
  ["chat/general", "chat/tech", "notifications"],
  fn msg ->
    IO.puts("Received on #{msg["topic"]}: #{inspect(msg["data"])}")
  end
)

# Later, unsubscribe from all
unsubscribe_all.()
```

## Error Handling

```elixir
case Bosbase.pubsub()
     |> Bosbase.PubSubService.subscribe(pb, "chat/general", fn msg -> 
       IO.inspect(msg)
     end) do
  {:ok, unsubscribe} ->
    # Subscription successful
    unsubscribe
  {:error, error} ->
    IO.puts("Failed to subscribe: #{inspect(error)}")
    nil
end

case Bosbase.pubsub()
     |> Bosbase.PubSubService.publish(pb, "chat/general", %{"text" => "Hello"}) do
  {:ok, ack} ->
    IO.puts("Published successfully: #{ack["id"]}")
  {:error, error} ->
    IO.puts("Failed to publish: #{inspect(error)}")
end
```

## Best Practices

1. **Authentication**: Ensure you're authenticated if you need to publish messages
2. **Error Handling**: Always handle errors when subscribing or publishing
3. **Cleanup**: Always call the unsubscribe function when done
4. **Topic Naming**: Use clear, hierarchical topic names (e.g., `chat/general`, `notifications/user123`)
5. **Message Format**: Use consistent message formats for easier handling
6. **Reconnection**: The SDK handles automatic reconnection, but be aware of potential message loss during disconnections
7. **Rate Limiting**: Be mindful of publish rate limits
8. **Message Size**: Keep messages reasonably sized for better performance

## Limitations

- **Publishing Requires Auth**: Anonymous clients can subscribe but cannot publish
- **WebSocket Connection**: Requires a persistent WebSocket connection
- **Message Persistence**: Messages are stored in the database for a day
- **Cluster Behavior**: Messages are eventually consistent across cluster nodes

## Related Documentation

- [Realtime API](./REALTIME.md) - Real-time collection subscriptions
- [Authentication](./AUTHENTICATION.md) - User authentication

