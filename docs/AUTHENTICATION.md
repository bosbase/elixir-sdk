# Authentication - Elixir SDK Documentation

## Overview

Authentication in BosBase is stateless and token-based. A client is considered authenticated as long as it sends a valid `Authorization: YOUR_AUTH_TOKEN` header with requests.

**Key Points:**
- **No sessions**: BosBase APIs are fully stateless (tokens are not stored in the database)
- **No logout endpoint**: To "logout", simply clear the token from your local state (`Bosbase.AuthStore.clear/1`)
- **Token generation**: Auth tokens are generated through auth collection Web APIs or programmatically
- **Admin users**: `_superusers` collection works like regular auth collections but with full access (API rules are ignored)
- **OAuth2 limitation**: OAuth2 is not supported for `_superusers` collection

## Authentication Methods

BosBase supports multiple authentication methods that can be configured individually for each auth collection:

1. **Password Authentication** - Email/username + password
2. **OTP Authentication** - One-time password via email
3. **OAuth2 Authentication** - Google, GitHub, Microsoft, etc.
4. **Multi-factor Authentication (MFA)** - Requires 2 different auth methods

## Authentication Store

The SDK maintains an `AuthStore` that automatically manages the authentication state:

```elixir
alias Bosbase.Client

client = Bosbase.new("http://localhost:8090")

# Check authentication status
IO.inspect(Bosbase.AuthStore.valid?(client.auth_store))  # true/false
IO.inspect(Bosbase.AuthStore.token(client.auth_store))   # current auth token
IO.inspect(Bosbase.AuthStore.record(client.auth_store)) # authenticated user record

# Clear authentication (logout)
Bosbase.AuthStore.clear(client.auth_store)
```

## Password Authentication

Authenticate using email/username and password. The identity field can be configured in the collection options (default is email).

**Backend Endpoint:** `POST /api/collections/{collection}/auth-with-password`

### Basic Usage

```elixir
alias Bosbase.Client

client = Bosbase.new("http://localhost:8090")
users = Client.collection(client, "users")

# Authenticate with email and password
{:ok, auth_data} = Bosbase.RecordService.auth_with_password(users, "test@example.com", "password123")

# Auth data is automatically stored in client.auth_store
IO.inspect(Bosbase.AuthStore.valid?(client.auth_store))  # true
IO.inspect(Bosbase.AuthStore.token(client.auth_store))  # JWT token
IO.inspect(Bosbase.AuthStore.record(client.auth_store)) # user record
```

### Response Format

```elixir
%{
  "token" => "eyJhbGciOiJIUzI1NiJ9...",
  "record" => %{
    "id" => "record_id",
    "email" => "test@example.com",
    # ... other user fields
  }
}
```

### Error Handling with MFA

```elixir
case Bosbase.RecordService.auth_with_password(users, "test@example.com", "pass123") do
  {:ok, auth_data} ->
    IO.puts("Authentication successful")
    
  {:error, %{status: 401, response: %{"mfaId" => mfa_id}}} ->
    # Handle MFA flow (see Multi-factor Authentication section)
    handle_mfa(mfa_id)
    
  {:error, error} ->
    IO.inspect("Authentication failed: #{inspect(error)}")
end
```

## OTP Authentication

One-time password authentication via email.

**Backend Endpoints:**
- `POST /api/collections/{collection}/request-otp` - Request OTP
- `POST /api/collections/{collection}/auth-with-otp` - Authenticate with OTP

### Request OTP

```elixir
# Send OTP to user's email
{:ok, result} = Bosbase.RecordService.request_otp(users, "test@example.com")
IO.inspect(result["otpId"])  # OTP ID to use in auth_with_otp
```

### Authenticate with OTP

```elixir
# Step 1: Request OTP
{:ok, result} = Bosbase.RecordService.request_otp(users, "test@example.com")

# Step 2: User enters OTP from email
{:ok, auth_data} = Bosbase.RecordService.auth_with_otp(
  users,
  result["otpId"],
  "123456"  # OTP code from email
)
```

## OAuth2 Authentication

**Backend Endpoint:** `POST /api/collections/{collection}/auth-with-oauth2`

### Manual Code Exchange

```elixir
# Get auth methods
{:ok, auth_methods} = Bosbase.RecordService.list_auth_methods(users)
provider = Enum.find(auth_methods["oauth2"]["providers"], fn p -> p["name"] == "google" end)

# Exchange code for token (after OAuth2 redirect)
{:ok, auth_data} = Bosbase.RecordService.auth_with_oauth2_code(
  users,
  provider["name"],
  code,
  provider["codeVerifier"],
  redirect_url
)
```

