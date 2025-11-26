# Files Upload and Handling - Elixir SDK Documentation

## Overview

BosBase allows you to upload and manage files through file fields in your collections. Files are stored with sanitized names and a random suffix for security (e.g., `test_52iwbgds7l.png`).

**Key Features:**
- Upload multiple files per field
- Maximum file size: ~8GB (2^53-1 bytes)
- Automatic filename sanitization and random suffix
- Image thumbnails support
- Protected files with token-based access
- File modifiers for append/prepend/delete operations

**Backend Endpoints:**
- `POST /api/files/token` - Get file access token for protected files
- `GET /api/files/{collection}/{recordId}/{filename}` - Download file

## File Field Configuration

Before uploading files, you must add a file field to your collection:

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Get collection
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "example")

# Add file field
new_fields = collection["fields"] ++ [
  %{
    "name" => "documents",
    "type" => "file",
    "maxSelect" => 5,        # Maximum number of files (1 for single file)
    "maxSize" => 5_242_880,  # 5MB in bytes (optional, default: 5MB)
    "mimeTypes" => ["image/jpeg", "image/png", "application/pdf"],
    "thumbs" => ["100x100", "300x300"],  # Thumbnail sizes for images
    "protected" => false     # Require token for access
  }
]

# Update collection
{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "example", %{"fields" => new_fields})
```

## Uploading Files

### Basic Upload with Create

When creating a new record, you can upload files directly. In Elixir, you'll typically use multipart form data:

```elixir
alias Bosbase.Client

pb = Client.new("http://localhost:8090")

# Upload file using multipart form data
# Note: You'll need to use an HTTP client like HTTPoison with multipart support
# This is a conceptual example - actual implementation depends on your HTTP client

# For multipart uploads, you would typically:
# 1. Create a multipart form with the file
# 2. Send it via the client's send method

# Example with HTTPoison (conceptual):
# {:ok, file_content} = File.read("/path/to/file.txt")
# 
# body = Multipart.new()
#   |> Multipart.add_field("title", "Hello world!")
#   |> Multipart.add_file("documents", file_content, filename: "file1.txt")
#
# {:ok, created_record} = Client.collection(pb, "example")
#   |> Bosbase.RecordService.create(body)
```

### Upload with Update

```elixir
# Update record and upload new files
# Similar to create, use multipart form data
{:ok, _updated} = Client.collection(pb, "example")
  |> Bosbase.RecordService.update("RECORD_ID", %{
    "title" => "Updated title"
    # Files would be added via multipart form data
  })
```

### Append Files (Using + Modifier)

For multiple file fields, use the `+` modifier to append files:

```elixir
# Append files to existing ones
# Note: File uploads in Elixir typically require multipart form data
# This is a conceptual example

# {:ok, _updated} = Client.collection(pb, "example")
#   |> Bosbase.RecordService.update("RECORD_ID", %{
#     "documents+" => file_data  # Append single file
#   })

# Or prepend files (files will appear first)
# {:ok, _updated} = Client.collection(pb, "example")
#   |> Bosbase.RecordService.update("RECORD_ID", %{
#     "+documents" => file_data  # Prepend file
#   })
```

## Deleting Files

### Delete All Files

```elixir
# Delete all files in a field (set to empty array)
{:ok, _updated} = Client.collection(pb, "example")
  |> Bosbase.RecordService.update("RECORD_ID", %{
    "documents" => []
  })
```

### Delete Specific Files (Using - Modifier)

```elixir
# Delete individual files by filename
{:ok, _updated} = Client.collection(pb, "example")
  |> Bosbase.RecordService.update("RECORD_ID", %{
    "documents-" => ["file1.pdf", "file2.txt"]
  })
```

## File URLs

### Get File URL

Each uploaded file can be accessed via its URL:

```
http://localhost:8090/api/files/COLLECTION_ID_OR_NAME/RECORD_ID/FILENAME
```

**Using SDK:**

```elixir
{:ok, record} = Client.collection(pb, "example")
  |> Bosbase.RecordService.get_one("RECORD_ID")

