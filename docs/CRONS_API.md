# Crons API - Elixir SDK Documentation

## Overview

The Crons API provides endpoints for viewing and manually triggering scheduled cron jobs. All operations require superuser authentication and allow you to list registered cron jobs and execute them on-demand.

**Key Features:**
- List all registered cron jobs
- View cron job schedules (cron expressions)
- Manually trigger cron jobs
- Built-in system jobs for maintenance tasks

**Backend Endpoints:**
- `GET /api/crons` - List cron jobs
- `POST /api/crons/{jobId}` - Run cron job

**Note**: All Crons API operations require superuser authentication.

## Authentication

All Crons API operations require superuser authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

## List Cron Jobs

Returns a list of all registered cron jobs with their IDs and schedule expressions.

### Basic Usage

```elixir
# Get all cron jobs
{:ok, jobs} = Bosbase.crons()
  |> Bosbase.CronService.get_full_list(pb)

IO.inspect(jobs)
# [
#   %{"id" => "__pbLogsCleanup__", "expression" => "0 */6 * * *"},
#   %{"id" => "__pbDBOptimize__", "expression" => "0 0 * * *"},
#   %{"id" => "__pbMFACleanup__", "expression" => "0 * * * *"},
#   %{"id" => "__pbOTPCleanup__", "expression" => "0 * * * *"}
# ]
```

### Cron Job Structure

Each cron job contains:

```elixir
%{
  "id" => "string",        # Unique identifier for the job
  "expression" => "string" # Cron expression defining the schedule
}
```

### Built-in System Jobs

The following cron jobs are typically registered by default:

| Job ID | Expression | Description | Schedule |
|--------|-----------|-------------|----------|
| `__pbLogsCleanup__` | `0 */6 * * *` | Cleans up old log entries | Every 6 hours |
| `__pbDBOptimize__` | `0 0 * * *` | Optimizes database | Daily at midnight |
| `__pbMFACleanup__` | `0 * * * *` | Cleans up expired MFA records | Every hour |
| `__pbOTPCleanup__` | `0 * * * *` | Cleans up expired OTP codes | Every hour |

### Working with Cron Jobs

```elixir
# List all cron jobs
{:ok, jobs} = Bosbase.crons()
  |> Bosbase.CronService.get_full_list(pb)

# Find a specific job
logs_cleanup = Enum.find(jobs, fn job -> job["id"] == "__pbLogsCleanup__" end)

if logs_cleanup do
  IO.puts("Logs cleanup runs: #{logs_cleanup["expression"]}")
end

# Filter system jobs
system_jobs = Enum.filter(jobs, fn job -> String.starts_with?(job["id"], "__pb") end)

# Filter custom jobs
custom_jobs = Enum.reject(jobs, fn job -> String.starts_with?(job["id"], "__pb") end)
```

## Run Cron Job

Manually trigger a cron job to execute immediately.

### Basic Usage

```elixir
# Run a specific cron job
{:ok, _} = Bosbase.crons()
  |> Bosbase.CronService.run(pb, "__pbLogsCleanup__")
```

### Use Cases

```elixir
# Trigger logs cleanup manually
def cleanup_logs_now(pb) do
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbLogsCleanup__")
  IO.puts("Logs cleanup triggered")
end

# Trigger database optimization
def optimize_database(pb) do
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbDBOptimize__")
  IO.puts("Database optimization triggered")
end

# Trigger MFA cleanup
def cleanup_mfa(pb) do
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbMFACleanup__")
  IO.puts("MFA cleanup triggered")
end

# Trigger OTP cleanup
def cleanup_otp(pb) do
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbOTPCleanup__")
  IO.puts("OTP cleanup triggered")
end
```

## Cron Expression Format

Cron expressions use the standard 5-field format:

```
* * * * *
│ │ │ │ │
│ │ │ │ └─── Day of week (0-7, 0 or 7 is Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### Common Patterns

| Expression | Description |
|------------|-------------|
| `0 * * * *` | Every hour at minute 0 |
| `0 */6 * * *` | Every 6 hours |
| `0 0 * * *` | Daily at midnight |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st at midnight |
| `*/30 * * * *` | Every 30 minutes |
| `0 9 * * 1-5` | Weekdays at 9 AM |

### Supported Macros

| Macro | Equivalent Expression | Description |
|-------|----------------------|-------------|
| `@yearly` or `@annually` | `0 0 1 1 *` | Once a year |
| `@monthly` | `0 0 1 * *` | Once a month |
| `@weekly` | `0 0 * * 0` | Once a week |
| `@daily` or `@midnight` | `0 0 * * *` | Once a day |
| `@hourly` | `0 * * * *` | Once an hour |

### Expression Examples

```elixir
# Every hour
"0 * * * *"