## Multi-Factor Authentication (MFA)

Requires 2 different auth methods.

```elixir
mfa_id = case Bosbase.RecordService.auth_with_password(users, "test@example.com", "pass123") do
  {:ok, _} ->
    nil  # No MFA required
    
  {:error, %{status: 401, response: %{"mfaId" => id}}} ->
    id
end

if mfa_id do
  # Second auth method (OTP)
  {:ok, otp_result} = Bosbase.RecordService.request_otp(users, "test@example.com")
  {:ok, _} = Bosbase.RecordService.auth_with_otp(
    users,
    otp_result["otpId"],
    "123456",
    %{"mfaId" => mfa_id}
  )
end
```

## User Impersonation

Superusers can impersonate other users.

**Backend Endpoint:** `POST /api/collections/{collection}/impersonate/{id}`

```elixir
# Authenticate as superuser
admins = Client.collection(client, "_superusers")
{:ok, _} = Bosbase.RecordService.auth_with_password(admins, "admin@example.com", "adminpass")

# Impersonate a user
{:ok, impersonate_client} = Bosbase.RecordService.impersonate(users, "USER_RECORD_ID", 3600)

# Use impersonate client
{:ok, data} = Bosbase.RecordService.get_full_list(
  Client.collection(impersonate_client, "posts")
)
```

## Auth Token Verification

Verify token by calling `auth_refresh/1`.

**Backend Endpoint:** `POST /api/collections/{collection}/auth-refresh`

```elixir
case Bosbase.RecordService.auth_refresh(users) do
  {:ok, _} ->
    IO.puts("Token is valid")
    
  {:error, _} ->
    IO.puts("Token verification failed")
    Bosbase.AuthStore.clear(client.auth_store)
end
```

## List Available Auth Methods

**Backend Endpoint:** `GET /api/collections/{collection}/auth-methods`

```elixir
{:ok, auth_methods} = Bosbase.RecordService.list_auth_methods(users)
IO.inspect(auth_methods["password"]["enabled"])
IO.inspect(auth_methods["oauth2"]["providers"])
IO.inspect(auth_methods["mfa"]["enabled"])
```

## Complete Examples

### Example 1: Complete Authentication Flow with Error Handling

```elixir
defmodule AuthExample do
  alias Bosbase.{Client, RecordService, AuthStore}

  def authenticate_user(client, email, password) do
    users = Client.collection(client, "users")
    
    case RecordService.auth_with_password(users, email, password) do
      {:ok, auth_data} ->
        IO.puts("Successfully authenticated: #{auth_data["record"]["email"]}")
        {:ok, auth_data}
        
      {:error, %{status: 401, response: %{"mfaId" => mfa_id}}} ->
        IO.puts("MFA required, proceeding with second factor...")
        handle_mfa(client, email, mfa_id)
        
      {:error, %{status: 400}} ->
        {:error, "Invalid credentials"}
        
      {:error, %{status: 403}} ->
        {:error, "Password authentication is not enabled for this collection"}
        
      {:error, error} ->
        {:error, error}
    end
  end

  defp handle_mfa(client, email, mfa_id) do
    users = Client.collection(client, "users")
    
    # Request OTP for second factor
    {:ok, otp_result} = RecordService.request_otp(users, email)
    
    # In a real app, get OTP from user input
    user_entered_otp = get_user_otp_input()  # Your UI function
    
    case RecordService.auth_with_otp(
      users,
      otp_result["otpId"],
      user_entered_otp,
      %{"mfaId" => mfa_id}
    ) do
      {:ok, auth_data} ->
        IO.puts("MFA authentication successful")
        {:ok, auth_data}
        
      {:error, %{status: 429}} ->
        {:error, "Too many OTP attempts, please request a new OTP"}
        
      {:error, _} ->
        {:error, "Invalid OTP code"}
    end
  end

  defp get_user_otp_input do
    # Simulate getting OTP from user
    "123456"
  end
end

# Usage
client = Bosbase.new("http://localhost:8090")
case AuthExample.authenticate_user(client, "user@example.com", "password123") do
  {:ok, _} ->
    IO.inspect(Bosbase.AuthStore.record(client.auth_store))
  {:error, msg} ->
    IO.puts("Authentication failed: #{msg}")
end
```

