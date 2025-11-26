# Management API Documentation - Elixir SDK

This document covers the management API capabilities available in the Elixir SDK, which correspond to the features available in the backend management UI.

> **Note**: All management API operations require superuser authentication (🔐).

## Table of Contents

- [Settings Service](#settings-service)
  - [Application Configuration](#application-configuration)
  - [Mail Configuration](#mail-configuration)
  - [Storage Configuration](#storage-configuration)
  - [Backup Configuration](#backup-configuration)
  - [Log Configuration](#log-configuration)
- [Backup Service](#backup-service)
- [Log Service](#log-service)
- [Cron Service](#cron-service)
- [Health Service](#health-service)

---

## Settings Service

The Settings Service provides comprehensive management of application settings, matching the capabilities available in the backend management UI.

**Note**: The Elixir SDK may not have all management API methods wrapped yet. You may need to use `Client.send()` directly for some operations. Check the SDK implementation for available methods.

### Application Configuration

Manage application settings including meta information, trusted proxy, rate limits, and batch configuration.

#### Get Application Settings

```elixir
# Note: This may need to be implemented via direct client.send calls
{:ok, settings} = pb
  |> Client.send("/api/settings", %{})

IO.inspect(settings["meta"])  # Application meta information
IO.inspect(settings["rateLimits"])  # Rate limit rules
```

#### Update Application Settings

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/settings", %{
    method: :patch,
    body: %{
      "meta" => %{
        "appName" => "My App",
        "appURL" => "https://example.com",
        "hideControls" => false
      },
      "trustedProxy" => %{
        "headers" => ["X-Forwarded-For"],
        "useLeftmostIP" => true
      },
      "rateLimits" => %{
        "enabled" => true,
        "rules" => [
          %{
            "label" => "api/users",
            "duration" => 3600,
            "maxRequests" => 100
          }
        ]
      },
      "batch" => %{
        "enabled" => true,
        "maxRequests" => 100,
        "interval" => 200
      }
    }
  })
```

---

### Mail Configuration

Manage SMTP email settings and sender information.

#### Get Mail Settings

```elixir
{:ok, mail_settings} = pb
  |> Client.send("/api/settings/mail", %{})

IO.puts(mail_settings["meta"]["senderName"])  # Sender name
IO.puts(mail_settings["smtp"]["host"])  # SMTP host
```

#### Update Mail Settings

Update both sender info and SMTP configuration in one call:

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/settings/mail", %{
    method: :patch,
    body: %{
      "senderName" => "My App",
      "senderAddress" => "noreply@example.com",
      "smtp" => %{
        "enabled" => true,
        "host" => "smtp.example.com",
        "port" => 587,
        "username" => "user@example.com",
        "password" => "password",
        "authMethod" => "PLAIN",
        "tls" => true,
        "localName" => "localhost"
      }
    }
  })
```

#### Test Email

Send a test email to verify SMTP configuration:

```elixir
{:ok, _result} = pb
  |> Client.send("/api/settings/mail/test", %{
    method: :post,
    body: %{
      "email" => "test@example.com",
      "template" => "verification",  # verification, password-reset, email-change, otp, login-alert
      "collection" => "_superusers"  # optional, defaults to _superusers
    }
  })
```

**Email Templates:**
- `verification` - Email verification template
- `password-reset` - Password reset template
- `email-change` - Email change confirmation template
- `otp` - One-time password template
- `login-alert` - Login alert template

---

### Storage Configuration

Manage S3 storage configuration for file storage.

#### Get Storage S3 Configuration

```elixir
{:ok, s3_config} = pb
  |> Client.send("/api/settings/storage/s3", %{})

IO.inspect(s3_config["enabled"])
IO.inspect(s3_config["bucket"])
```

#### Update Storage S3 Configuration

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/settings/storage/s3", %{
    method: :patch,
    body: %{
      "enabled" => true,
      "bucket" => "my-bucket",
      "region" => "us-east-1",
      "endpoint" => "https://s3.amazonaws.com",
      "accessKey" => "ACCESS_KEY",
      "secret" => "SECRET_KEY",
      "forcePathStyle" => false
    }
  })
```

#### Test Storage S3 Connection

```elixir
{:ok, result} = pb
  |> Client.send("/api/settings/storage/s3/test", %{
    method: :post
  })

if result["success"] do
  IO.puts("S3 connection successful")
else
  IO.puts("S3 connection failed")
end
```

---

### Backup Configuration

Manage auto-backup scheduling and S3 storage for backups.

#### Get Backup Settings

```elixir
{:ok, backup_settings} = pb
  |> Client.send("/api/settings/backups", %{})

IO.puts(backup_settings["cron"])  # Cron expression (e.g., "0 0 * * *")
IO.puts(backup_settings["cronMaxKeep"])  # Maximum backups to keep
```

#### Update Backup Settings

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/settings/backups", %{
    method: :patch,
    body: %{
      "cron" => "0 0 * * *",  # Daily at midnight (empty string to disable)
      "cronMaxKeep" => 10,  # Keep maximum 10 backups
      "s3" => %{
        "enabled" => true,
        "bucket" => "backup-bucket",
        "region" => "us-east-1",
        "endpoint" => "https://s3.amazonaws.com",
        "accessKey" => "ACCESS_KEY",
        "secret" => "SECRET_KEY",
        "forcePathStyle" => false
      }
    }
  })
```

**Common Cron Expressions:**
- `"0 0 * * *"` - Daily at midnight
- `"0 0 * * 0"` - Weekly on Sunday at midnight
- `"0 0 1 * *"` - Monthly on the 1st at midnight
- `"0 0 * * 1,3"` - Twice weekly (Monday and Wednesday)

---

### Log Configuration

Manage log retention and logging settings.

#### Get Log Settings

```elixir
{:ok, log_settings} = pb
  |> Client.send("/api/settings/logs", %{})

IO.inspect(log_settings["maxDays"])  # Retention days
IO.inspect(log_settings["minLevel"])  # Minimum log level
```

#### Update Log Settings

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/settings/logs", %{
    method: :patch,
    body: %{
      "maxDays" => 30,  # Retain logs for 30 days
      "minLevel" => 0,  # Minimum log level (negative=debug/info, 0=warning, positive=error)
      "logIP" => true,  # Log IP addresses
      "logAuthId" => true  # Log authentication IDs
    }
  })
```

**Log Levels:**
- Negative values: Debug/Info levels
- `0`: Default/Warning level
- Positive values: Error levels

---

## Backup Service

Manage application backups - create, list, upload, delete, and restore backups.

### List All Backups

```elixir
{:ok, backups} = Bosbase.backups()
  |> Bosbase.BackupService.get_full_list(pb)

Enum.each(backups, fn backup ->
  IO.puts("#{backup["key"]}: #{backup["size"]} bytes, modified: #{backup["modified"]}")
end)
```

### Create Backup

```elixir
{:ok, _result} = Bosbase.backups()
  |> Bosbase.BackupService.create(pb, "backup-2024-01-01")
# Creates a new backup with the specified basename
```

### Upload Backup

Upload an existing backup file:

```elixir
# Note: File uploads in Elixir typically require multipart form data
# This is a conceptual example - actual implementation depends on your HTTP client

# {:ok, _result} = Bosbase.backups()
#   |> Bosbase.BackupService.upload(pb, file_data, "backup-2024-01-01")
```

### Delete Backup

```elixir
:ok = Bosbase.backups()
  |> Bosbase.BackupService.delete(pb, "backup-2024-01-01")
# Deletes the specified backup file
```

### Restore Backup

```elixir
:ok = Bosbase.backups()
  |> Bosbase.BackupService.restore(pb, "backup-2024-01-01")
# Restores the application from the specified backup
```

**⚠️ Warning**: Restoring a backup will replace all current application data!

### Get Backup Download URL

```elixir
# First, get a file token
{:ok, token_response} = Bosbase.files()
  |> Bosbase.FileService.get_token(pb)

token = token_response["token"]

# Then build the download URL
url = Bosbase.backups()
  |> Bosbase.BackupService.get_download_url(pb, token, "backup-2024-01-01")

IO.puts("Download URL: #{url}")
```

---

## Log Service

Query and analyze application logs.

### List Logs

```elixir
{:ok, result} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 30, %{
    "filter" => ~s(level >= 0),
    "sort" => "-created"
  })

IO.puts("Page: #{result["page"]}")
IO.puts("Total: #{result["totalItems"]}")
Enum.each(result["items"], fn log ->
  IO.puts("[#{log["level"]}] #{log["message"]}")
end)
```

**Example with filtering:**

```elixir
# Get error logs from the last 24 hours
yesterday = DateTime.utc_now()
  |> DateTime.add(-1, :day)
  |> DateTime.to_iso8601()

{:ok, error_logs} = Bosbase.logs()
  |> Bosbase.LogService.get_list(pb, 1, 50, %{
    "filter" => ~s(level > 0 && created >= "#{yesterday}"),
    "sort" => "-created"
  })

Enum.each(error_logs["items"], fn log ->
  IO.puts("[#{log["level"]}] #{log["message"]}")
end)
```

### Get Single Log

```elixir
{:ok, log} = Bosbase.logs()
  |> Bosbase.LogService.get_one(pb, "log-id")

IO.puts("Message: #{log["message"]}")
IO.inspect(log["data"])
```

### Get Log Statistics

```elixir
{:ok, stats} = Bosbase.logs()
  |> Bosbase.LogService.get_stats(pb, %{
    "filter" => ~s(level >= 0)  # Optional filter
  })

Enum.each(stats, fn stat ->
  IO.puts("#{stat["date"]}: #{stat["total"]} requests")
end)
```

---

## Cron Service

Manage and execute cron jobs.

### List All Cron Jobs

```elixir
{:ok, cron_jobs} = Bosbase.crons()
  |> Bosbase.CronService.get_full_list(pb)

Enum.each(cron_jobs, fn job ->
  IO.puts("Job #{job["id"]}: #{job["expression"]}")
end)
```

### Run Cron Job

Manually trigger a cron job:

```elixir
:ok = Bosbase.crons()
  |> Bosbase.CronService.run(pb, "job-id")
# Executes the specified cron job immediately
```

**Example:**

```elixir
{:ok, cron_jobs} = Bosbase.crons()
  |> Bosbase.CronService.get_full_list(pb)

backup_job = Enum.find(cron_jobs, fn job ->
  String.contains?(job["id"], "backup")
end)

if backup_job do
  :ok = Bosbase.crons()
    |> Bosbase.CronService.run(pb, backup_job["id"])
  IO.puts("Backup job executed")
end
```

---

## Health Service

Check the health status of the server.

### Check Health

```elixir
{:ok, health} = Bosbase.health()
  |> Bosbase.HealthService.check(pb)

IO.puts("Status: #{health["status"]}")
IO.puts("Code: #{health["code"]}")
```

**Response:**
- `status`: "ok" or "error"
- `code`: HTTP status code (200 for healthy)

---

## Complete Example

```elixir
defmodule ManagementExample do
  def setup_application(pb) do
    # Authenticate as superuser
    {:ok, _auth} = Client.collection(pb, "_superusers")
      |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
    
    # Update application settings
    {:ok, _updated} = pb
      |> Client.send("/api/settings", %{
        method: :patch,
        body: %{
          "meta" => %{
            "appName" => "My Application",
            "appURL" => "https://example.com"
          }
        }
      })
    
    # Configure mail
    {:ok, _updated} = pb
      |> Client.send("/api/settings/mail", %{
        method: :patch,
        body: %{
          "senderName" => "My App",
          "senderAddress" => "noreply@example.com",
          "smtp" => %{
            "enabled" => true,
            "host" => "smtp.example.com",
            "port" => 587,
            "username" => "user@example.com",
            "password" => "password"
          }
        }
      })
    
    # Create backup
    {:ok, _result} = Bosbase.backups()
      |> Bosbase.BackupService.create(pb, "initial-backup")
    
    # List logs
    {:ok, logs} = Bosbase.logs()
      |> Bosbase.LogService.get_list(pb, 1, 20, %{
        "filter" => ~s(level >= 0),
        "sort" => "-created"
      })
    
    IO.puts("Setup complete!")
    IO.puts("Found #{logs["totalItems"]} log entries")
  end
end
```

## Error Handling

```elixir
case pb
     |> Client.send("/api/settings", %{
       method: :patch,
       body: settings_data
     }) do
  {:ok, _updated} ->
    IO.puts("Settings updated successfully")
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated as superuser")
  {:error, %{status: 403}} ->
    IO.puts("Permission denied")
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
```

## Related Documentation

- [Backups API](./BACKUPS_API.md) - Detailed backup operations
- [Logs API](./LOGS_API.md) - Detailed log operations
- [Crons API](./CRONS_API.md) - Detailed cron operations
- [Health API](./HEALTH_API.md) - Health check operations

