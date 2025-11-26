# Logs API - Elixir SDK Documentation

## Overview

The Logs API provides endpoints for viewing and analyzing application logs. All operations require superuser authentication and allow you to query request logs, filter by various criteria, and get aggregated statistics.

**Key Features:**
- List and paginate logs
- View individual log entries
- Filter logs by status, URL, method, IP, etc.
- Sort logs by various fields
- Get hourly aggregated statistics
- Filter statistics by criteria

**Backend Endpoints:**
- `GET /api/logs` - List logs
- `GET /api/logs/{id}` - View log
- `GET /api/logs/stats` - Get statistics

**Note**: All Logs API operations require superuser authentication.

## Authentication

All Logs API operations require superuser authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

## List Logs

Returns a paginated list of logs with support for filtering and sorting.

### Basic Usage

```elixir
# Basic list
{:ok, result} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 30)

IO.inspect(result["page"])        # 1
IO.inspect(result["perPage"])     # 30
IO.inspect(result["totalItems"])  # Total logs count
IO.inspect(result["items"])       # List of log entries
```

### Log Entry Structure

Each log entry contains:

```elixir
%{
  "id" => "ai5z3aoed6809au",
  "created" => "2024-10-27 09:28:19.524Z",
  "level" => 0,
  "message" => "GET /api/collections/posts/records",
  "data" => %{
    "auth" => "_superusers",
    "execTime" => 2.392327,
    "method" => "GET",
    "referer" => "http://localhost:8090/_/",
    "remoteIP" => "127.0.0.1",
    "status" => 200,
    "type" => "request",
    "url" => "/api/collections/posts/records?page=1",
    "userAgent" => "Mozilla/5.0...",
    "userIP" => "127.0.0.1"
  }
}
```

### Filtering Logs

```elixir
# Filter by HTTP status code
{:ok, error_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.status >= 400))

# Filter by method
{:ok, get_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.method = "GET"))

# Filter by URL pattern
{:ok, api_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.url ~ "/api/"))

# Filter by IP address
{:ok, ip_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.remoteIP = "127.0.0.1"))

# Filter by execution time (slow requests)
{:ok, slow_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.execTime > 1.0))

# Filter by log level
{:ok, error_level_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(level > 0))

# Filter by date range
{:ok, recent_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(created >= "2024-10-27 00:00:00"))
```

### Complex Filters

```elixir
# Multiple conditions
{:ok, complex_filter} = Bosbase.logs()
  |> Bosbase.LogService.get_list(
    pb,
    1,
    50,
    ~s(data.status >= 400 && data.method = "POST" && data.execTime > 0.5)
  )

# Exclude superuser requests
{:ok, user_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.auth != "_superusers"))

# Specific endpoint errors
{:ok, endpoint_errors} = Bosbase.logs()
  |> Bosbase.LogService.get_list(
    pb,
    1,
    50,
    ~s(data.url ~ "/api/collections/posts/records" && data.status >= 400)
  )

# Errors or slow requests
{:ok, problems} = Bosbase.logs()
  |> Bosbase.LogService.get_list(
    pb,
    1,
    50,
    ~s(data.status >= 400 || data.execTime > 2.0)
  )
```

### Sorting Logs

```elixir
# Sort by creation date (newest first)
{:ok, recent} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, "", "-created")

# Sort by execution time (slowest first)
{:ok, slowest} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, "", "-data.execTime")

# Sort by status code
{:ok, by_status} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, "", "data.status")

# Sort by rowid (most efficient)
{:ok, by_rowid} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, "", "-rowid")

# Multiple sort fields
{:ok, multi_sort} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, "", "-created,level")
```

## View Log

Retrieve a single log entry by ID:

```elixir
# Get specific log
{:ok, log} = Bosbase.logs()
  |> Bosbase.LogService.get_one(pb, "ai5z3aoed6809au")

IO.inspect(log["message"])
IO.inspect(log["data"]["status"])
IO.inspect(log["data"]["execTime"])
```

### Log Details

```elixir
def analyze_log(pb, log_id) do
  {:ok, log} = Bosbase.logs()
    |> Bosbase.LogService.get_one(pb, log_id)
  
  IO.puts("Log ID: #{log["id"]}")
  IO.puts("Created: #{log["created"]}")
  IO.puts("Level: #{log["level"]}")
  IO.puts("Message: #{log["message"]}")
  
  if log["data"]["type"] == "request" do
    IO.puts("Method: #{log["data"]["method"]}")
    IO.puts("URL: #{log["data"]["url"]}")
    IO.puts("Status: #{log["data"]["status"]}")
    IO.puts("Execution Time: #{log["data"]["execTime"]} ms")
    IO.puts("Remote IP: #{log["data"]["remoteIP"]}")
    IO.puts("User Agent: #{log["data"]["userAgent"]}")
    IO.puts("Auth Collection: #{log["data"]["auth"]}")
  end
end
```

## Logs Statistics

Get hourly aggregated statistics for logs:

### Basic Usage

```elixir
# Get all statistics
{:ok, stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb)

# Each stat entry contains:
# %{"total" => 4, "date" => "2022-06-01 19:00:00.000"}
```

### Filtered Statistics

```elixir
# Statistics for errors only
{:ok, error_stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb, %{"filter" => ~s(data.status >= 400)})

# Statistics for specific endpoint
{:ok, endpoint_stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(
    pb,
    %{"filter" => ~s(data.url ~ "/api/collections/posts/records")}
  )

# Statistics for slow requests
{:ok, slow_stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb, %{"filter" => ~s(data.execTime > 1.0)})

# Statistics excluding superuser requests
{:ok, user_stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb, %{"filter" => ~s(data.auth != "_superusers")})
```

