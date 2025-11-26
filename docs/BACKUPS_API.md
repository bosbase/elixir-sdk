# Backups API - Elixir SDK Documentation

## Overview

The Backups API provides endpoints for managing application data backups. You can create backups, upload existing backup files, download backups, delete backups, and restore the application from a backup.

**Key Features:**
- List all available backup files
- Create new backups with custom names or auto-generated names
- Upload existing backup ZIP files
- Download backup files (requires file token)
- Delete backup files
- Restore the application from a backup (restarts the app)

**Backend Endpoints:**
- `GET /api/backups` - List backups
- `POST /api/backups` - Create backup
- `POST /api/backups/upload` - Upload backup
- `GET /api/backups/{key}` - Download backup
- `DELETE /api/backups/{key}` - Delete backup
- `POST /api/backups/{key}/restore` - Restore backup

**Note**: All Backups API operations require superuser authentication (except download which requires a superuser file token).

## Authentication

All Backups API operations require superuser authentication:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Authenticate as superuser
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
```

**Downloading backups** requires a superuser file token (obtained via `Bosbase.files().get_token()`), but does not require the Authorization header.

## Backup File Structure

Each backup file contains:
- `key`: The filename/key of the backup file (string)
- `size`: File size in bytes (integer)
- `modified`: ISO 8601 timestamp of when the backup was last modified (string)

## List Backups

Returns a list of all available backup files with their metadata.

### Basic Usage

```elixir
# Get all backups
{:ok, backups} = Bosbase.backups()
  |> Bosbase.BackupService.get_full_list(pb)

IO.inspect(backups)
# [
#   %{
#     "key" => "pb_backup_20230519162514.zip",
#     "modified" => "2023-05-19T16:25:57.542Z",
#     "size" => 251_316_185
#   },
#   %{
#     "key" => "pb_backup_20230518162514.zip",
#     "modified" => "2023-05-18T16:25:57.542Z",
#     "size" => 251_314_010
#   }
# ]
```

### Working with Backup Lists

```elixir
# Sort backups by modification date (newest first)
{:ok, backups} = Bosbase.backups()
  |> Bosbase.BackupService.get_full_list(pb)

sorted = Enum.sort_by(backups, fn b -> b["modified"] end, {:desc, DateTime})

# Find the most recent backup
most_recent = List.first(sorted)

# Filter backups by size (larger than 100MB)
large_backups = Enum.filter(backups, fn backup -> backup["size"] > 100 * 1024 * 1024 end)

# Get total storage used by backups
total_size = Enum.reduce(backups, 0, fn backup, sum -> sum + backup["size"] end)
IO.puts("Total backup storage: #{Float.round(total_size / 1024 / 1024, 2)} MB")
```

## Create Backup

Creates a new backup of the application data. The backup process is asynchronous and may take some time depending on the size of your data.

### Basic Usage

```elixir
# Create backup with custom name
{:ok, _} = Bosbase.backups()
  |> Bosbase.BackupService.create(pb, "my_backup_2024.zip")

# Create backup with auto-generated name (pass empty string or let backend generate)
{:ok, _} = Bosbase.backups()
  |> Bosbase.BackupService.create(pb, "")
```

### Backup Name Format

Backup names must follow the format: `[a-z0-9_-].zip`
- Only lowercase letters, numbers, underscores, and hyphens
- Must end with `.zip`
- Maximum length: 150 characters
- Must be unique (no existing backup with the same name)

### Examples

```elixir
# Create a named backup
def create_named_backup(pb, name) do
  case Bosbase.backups()
       |> Bosbase.BackupService.create(pb, name) do
    {:ok, _} ->
      IO.puts("Backup \"#{name}\" creation initiated")
    {:error, %{status: 400}} ->
      IO.puts("Invalid backup name or backup already exists")
    {:error, error} ->
      IO.puts("Failed to create backup: #{inspect(error)}")
  end
end

# Create backup with timestamp
def create_timestamped_backup(pb) do
  timestamp = DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.replace(~r/[:.]/, "-")
    |> String.slice(0, 19)
  
  name = "backup_#{timestamp}.zip"
  Bosbase.backups()
    |> Bosbase.BackupService.create(pb, name)
end
```

### Important Notes

- **Asynchronous Process**: Backup creation happens in the background. The API returns immediately (204 No Content).
- **Concurrent Operations**: Only one backup or restore operation can run at a time. If another operation is in progress, you'll receive a 400 error.
- **Storage**: Backups are stored in the configured backup filesystem (local or S3).
- **S3 Consistency**: For S3 storage, the backup file may not be immediately available after creation due to eventual consistency.

## Upload Backup

Uploads an existing backup ZIP file to the server. This is useful for restoring backups created elsewhere or for importing backups.

### Basic Usage

```elixir
# Upload from file path
{:ok, file_content} = File.read("/path/to/backup.zip")

{:ok, _} = Bosbase.backups()
  |> Bosbase.BackupService.upload(pb, [{"file", file_content, [{"content-type", "application/zip"}]}])