# Single file field (returns string)
filename = record["documents"]
url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename)

# Multiple file field (returns array)
first_file = List.first(record["documents"])
url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, first_file)
```

### Image Thumbnails

If your file field has thumbnail sizes configured, you can request thumbnails:

```elixir
{:ok, record} = Client.collection(pb, "example")
  |> Bosbase.RecordService.get_one("RECORD_ID")

filename = record["avatar"]  # Image file

# Get thumbnail with specific size
thumb_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename, %{
    "thumb" => "100x300"  # Width x Height
  })
```

**Thumbnail Formats:**

- `WxH` (e.g., `100x300`) - Crop to WxH viewbox from center
- `WxHt` (e.g., `100x300t`) - Crop to WxH viewbox from top
- `WxHb` (e.g., `100x300b`) - Crop to WxH viewbox from bottom
- `WxHf` (e.g., `100x300f`) - Fit inside WxH viewbox (no cropping)
- `0xH` (e.g., `0x300`) - Resize to H height, preserve aspect ratio
- `Wx0` (e.g., `100x0`) - Resize to W width, preserve aspect ratio

**Supported Image Formats:**
- JPEG (`.jpg`, `.jpeg`)
- PNG (`.png`)
- GIF (`.gif` - first frame only)
- WebP (`.webp` - stored as PNG)

**Example:**

```elixir
{:ok, record} = Client.collection(pb, "products")
  |> Bosbase.RecordService.get_one("PRODUCT_ID")

image = record["image"]

# Different thumbnail sizes
thumb_small = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, image, %{"thumb" => "100x100"})

thumb_medium = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, image, %{"thumb" => "300x300f"})

thumb_large = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, image, %{"thumb" => "800x600"})

thumb_height = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, image, %{"thumb" => "0x400"})

thumb_width = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, image, %{"thumb" => "600x0"})
```

### Force Download

To force browser download instead of preview:

```elixir
url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename, %{
    "download" => 1  # Force download
  })
```

## Protected Files

By default, all files are publicly accessible if you know the full URL. For sensitive files, you can mark the field as "Protected" in the collection settings.

### Setting Up Protected Files

```elixir
{:ok, collection} = Bosbase.collections()
  |> Bosbase.CollectionService.get_one(pb, "example")

# Find and update file field
updated_fields = Enum.map(collection["fields"], fn field ->
  if field["name"] == "documents" do
    Map.put(field, "protected", true)
  else
    field
  end
end)

{:ok, _updated} = Bosbase.collections()
  |> Bosbase.CollectionService.update(pb, "example", %{"fields" => updated_fields})
```

### Accessing Protected Files

Protected files require authentication and a file token:

```elixir
# Step 1: Authenticate
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password123")

# Step 2: Get file token (valid for ~2 minutes)
{:ok, token_response} = Bosbase.files()
  |> Bosbase.FileService.get_token(pb)

file_token = token_response["token"]

# Step 3: Get protected file URL with token
{:ok, record} = Client.collection(pb, "example")
  |> Bosbase.RecordService.get_one("RECORD_ID")

url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["privateDocument"], %{
    "token" => file_token
  })

IO.puts("Protected file URL: #{url}")
```

**Important:**
- File tokens are short-lived (~2 minutes)
- Only authenticated users satisfying the collection's `viewRule` can access protected files
- Tokens must be regenerated when they expire

### Complete Protected File Example

```elixir
def load_protected_image(pb, record_id, filename) do
  # Check if authenticated (you would check auth store)
  # if not authenticated, authenticate first
  
  # Get fresh token
  case Bosbase.files()
       |> Bosbase.FileService.get_token(pb) do
    {:ok, token_response} ->
      token = token_response["token"]
      
      # Get file URL
      {:ok, record} = Client.collection(pb, "example")
        |> Bosbase.RecordService.get_one(record_id)
      
      url = Bosbase.files()
        |> Bosbase.FileService.get_url(pb, record, filename, %{"token" => token})
      
      {:ok, url}
    {:error, %{status: 404}} ->
      {:error, "File not found or access denied"}
    {:error, %{status: 401}} ->
      {:error, "Authentication required"}
    {:error, error} ->
      {:error, error}
  end
