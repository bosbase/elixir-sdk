# File API - Elixir SDK Documentation

## Overview

The File API provides endpoints for downloading and accessing files stored in collection records. It supports thumbnail generation for images, protected file access with tokens, and force download options.

**Key Features:**
- Download files from collection records
- Generate thumbnails for images (crop, fit, resize)
- Protected file access with short-lived tokens
- Force download option for any file type
- Automatic content-type detection
- Support for Range requests and caching

**Backend Endpoints:**
- `GET /api/files/{collection}/{recordId}/{filename}` - Download/fetch file
- `POST /api/files/token` - Generate protected file token

## Download / Fetch File

Downloads a single file resource from a record.

### Basic Usage

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Get a record with a file field
{:ok, record} = Client.collection(pb, "posts")
  |> Bosbase.RecordService.get_one("RECORD_ID")

# Get the file URL
file_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"])

IO.puts("File URL: #{file_url}")
```

### File URL Structure

The file URL follows this pattern:
```
/api/files/{collectionIdOrName}/{recordId}/{filename}
```

Example:
```
http://127.0.0.1:8090/api/files/posts/abc123/photo_xyz789.jpg
```

## Thumbnails

Generate thumbnails for image files on-the-fly.

### Thumbnail Formats

The following thumbnail formats are supported:

| Format | Example | Description |
|--------|---------|-------------|
| `WxH` | `100x300` | Crop to WxH viewbox (from center) |
| `WxHt` | `100x300t` | Crop to WxH viewbox (from top) |
| `WxHb` | `100x300b` | Crop to WxH viewbox (from bottom) |
| `WxHf` | `100x300f` | Fit inside WxH viewbox (without cropping) |
| `0xH` | `0x300` | Resize to H height preserving aspect ratio |
| `Wx0` | `100x0` | Resize to W width preserving aspect ratio |

### Using Thumbnails

```elixir
# Get thumbnail URL
thumb_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "100x100"
  })

# Different thumbnail sizes
small_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "50x50"
  })

medium_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "200x200"
  })

large_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "500x500"
  })

# Fit thumbnail (no cropping)
fit_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "200x200f"
  })

# Resize to specific width
width_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "300x0"
  })

# Resize to specific height
height_thumb = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["image"], %{
    "thumb" => "0x200"
  })
```

### Thumbnail Behavior

- **Image Files Only**: Thumbnails are only generated for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Non-Image Files**: For non-image files, the thumb parameter is ignored and the original file is returned
- **Caching**: Thumbnails are cached and reused if already generated
- **Fallback**: If thumbnail generation fails, the original file is returned
- **Field Configuration**: Thumb sizes must be defined in the file field's `thumbs` option or use default `100x100`

## Protected Files

Protected files require a special token for access, even if you're authenticated.

### Getting a File Token

```elixir
# Must be authenticated first
{:ok, _auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.auth_with_password("user@example.com", "password")

# Get file token
{:ok, token_response} = Bosbase.files()
  |> Bosbase.FileService.get_token(pb)

token = token_response["token"]
IO.puts("Token: #{token}")  # Short-lived JWT token
```

### Using Protected File Token

```elixir
# Get protected file URL with token
protected_file_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["document"], %{
    "token" => token
  })

# Access the file (using HTTPoison or similar)
# {:ok, response} = HTTPoison.get(protected_file_url)
```

### Protected File Example

```elixir
def display_protected_image(pb, record_id) do
  # Authenticate
  {:ok, _auth} = Client.collection(pb, "users")
    |> Bosbase.RecordService.auth_with_password("user@example.com", "password")
  
  # Get record
  {:ok, record} = Client.collection(pb, "documents")
    |> Bosbase.RecordService.get_one(record_id)
  
  # Get file token
  {:ok, token_response} = Bosbase.files()
    |> Bosbase.FileService.get_token(pb)
  
  token = token_response["token"]
  
  # Get protected file URL
  image_url = Bosbase.files()
    |> Bosbase.FileService.get_url(pb, record, record["thumbnail"], %{
      "token" => token,
      "thumb" => "300x300"
    })
  
  IO.puts("Image URL: #{image_url}")
end
```

### Token Lifetime

- File tokens are short-lived (typically expires after a few minutes)
- Tokens are associated with the authenticated user/superuser
- Generate a new token if the previous one expires

## Force Download

Force files to download instead of being displayed in the browser.

```elixir
# Force download
download_url = Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, record["document"], %{
    "download" => true
  })

IO.puts("Download URL: #{download_url}")
```

### Download Parameter Values

```elixir
# These all force download:
Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename, %{"download" => true})

Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename, %{"download" => 1})

# These allow inline display (default):
Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename, %{"download" => false})

Bosbase.files()
  |> Bosbase.FileService.get_url(pb, record, filename)  # No download parameter