# Every 6 hours
"0 */6 * * *"

# Daily at midnight
"0 0 * * *"

# Every 30 minutes
"*/30 * * * *"

# Weekdays at 9 AM
"0 9 * * 1-5"

# First day of every month
"0 0 1 * *"

# Using macros
"@daily"   # Same as "0 0 * * *"
"@hourly"  # Same as "0 * * * *"
```

## Complete Examples

### Example 1: Cron Job Monitor

```elixir
defmodule CronMonitor do
  def list_all_jobs(pb) do
    {:ok, jobs} = Bosbase.crons()
      |> Bosbase.CronService.get_full_list(pb)
    
    IO.puts("Found #{length(jobs)} cron jobs:")
    Enum.each(jobs, fn job ->
      IO.puts("  - #{job["id"]}: #{job["expression"]}")
    end)
    
    jobs
  end

  def run_job(pb, job_id) do
    case Bosbase.crons()
         |> Bosbase.CronService.run(pb, job_id) do
      {:ok, _} ->
        IO.puts("Successfully triggered: #{job_id}")
        true
      {:error, error} ->
        IO.puts("Failed to run #{job_id}: #{inspect(error)}")
        false
    end
  end

  def run_maintenance_jobs(pb) do
    maintenance_jobs = [
      "__pbLogsCleanup__",
      "__pbDBOptimize__",
      "__pbMFACleanup__",
      "__pbOTPCleanup__"
    ]

    Enum.each(maintenance_jobs, fn job_id ->
      IO.puts("Running #{job_id}...")
      run_job(pb, job_id)
      Process.sleep(1000)  # Wait a bit between jobs
    end)
  end
end

# Usage
jobs = CronMonitor.list_all_jobs(pb)
CronMonitor.run_maintenance_jobs(pb)
```

### Example 2: Manual Maintenance Script

```elixir
def perform_maintenance(pb) do
  IO.puts("Starting maintenance tasks...")
  
  # Cleanup old logs
  IO.puts("1. Cleaning up old logs...")
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbLogsCleanup__")
  
  # Cleanup expired MFA records
  IO.puts("2. Cleaning up expired MFA records...")
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbMFACleanup__")
  
  # Cleanup expired OTP codes
  IO.puts("3. Cleaning up expired OTP codes...")
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbOTPCleanup__")
  
  # Optimize database (run last as it may take longer)
  IO.puts("4. Optimizing database...")
  {:ok, _} = Bosbase.crons()
    |> Bosbase.CronService.run(pb, "__pbDBOptimize__")
  
  IO.puts("Maintenance tasks completed")
end
```

## Error Handling

```elixir
case Bosbase.crons()
     |> Bosbase.CronService.get_full_list(pb) do
  {:ok, jobs} ->
    IO.inspect(jobs)
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, %{status: 403}} ->
    IO.puts("Not a superuser")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end

case Bosbase.crons()
     |> Bosbase.CronService.run(pb, "__pbLogsCleanup__") do
  {:ok, _} ->
    IO.puts("Job triggered successfully")
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, %{status: 403}} ->
    IO.puts("Not a superuser")
  {:error, %{status: 404}} ->
    IO.puts("Cron job not found")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Check Job Existence**: Verify a cron job exists before trying to run it
2. **Error Handling**: Always handle errors when running cron jobs
3. **Rate Limiting**: Don't trigger cron jobs too frequently manually
4. **Monitoring**: Regularly check that expected cron jobs are registered
5. **Logging**: Log when cron jobs are manually triggered for auditing
6. **Testing**: Test cron jobs in development before running in production
7. **Documentation**: Document custom cron jobs and their purposes
8. **Scheduling**: Let the cron scheduler handle regular execution; use manual triggers sparingly

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Read-Only API**: The SDK API only allows listing and running jobs; adding/removing jobs must be done via backend hooks
- **Asynchronous Execution**: Running a cron job triggers it asynchronously; the API returns immediately
- **No Status**: The API doesn't provide execution status or history
- **System Jobs**: Built-in system jobs (prefixed with `__pb`) cannot be removed via the API

## Custom Cron Jobs

Custom cron jobs are typically registered through backend hooks (JavaScript VM plugins). The Crons API only allows you to:

- **View** all registered jobs (both system and custom)
- **Trigger** any registered job manually

To add or remove cron jobs, you need to use the backend hook system.

## Related Documentation

- [Collection API](./COLLECTION_API.md) - Collection management
- [Logs API](./LOGS_API.md) - Log viewing and analysis
- [Backups API](./BACKUPS_API.md) - Backup management