### Example 2: Token Management and Refresh

```elixir
defmodule TokenManager do
  alias Bosbase.{Client, RecordService, AuthStore}

  def check_auth(client) do
    if AuthStore.valid?(client.auth_store) do
      record = AuthStore.record(client.auth_store)
      IO.puts("User is authenticated: #{record["email"]}")
      
      # Verify token is still valid and refresh if needed
      case RecordService.auth_refresh(Client.collection(client, "users")) do
        {:ok, _} ->
          IO.puts("Token refreshed successfully")
          true
          
        {:error, _} ->
          IO.puts("Token expired or invalid, clearing auth")
          AuthStore.clear(client.auth_store)
          false
      end
    else
      false
    end
  end

  def setup_auto_refresh(client) do
    if AuthStore.valid?(client.auth_store) do
      # Calculate time until token expiration
      token = AuthStore.token(client.auth_store)
      [_, payload, _] = String.split(token, ".")
      
      {:ok, json} = Base.url_decode64(payload, padding: false)
      {:ok, data} = Jason.decode(json)
      exp = data["exp"]
      
      now = System.os_time(:second)
      time_until_expiry = exp - now
      
      # Refresh 5 minutes before expiration
      refresh_time = max(0, time_until_expiry - 300) * 1000
      
      Process.send_after(self(), :refresh_token, refresh_time)
    end
  end
end

# Usage
client = Bosbase.new("http://localhost:8090")
if TokenManager.check_auth(client) do
  TokenManager.setup_auto_refresh(client)
else
  # Redirect to login
end
```

### Example 3: Admin Impersonation for Support

```elixir
defmodule SupportImpersonation do
  alias Bosbase.{Client, RecordService}

  def impersonate_user_for_support(client, user_id) do
    # Authenticate as admin
    admins = Client.collection(client, "_superusers")
    {:ok, _} = RecordService.auth_with_password(admins, "admin@example.com", "adminpassword")
    
    # Impersonate the user (1 hour token)
    users = Client.collection(client, "users")
    {:ok, user_client} = RecordService.impersonate(users, user_id, 3600)
    
    record = Bosbase.AuthStore.record(user_client.auth_store)
    IO.puts("Impersonating user: #{record["email"]}")
    
    # Use the impersonated client to test user experience
    posts = Client.collection(user_client, "posts")
    {:ok, user_records} = RecordService.get_full_list(posts)
    IO.puts("User can see #{length(user_records)} posts")
    
    {:ok, user_view} = RecordService.get_list(posts, %{
      "filter" => "published = true"
    })
    
    %{
      can_access: length(user_view["items"]),
      total_posts: length(user_records)
    }
  end
end

# Usage in support dashboard
client = Bosbase.new("http://localhost:8090")
case SupportImpersonation.impersonate_user_for_support(client, "user_record_id") do
  {:ok, result} ->
    IO.inspect(result)
  {:error, err} ->
    IO.puts("Impersonation failed: #{inspect(err)}")
end
```

## Best Practices

1. **Secure Token Storage**: Never expose tokens in client-side code or logs
2. **Token Refresh**: Implement automatic token refresh before expiration
3. **Error Handling**: Always handle MFA requirements and token expiration
4. **OAuth2 Security**: Always validate the `state` parameter in OAuth2 callbacks
5. **API Keys**: Use impersonation tokens for server-to-server communication only
6. **Superuser Tokens**: Never expose superuser impersonation tokens in client code
7. **OTP Security**: Use OTP with MFA for security-critical applications
8. **Rate Limiting**: Be aware of rate limits on authentication endpoints

## Troubleshooting

### Token Expired
If you get 401 errors, check if the token has expired:

```elixir
case Bosbase.RecordService.auth_refresh(Client.collection(client, "users")) do
  {:ok, _} ->
    :ok
  {:error, _} ->
    # Token expired, require re-authentication
    Bosbase.AuthStore.clear(client.auth_store)
    # Redirect to login
end
```

### MFA Required
If authentication returns 401 with mfaId:

```elixir
case Bosbase.RecordService.auth_with_password(users, email, password) do
  {:error, %{status: 401, response: %{"mfaId" => mfa_id}}} ->
    # Proceed with second authentication factor
    handle_mfa(mfa_id)
  {:error, error} ->
    # Handle other errors
end
```

## Related Documentation

- [Collections](./COLLECTIONS.md)
- [API Rules](./API_RULES_AND_FILTERS.md)

