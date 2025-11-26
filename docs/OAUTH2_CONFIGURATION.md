# OAuth2 Configuration Guide - Elixir SDK Documentation

This guide explains how to configure OAuth2 authentication providers for auth collections using the BosBase Elixir SDK.

## Overview

OAuth2 allows users to authenticate with your application using third-party providers like Google, GitHub, Facebook, etc. Before you can use OAuth2 authentication, you need to:

1. **Create an OAuth2 app** in the provider's dashboard
2. **Obtain Client ID and Client Secret** from the provider
3. **Register a redirect URL** (typically: `https://yourdomain.com/api/oauth2-redirect`)
4. **Configure the provider** in your BosBase auth collection using the SDK

## Prerequisites

- An auth collection in your BosBase instance
- OAuth2 app credentials (Client ID and Client Secret) from your chosen provider
- Admin/superuser authentication to configure collections

## Supported Providers

The following OAuth2 providers are supported:

- **google** - Google OAuth2
- **github** - GitHub OAuth2
- **gitlab** - GitLab OAuth2
- **discord** - Discord OAuth2
- **facebook** - Facebook OAuth2
- **microsoft** - Microsoft OAuth2
- **apple** - Apple Sign In
- **twitter** - Twitter OAuth2
- **spotify** - Spotify OAuth2
- **kakao** - Kakao OAuth2
- **twitch** - Twitch OAuth2
- **strava** - Strava OAuth2
- **vk** - VK OAuth2
- **yandex** - Yandex OAuth2
- **patreon** - Patreon OAuth2
- **linkedin** - LinkedIn OAuth2
- **instagram** - Instagram OAuth2
- **vimeo** - Vimeo OAuth2
- **digitalocean** - DigitalOcean OAuth2
- **bitbucket** - Bitbucket OAuth2
- **dropbox** - Dropbox OAuth2
- **planningcenter** - Planning Center OAuth2
- **notion** - Notion OAuth2
- **linear** - Linear OAuth2
- **oidc**, **oidc2**, **oidc3** - OpenID Connect (OIDC) providers

## Basic Usage

### 1. Enable OAuth2 for a Collection

First, enable OAuth2 authentication for your auth collection:

```elixir
alias Bosbase.Client

pb = Client.new("https://your-instance.com")

# Authenticate as admin
{:ok, _auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")

# Enable OAuth2 for the "users" collection
# Note: This functionality may need to be implemented via direct client.send calls
# as it might not be wrapped in CollectionService yet

# For now, you can use the client directly:
{:ok, _updated} = pb
  |> Client.send("/api/collections/users/oauth2", %{
    method: :post,
    body: %{"enabled" => true}
  })
```

### 2. Add an OAuth2 Provider

Add a provider configuration to your collection. You'll need the URLs and credentials from your OAuth2 app:

```elixir
# Add Google OAuth2 provider
{:ok, _updated} = pb
  |> Client.send("/api/collections/users/oauth2/providers", %{
    method: :post,
    body: %{
      "name" => "google",
      "clientId" => "your-google-client-id",
      "clientSecret" => "your-google-client-secret",
      "authURL" => "https://accounts.google.com/o/oauth2/v2/auth",
      "tokenURL" => "https://oauth2.googleapis.com/token",
      "userInfoURL" => "https://www.googleapis.com/oauth2/v2/userinfo",
      "displayName" => "Google",
      "pkce" => true  # Optional: enable PKCE if supported
    }
  })
```

### 3. Configure Field Mapping

Map OAuth2 provider fields to your collection fields:

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/collections/users/oauth2/mapped-fields", %{
    method: :post,
    body: %{
      "name" => "name",        # OAuth2 "name" → collection "name"
      "email" => "email",      # OAuth2 "email" → collection "email"
      "avatarUrl" => "avatar"  # OAuth2 "avatarUrl" → collection "avatar"
    }
  })
```

### 4. Get OAuth2 Configuration

Retrieve the current OAuth2 configuration:

```elixir
{:ok, config} = pb
  |> Client.send("/api/collections/users/oauth2", %{})

IO.inspect(config["enabled"])        # true/false
IO.inspect(config["providers"])      # List of providers
IO.inspect(config["mappedFields"])   # Field mappings
```

### 5. Update a Provider

Update an existing provider's configuration:

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/collections/users/oauth2/providers/google", %{
    method: :patch,
    body: %{
      "clientId" => "new-client-id",
      "clientSecret" => "new-client-secret"
    }
  })
```

### 6. Remove a Provider

Remove an OAuth2 provider:

```elixir
:ok = pb
  |> Client.send("/api/collections/users/oauth2/providers/google", %{
    method: :delete
  })
```

### 7. Disable OAuth2

Disable OAuth2 authentication for a collection:

```elixir
{:ok, _updated} = pb
  |> Client.send("/api/collections/users/oauth2", %{
    method: :post,
    body: %{"enabled" => false}
  })
```

## Complete Example

Here's a complete example of setting up Google OAuth2:

```elixir
defmodule OAuth2Setup do
  def setup_google_oauth2(pb) do
    # Authenticate as admin
    {:ok, _auth} = Client.collection(pb, "_superusers")
      |> Bosbase.RecordService.auth_with_password("admin@example.com", "password")
    
    try do
      # 1. Enable OAuth2
      {:ok, _} = pb
        |> Client.send("/api/collections/users/oauth2", %{
          method: :post,
          body: %{"enabled" => true}
        })
      
      # 2. Add Google provider
      {:ok, _} = pb
        |> Client.send("/api/collections/users/oauth2/providers", %{
          method: :post,
          body: %{
            "name" => "google",
            "clientId" => "your-google-client-id.apps.googleusercontent.com",
            "clientSecret" => "your-google-client-secret",
            "authURL" => "https://accounts.google.com/o/oauth2/v2/auth",
            "tokenURL" => "https://oauth2.googleapis.com/token",
            "userInfoURL" => "https://www.googleapis.com/oauth2/v2/userinfo",
            "displayName" => "Google",
            "pkce" => true
          }
        })
      
      # 3. Configure field mappings
      {:ok, _} = pb
        |> Client.send("/api/collections/users/oauth2/mapped-fields", %{
          method: :post,
          body: %{
            "name" => "name",
            "email" => "email",
            "avatarUrl" => "avatar"
          }
        })
      
      IO.puts("OAuth2 configuration completed successfully!")
      :ok
    rescue
      error ->
        IO.puts("Error configuring OAuth2: #{inspect(error)}")
        {:error, error}
    end
  end
end
```

## Provider-Specific Examples

### GitHub

```elixir
{:ok, _} = pb
  |> Client.send("/api/collections/users/oauth2/providers", %{
    method: :post,
    body: %{
      "name" => "github",
      "clientId" => "your-github-client-id",
      "clientSecret" => "your-github-client-secret",
      "authURL" => "https://github.com/login/oauth/authorize",
      "tokenURL" => "https://github.com/login/oauth/access_token",
      "userInfoURL" => "https://api.github.com/user",
      "displayName" => "GitHub",
      "pkce" => false
    }
  })
```

### Discord

```elixir
{:ok, _} = pb
  |> Client.send("/api/collections/users/oauth2/providers", %{
    method: :post,
    body: %{
      "name" => "discord",
      "clientId" => "your-discord-client-id",
      "clientSecret" => "your-discord-client-secret",
      "authURL" => "https://discord.com/api/oauth2/authorize",
      "tokenURL" => "https://discord.com/api/oauth2/token",
      "userInfoURL" => "https://discord.com/api/users/@me",
      "displayName" => "Discord",
      "pkce" => true
    }
  })
```

## Important Notes

1. **Redirect URL**: When creating your OAuth2 app in the provider's dashboard, you must register the redirect URL as: `https://yourdomain.com/api/oauth2-redirect`

2. **Provider Names**: The `name` field must match one of the supported provider names exactly (case-sensitive).

3. **PKCE Support**: Some providers support PKCE (Proof Key for Code Exchange) for enhanced security. Check your provider's documentation to determine if PKCE should be enabled.

4. **Client Secret Security**: Never expose your client secret in client-side code. These configuration methods should only be called from server-side code or with proper authentication.

5. **Field Mapping**: The mapped fields determine how OAuth2 user data is mapped to your collection fields. Common OAuth2 fields include:
   - `name` - User's full name
   - `email` - User's email address
   - `avatarUrl` - User's avatar/profile picture URL
   - `username` - User's username

6. **Multiple Providers**: You can add multiple OAuth2 providers to the same collection. Users can choose which provider to use during authentication.

## Error Handling

```elixir
case pb
     |> Client.send("/api/collections/users/oauth2/providers", %{
       method: :post,
       body: provider_config
     }) do
  {:ok, _updated} ->
    IO.puts("Provider added successfully")
  {:error, %{status: 400}} ->
    IO.puts("Invalid provider configuration")
  {:error, %{status: 403}} ->
    IO.puts("Permission denied. Make sure you are authenticated as admin.")
  {:error, error} ->
    IO.puts("Unexpected error: #{inspect(error)}")
end
```

## Next Steps

After configuring OAuth2 providers, users can authenticate using the `authWithOAuth2()` method. See the [Authentication Guide](./AUTHENTICATION.md) for details on using OAuth2 authentication in your application.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - Using OAuth2 authentication
- [Users Collection Guide](./USERS_COLLECTION_GUIDE.md) - Working with users collection