```

## Complete Examples

### Example 1: Image Gallery

```elixir
def display_image_gallery(pb, record_id) do
  {:ok, record} = Client.collection(pb, "posts")
    |> Bosbase.RecordService.get_one(record_id)
  
  images = if is_list(record["images"]), do: record["images"], else: [record["image"]]
  
  Enum.each(images, fn filename ->
    # Thumbnail for gallery
    thumb_url = Bosbase.files()
      |> Bosbase.FileService.get_url(pb, record, filename, %{
        "thumb" => "200x200"
      })
    
    # Full image URL
    full_url = Bosbase.files()
      |> Bosbase.FileService.get_url(pb, record, filename)
    
    IO.puts("Thumbnail: #{thumb_url}")
    IO.puts("Full: #{full_url}")
  end)
end
```

### Example 2: File Download Handler

```elixir
def download_file(pb, record_id, filename) do
  {:ok, record} = Client.collection(pb, "documents")
    |> Bosbase.RecordService.get_one(record_id)
  
  # Get download URL
  download_url = Bosbase.files()
    |> Bosbase.FileService.get_url(pb, record, filename, %{
      "download" => true
    })
  
  IO.puts("Download URL: #{download_url}")
  # Use HTTPoison or similar to download the file
end
```

### Example 3: Protected File Viewer

```elixir
def view_protected_file(pb, record_id) do
  # Authenticate
  {:ok, _auth} = Client.collection(pb, "users")
    |> Bosbase.RecordService.auth_with_password("user@example.com", "password")
  
  # Get record
  {:ok, record} = Client.collection(pb, "private_docs")
    |> Bosbase.RecordService.get_one(record_id)
  
  # Get token
  case Bosbase.files()
       |> Bosbase.FileService.get_token(pb) do
    {:ok, token_response} ->
      token = token_response["token"]
      
      # Get file URL
      file_url = Bosbase.files()
        |> Bosbase.FileService.get_url(pb, record, record["file"], %{
          "token" => token
        })
      
      IO.puts("File URL: #{file_url}")
    {:error, error} ->
      IO.puts("Failed to get file token: #{inspect(error)}")
  end
end
```

## Error Handling

```elixir
case Bosbase.files()
     |> Bosbase.FileService.get_url(pb, record, record["image"]) do
  url when is_binary(url) ->
    IO.puts("File URL: #{url}")
  {:error, error} ->
    IO.puts("File access error: #{inspect(error)}")
end
```

### Protected File Token Error Handling

```elixir
def get_protected_file_url(pb, record, filename) do
  case Bosbase.files()
       |> Bosbase.FileService.get_token(pb) do
    {:ok, token_response} ->
      token = token_response["token"]
      Bosbase.files()
        |> Bosbase.FileService.get_url(pb, record, filename, %{"token" => token})
    {:error, %{status: 401}} ->
      IO.puts("Not authenticated")
      nil
    {:error, %{status: 403}} ->
      IO.puts("No permission to access file")
      nil
    {:error, error} ->
      IO.puts("Failed to get file token: #{inspect(error)}")
      nil
  end
end
```

## Best Practices

1. **Use Thumbnails for Lists**: Use thumbnails when displaying images in lists/grids to reduce bandwidth
2. **Lazy Loading**: Consider lazy loading for images below the fold
3. **Cache Tokens**: Store file tokens and reuse them until they expire
4. **Error Handling**: Always handle file loading errors gracefully
5. **Content-Type**: Let the server handle content-type detection automatically
6. **Range Requests**: The API supports Range requests for efficient video/audio streaming
7. **Caching**: Files are cached with a 30-day cache-control header
8. **Security**: Always use tokens for protected files, never expose them in client-side code

## Thumbnail Size Guidelines

| Use Case | Recommended Size |
|----------|-----------------|
| Profile picture | `100x100` or `150x150` |
| List thumbnails | `200x200` or `300x300` |
| Card images | `400x400` or `500x500` |
| Gallery previews | `300x300f` (fit) or `400x400f` |
| Hero images | Use original or `800x800f` |
| Avatar | `50x50` or `75x75` |

## Limitations

- **Thumbnails**: Only work for image files (PNG, JPG, JPEG, GIF, WEBP)
- **Protected Files**: Require authentication to get tokens
- **Token Expiry**: File tokens expire after a short period (typically minutes)
- **File Size**: Large files may take time to generate thumbnails on first request
- **Thumb Sizes**: Must match sizes defined in field configuration or use default `100x100`

## Related Documentation

- [Files Upload and Handling](./FILES.md) - Uploading and managing files
- [API Records](./API_RECORDS.md) - Working with records
- [Collections](./COLLECTIONS.md) - Collection configuration