end
```

## Complete Examples

### Example 1: Image Upload with Thumbnails

```elixir
defmodule ImageUpload do
  def upload_product_image(pb, product_id, image_path) do
    # Read file
    {:ok, file_content} = File.read(image_path)
    
    # Upload via multipart form (conceptual - actual implementation depends on HTTP client)
    # The SDK would handle multipart encoding
    
    # After upload, get thumbnail URL
    {:ok, product} = Client.collection(pb, "products")
      |> Bosbase.RecordService.get_one(product_id)
    
    thumbnail_url = Bosbase.files()
      |> Bosbase.FileService.get_url(pb, product, product["image"], %{
        "thumb" => "300x300"
      })
    
    IO.puts("Thumbnail URL: #{thumbnail_url}")
  end
end
```

### Example 2: File Management

```elixir
defmodule FileManager do
  def list_files(pb, collection_id, record_id) do
    {:ok, record} = Client.collection(pb, collection_id)
      |> Bosbase.RecordService.get_one(record_id)
    
    files = if is_list(record["documents"]), do: record["documents"], else: []
    
    Enum.map(files, fn filename ->
      url = Bosbase.files()
        |> Bosbase.FileService.get_url(pb, record, filename)
      
      %{"filename" => filename, "url" => url}
    end)
  end

  def delete_file(pb, collection_id, record_id, filename) do
    Client.collection(pb, collection_id)
      |> Bosbase.RecordService.update(record_id, %{
        "documents-" => [filename]
      })
  end
end
```

## File Field Modifiers

### Summary

- **No modifier** - Replace all files: `documents: [file1, file2]`
- **`+` suffix** - Append files: `documents+: file3`
- **`+` prefix** - Prepend files: `+documents: file0`
- **`-` suffix** - Delete files: `documents-: ['file1.pdf']`

## Best Practices

1. **File Size Limits**: Always validate file sizes on the client before upload
2. **MIME Types**: Configure allowed MIME types in collection field settings
3. **Thumbnails**: Pre-generate common thumbnail sizes for better performance
4. **Protected Files**: Use protected files for sensitive documents (ID cards, contracts)
5. **Token Refresh**: Refresh file tokens before they expire for protected files
6. **Error Handling**: Handle 404 errors for missing files and 401 for protected file access
7. **Filename Sanitization**: Files are automatically sanitized, but validate on client side too

## Error Handling

```elixir
case Client.collection(pb, "example")
     |> Bosbase.RecordService.create(%{
       "title" => "Test"
       # Files would be in multipart form
     }) do
  {:ok, record} ->
    IO.puts("Upload successful")
  {:error, %{status: 413}} ->
    IO.puts("File too large")
  {:error, %{status: 400}} ->
    IO.puts("Invalid file type or field validation failed")
  {:error, %{status: 403}} ->
    IO.puts("Insufficient permissions")
  {:error, error} ->
    IO.puts("Upload failed: #{inspect(error)}")
end
```

## Storage Options

By default, BosBase stores files in `pb_data/storage` on the local filesystem. For production, you can configure S3-compatible storage (AWS S3, MinIO, Wasabi, DigitalOcean Spaces, etc.) from:
**Dashboard > Settings > Files storage**

This is configured server-side and doesn't require SDK changes.

## Related Documentation

- [File API](./FILE_API.md) - Downloading and accessing files
- [Collections](./COLLECTIONS.md) - Collection and field configuration
- [Authentication](./AUTHENTICATION.md) - Required for protected files