## Filter Syntax

Logs support filtering with a flexible syntax similar to records filtering.

### Supported Fields

**Direct Fields:**
- `id` - Log ID
- `created` - Creation timestamp
- `updated` - Update timestamp
- `level` - Log level (0 = info, higher = warnings/errors)
- `message` - Log message

**Data Fields (nested):**
- `data.status` - HTTP status code
- `data.method` - HTTP method (GET, POST, etc.)
- `data.url` - Request URL
- `data.execTime` - Execution time in seconds
- `data.remoteIP` - Remote IP address
- `data.userIP` - User IP address
- `data.userAgent` - User agent string
- `data.referer` - Referer header
- `data.auth` - Auth collection ID
- `data.type` - Log type (usually "request")

### Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Equal | `data.status = 200` |
| `!=` | Not equal | `data.status != 200` |
| `>` | Greater than | `data.status > 400` |
| `>=` | Greater than or equal | `data.status >= 400` |
| `<` | Less than | `data.execTime < 0.5` |
| `<=` | Less than or equal | `data.execTime <= 1.0` |
| `~` | Contains/Like | `data.url ~ "/api/"` |
| `!~` | Not contains | `data.url !~ "/admin/"` |

### Logical Operators

- `&&` - AND
- `||` - OR
- `()` - Grouping

## Complete Examples

### Example 1: Error Monitoring Dashboard

```elixir
defmodule ErrorMonitor do
  def get_error_metrics(pb) do
    # Get error logs from last 24 hours
    yesterday = DateTime.utc_now()
      |> DateTime.add(-1, :day)
      |> DateTime.to_iso8601()
      |> String.slice(0, 10)
    
    date_filter = ~s(created >= "#{yesterday} 00:00:00")
    
    # 4xx errors
    {:ok, client_errors} = Bosbase.logs()
      |> Bosbase.LogService.get_list(
        pb,
        1,
        100,
        ~s(#{date_filter} && data.status >= 400 && data.status < 500),
        "-created"
      )
    
    # 5xx errors
    {:ok, server_errors} = Bosbase.logs()
      |> Bosbase.LogService.get_list(
        pb,
        1,
        100,
        ~s(#{date_filter} && data.status >= 500),
        "-created"
      )
    
    # Get hourly statistics
    {:ok, error_stats} = Bosbase.logs()
      |> Bosbase.LogService.get_stats(
        pb,
        %{"filter" => ~s(#{date_filter} && data.status >= 400)}
      )
    
    %{
      client_errors: client_errors["items"],
      server_errors: server_errors["items"],
      stats: error_stats
    }
  end
end
```

### Example 2: Performance Analysis

```elixir
def analyze_performance(pb) do
  # Get slow requests
  {:ok, slow_requests} = Bosbase.logs()
    |> Bosbase.LogService.get_list(
      pb,
      1,
      50,
      ~s(data.execTime > 1.0),
      "-data.execTime"
    )
  
  # Analyze by endpoint
  endpoint_stats = Enum.reduce(slow_requests["items"], %{}, fn log, acc ->
    url = log["data"]["url"]
      |> String.split("?")
      |> List.first()
    
    current = Map.get(acc, url, %{"count" => 0, "totalTime" => 0, "maxTime" => 0})
    
    updated = current
      |> Map.update!("count", &(&1 + 1))
      |> Map.update!("totalTime", &(&1 + log["data"]["execTime"]))
      |> Map.update!("maxTime", fn max -> 
        max(max, log["data"]["execTime"])
      end)
    
    Map.put(acc, url, updated)
  end)
  
  # Calculate averages
  Enum.map(endpoint_stats, fn {url, stats} ->
    avg_time = stats["totalTime"] / stats["count"]
    {url, Map.put(stats, "avgTime", avg_time)}
  end)
end
```

## Error Handling

```elixir
case Bosbase.logs()
     |> Bosbase.LogService.get_list(pb, 1, 50, ~s(data.status >= 400)) do
  {:ok, logs} ->
    IO.inspect(logs["items"])
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, %{status: 403}} ->
    IO.puts("Not a superuser")
  {:error, %{status: 400} = error} ->
    IO.puts("Invalid filter: #{inspect(error)}")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Use Filters**: Always use filters to narrow down results, especially for large log datasets
2. **Paginate**: Use pagination instead of fetching all logs at once
3. **Efficient Sorting**: Use `-rowid` for default sorting (most efficient)
4. **Filter Statistics**: Always filter statistics for meaningful insights
5. **Monitor Errors**: Regularly check for 4xx/5xx errors
6. **Performance Tracking**: Monitor execution times for slow endpoints
7. **Security Auditing**: Track authentication failures and suspicious activity
8. **Archive Old Logs**: Consider deleting or archiving old logs to maintain performance

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Data Fields**: Only fields in the `data` object are filterable
- **Statistics**: Statistics are aggregated hourly
- **Performance**: Large log datasets may be slow to query
- **Storage**: Logs accumulate over time and may need periodic cleanup

## Log Levels

- **0**: Info (normal requests)
- **> 0**: Warnings/Errors (non-200 status codes, exceptions, etc.)

Higher values typically indicate more severe issues.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - User authentication
- [API Records](./API_RECORDS.md) - Record operations
- [Collection API](./COLLECTION_API.md) - Collection management