```

### File Requirements

- **MIME Type**: Must be `application/zip`
- **Format**: Must be a valid ZIP archive
- **Name**: Must be unique (no existing backup with the same name)
- **Validation**: The file will be validated before upload

## Download Backup

Downloads a backup file. Requires a superuser file token for authentication.

### Basic Usage

```elixir
# Get file token
{:ok, token_response} = Bosbase.files()
  |> Bosbase.FileService.get_token(pb)

token = token_response["token"]

# Build download URL
url = Bosbase.backups()
  |> Bosbase.BackupService.get_download_url(pb, token, "pb_backup_20230519162514.zip")

# Download the file (using HTTPoison or similar)
# {:ok, response} = HTTPoison.get(url)
```

### Download URL Structure

The download URL format is:
```
/api/backups/{key}?token={fileToken}
```

## Delete Backup

Deletes a backup file from the server.

### Basic Usage

```elixir
:ok = Bosbase.backups()
  |> Bosbase.BackupService.delete(pb, "pb_backup_20230519162514.zip")
```

### Important Notes

- **Active Backups**: Cannot delete a backup that is currently being created or restored
- **No Undo**: Deletion is permanent
- **File System**: The file will be removed from the backup filesystem

## Restore Backup

Restores the application from a backup file. **This operation will restart the application**.

### Basic Usage

```elixir
{:ok, _} = Bosbase.backups()
  |> Bosbase.BackupService.restore(pb, "pb_backup_20230519162514.zip")
```

### Important Warnings

⚠️ **CRITICAL**: Restoring a backup will:
1. Replace all current application data with data from the backup
2. **Restart the application process**
3. Any unsaved changes will be lost
4. The application will be unavailable during the restore process

### Prerequisites

- **Disk Space**: Recommended to have at least **2x the backup size** in free disk space
- **UNIX Systems**: Restore is primarily supported on UNIX-based systems (Linux, macOS)
- **No Concurrent Operations**: Cannot restore if another backup or restore is in progress
- **Backup Existence**: The backup file must exist on the server

## Complete Examples

### Example 1: Backup Manager Module

```elixir
defmodule BackupManager do
  def list(pb) do
    {:ok, backups} = Bosbase.backups()
      |> Bosbase.BackupService.get_full_list(pb)
    
    Enum.sort_by(backups, fn b -> b["modified"] end, {:desc, DateTime})
  end

  def create(pb, name \\ nil) do
    name = name || generate_backup_name()
    
    case Bosbase.backups()
         |> Bosbase.BackupService.create(pb, name) do
      {:ok, _} -> {:ok, name}
      error -> error
    end
  end

  def download_url(pb, key) do
    {:ok, token_response} = Bosbase.files()
      |> Bosbase.FileService.get_token(pb)
    
    token = token_response["token"]
    Bosbase.backups()
      |> Bosbase.BackupService.get_download_url(pb, token, key)
  end

  def delete(pb, key) do
    Bosbase.backups()
      |> Bosbase.BackupService.delete(pb, key)
  end

  def restore(pb, key) do
    Bosbase.backups()
      |> Bosbase.BackupService.restore(pb, key)
  end

  defp generate_backup_name do
    timestamp = DateTime.utc_now()
      |> DateTime.to_iso8601()
      |> String.replace(~r/[:.]/, "-")
      |> String.slice(0, 19)
    
    "backup_#{timestamp}.zip"
  end
end

# Usage
backups = BackupManager.list(pb)
{:ok, name} = BackupManager.create(pb, "weekly_backup.zip")
```

## Error Handling

```elixir
case Bosbase.backups()
     |> Bosbase.BackupService.create(pb, "my-backup") do
  {:ok, _} ->
    IO.puts("Backup created successfully")
  {:error, %{status: 400}} ->
    IO.puts("Invalid backup name or backup already exists")
  {:error, %{status: 401}} ->
    IO.puts("Not authenticated")
  {:error, %{status: 403}} ->
    IO.puts("Not a superuser")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Best Practices

1. **Regular Backups**: Create backups regularly (daily, weekly, or based on your needs)
2. **Naming Convention**: Use clear, consistent naming (e.g., `backup_YYYY-MM-DD.zip`)
3. **Backup Rotation**: Implement cleanup to remove old backups and prevent storage issues
4. **Test Restores**: Periodically test restoring backups to ensure they work
5. **Off-site Storage**: Download and store backups in a separate location
6. **Pre-Restore Backup**: Always create a backup before restoring (if possible)
7. **Monitor Storage**: Monitor backup storage usage to prevent disk space issues
8. **Documentation**: Document your backup and restore procedures
9. **Automation**: Use cron jobs or schedulers for automated backups
10. **Verification**: Verify backup integrity after creation/download

## Limitations

- **Superuser Only**: All operations require superuser authentication
- **Concurrent Operations**: Only one backup or restore can run at a time
- **Restore Restart**: Restoring a backup restarts the application
- **UNIX Systems**: Restore primarily works on UNIX-based systems
- **Disk Space**: Restore requires significant free disk space (2x backup size recommended)
- **S3 Consistency**: S3 backups may not be immediately available after creation
- **Active Backups**: Cannot delete backups that are currently being created or restored

## Related Documentation

- [File API](./FILE_API.md) - File handling and tokens
- [Crons API](./CRONS_API.md) - Automated backup scheduling
- [Collection API](./COLLECTION_API.md) - Collection management

