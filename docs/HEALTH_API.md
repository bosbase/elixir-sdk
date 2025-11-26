# Health API - Elixir SDK Documentation

## Overview

The Health API provides a simple endpoint to check the health status of the server. It returns basic health information and, when authenticated as a superuser, provides additional diagnostic information about the server state.

**Key Features:**
- No authentication required for basic health check
- Superuser authentication provides additional diagnostic data
- Lightweight endpoint for monitoring and health checks
- Supports both GET and HEAD methods

**Backend Endpoints:**
- `GET /api/health` - Check health status
- `HEAD /api/health` - Check health status (HEAD method)

**Note**: The health endpoint is publicly accessible, but superuser authentication provides additional information.

## Authentication

Basic health checks do not require authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Basic health check (no auth required)
{:ok, health} = Bosbase.health()
  |> Bosbase.HealthService.check(pb)
```

For additional diagnostic information, authenticate as a superuser:

```elixir
# Authenticate as superuser for extended health data
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

{:ok, health} = Bosbase.health()
  |> Bosbase.HealthService.check(pb)
```

## Health Check Response Structure

### Basic Response (Guest/Regular User)

```elixir
%{
  "code" => 200,
  "message" => "API is healthy.",
  "data" => %{}
}
```

### Superuser Response

```elixir
%{
  "code" => 200,
  "message" => "API is healthy.",
  "data" => %{
    "canBackup" => true,           # Whether backup operations are allowed
    "realIP" => "192.168.1.100",   # Real IP address of the client
    "requireS3" => false,          # Whether S3 storage is required
    "possibleProxyHeader" => ""    # Detected proxy header (if behind reverse proxy)
  }
}
```

## Check Health Status

Returns the health status of the API server.

### Basic Usage

```elixir
# Simple health check
{:ok, health} = Bosbase.health()
  |> Bosbase.HealthService.check(pb)

IO.puts(health["message"]) # "API is healthy."
IO.puts(health["code"])    # 200
```

### With Superuser Authentication

```elixir
# Authenticate as superuser first
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Get extended health information
{:ok, health} = Bosbase.health()
  |> Bosbase.HealthService.check(pb)

IO.inspect(health["data"]["canBackup"])           # true/false
IO.inspect(health["data"]["realIP"])              # "192.168.1.100"
IO.inspect(health["data"]["requireS3"])           # false
IO.inspect(health["data"]["possibleProxyHeader"]) # "" or header name
```

## Response Fields

### Common Fields (All Users)

| Field | Type | Description |
|-------|------|-------------|
| `code` | integer | HTTP status code (always 200 for healthy server) |
| `message` | string | Health status message ("API is healthy.") |
| `data` | map | Health data (empty for non-superusers, populated for superusers) |

### Superuser-Only Fields (in `data`)

| Field | Type | Description |
|-------|------|-------------|
| `canBackup` | boolean | `true` if backup/restore operations can be performed, `false` if a backup/restore is currently in progress |
| `realIP` | string | The real IP address of the client (useful when behind proxies) |
| `requireS3` | boolean | `true` if S3 storage is required (local fallback disabled), `false` otherwise |
| `possibleProxyHeader` | string | Detected proxy header name (e.g., "X-Forwarded-For", "CF-Connecting-IP") if the server appears to be behind a reverse proxy, empty string otherwise |

## Use Cases

### 1. Basic Health Monitoring

```elixir
defmodule HealthMonitor do
  def check_server_health(pb) do
    case Bosbase.health()
         |> Bosbase.HealthService.check(pb) do
      {:ok, health} ->
        if health["code"] == 200 && health["message"] == "API is healthy." do
          IO.puts("✓ Server is healthy")
          true
        else
          IO.puts("✗ Server health check failed")
          false
        end
      {:error, _error} ->
        IO.puts("✗ Health check error")
        false
    end
  end
end

# Use in monitoring
# Process.send_after(self(), :check_health, 60_000)  # Check every minute
```

### 2. Backup Readiness Check

```elixir
def can_perform_backup(pb) do
  # Authenticate as superuser
  case Client.collection(pb, "_superusers")
       |> Bosbase.RecordService.auth_with_password("admin@example.com", "password") do
    {:ok, _auth} ->
      case Bosbase.health()
           |> Bosbase.HealthService.check(pb) do
        {:ok, health} ->
          if health["data"]["canBackup"] == false do
            IO.puts("⚠️ Backup operation is currently in progress")
            false
          else
            IO.puts("✓ Backup operations are allowed")
            true
          end
        {:error, error} ->
          IO.puts("Failed to check backup readiness: #{inspect(error)}")
          false
      end
    {:error, _error} ->
      false
  end
end

# Use before creating backups
if can_perform_backup(pb) do
  # Create backup
end
```

## Error Handling

```elixir
case Bosbase.health()
     |> Bosbase.HealthService.check(pb) do
  {:ok, health} ->
    IO.puts("Health check successful: #{health["message"]}")
  {:error, %{status: status} = error} ->
    IO.puts("Health check failed with status #{status}: #{inspect(error)}")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Monitoring**: Use health checks for regular monitoring (e.g., every 30-60 seconds)
2. **Load Balancers**: Configure load balancers to use the health endpoint for health checks
3. **Pre-flight Checks**: Check `canBackup` before initiating backup operations
4. **Error Handling**: Always handle errors gracefully as the server may be down
5. **Rate Limiting**: Don't poll the health endpoint too frequently (avoid spamming)
6. **Caching**: Consider caching health check results for a few seconds to reduce load
7. **Logging**: Log health check results for troubleshooting and monitoring
8. **Alerting**: Set up alerts for consecutive health check failures
9. **Superuser Auth**: Only authenticate as superuser when you need diagnostic information
10. **Proxy Configuration**: Use `possibleProxyHeader` to detect and configure reverse proxy settings

## Response Codes

| Code | Meaning |
|------|---------|
| 200 | Server is healthy |
| Network Error | Server is unreachable or down |

## Limitations

- **No Detailed Metrics**: The health endpoint does not provide detailed performance metrics
- **Basic Status Only**: Returns basic status, not detailed system information
- **Superuser Required**: Extended diagnostics require superuser authentication
- **No Historical Data**: Only returns current status, no historical health data

## Related Documentation

- [Backups API](./BACKUPS_API.md) - Using `canBackup` to check backup readiness
- [Authentication](./AUTHENTICATION.md) - Superuser authentication
- [Settings API](./MANAGEMENT_API.md) - Configuring trusted proxy settings

