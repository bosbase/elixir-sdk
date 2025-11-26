# Custom Token Binding and Login - Elixir SDK Documentation

The Elixir SDK and BosBase service now support binding a custom token to an auth record (both `users` and `_superusers`) and signing in with that token. The server stores bindings in the `_token_bindings` table (created automatically on first bind; legacy `_tokenBindings`/`tokenBindings` are auto-renamed). Tokens are stored as hashes so raw values aren't persisted.

## API endpoints
- `POST /api/collections/{collection}/bind-token`
- `POST /api/collections/{collection}/unbind-token`
- `POST /api/collections/{collection}/auth-with-token`

## Binding a token

```elixir
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Bind for a regular user
{:ok, _} = Client.collection(pb, "users")
  |> Bosbase.RecordService.send("/bind-token", %{
    method: :post,
    body: %{
      "email" => "user@example.com",
      "password" => "user-password",
      "token" => "my-app-token"
    }
  })

# Bind for a superuser
{:ok, _} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.send("/bind-token", %{
    method: :post,
    body: %{
      "email" => "admin@example.com",
      "password" => "admin-password",
      "token" => "admin-app-token"
    }
  })
```

## Unbinding a token

```elixir
# Stop accepting the token for the user
{:ok, _} = Client.collection(pb, "users")
  |> Bosbase.RecordService.send("/unbind-token", %{
    method: :post,
    body: %{
      "email" => "user@example.com",
      "password" => "user-password",
      "token" => "my-app-token"
    }
  })

# Stop accepting the token for a superuser
{:ok, _} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.send("/unbind-token", %{
    method: :post,
    body: %{
      "email" => "admin@example.com",
      "password" => "admin-password",
      "token" => "admin-app-token"
    }
  })
```

## Logging in with a token

```elixir
# Login with the previously bound token
{:ok, auth} = Client.collection(pb, "users")
  |> Bosbase.RecordService.send("/auth-with-token", %{
    method: :post,
    body: %{
      "token" => "my-app-token"
    }
  })

IO.inspect(auth["token"])   # BosBase auth token
IO.inspect(auth["record"])  # authenticated record

# Superuser token login
{:ok, super_auth} = Client.collection(pb, "_superusers")
  |> Bosbase.RecordService.send("/auth-with-token", %{
    method: :post,
    body: %{
      "token" => "admin-app-token"
    }
  })

IO.inspect(super_auth["token"])
IO.inspect(super_auth["record"])
```

## Complete Example

```elixir
defmodule CustomTokenAuth do
  def bind_token(pb, collection, email, password, token) do
    Client.collection(pb, collection)
      |> Bosbase.RecordService.send("/bind-token", %{
        method: :post,
        body: %{
          "email" => email,
          "password" => password,
          "token" => token
        }
      })
  end

  def unbind_token(pb, collection, email, password, token) do
    Client.collection(pb, collection)
      |> Bosbase.RecordService.send("/unbind-token", %{
        method: :post,
        body: %{
          "email" => email,
          "password" => password,
          "token" => token
        }
      })
  end

  def auth_with_token(pb, collection, token) do
    Client.collection(pb, collection)
      |> Bosbase.RecordService.send("/auth-with-token", %{
        method: :post,
        body: %{
          "token" => token
        }
      })
  end
end

# Usage
alias Bosbase.Client

pb = Client.new("http://127.0.0.1:8090")

# Bind token for user
{:ok, _} = CustomTokenAuth.bind_token(
  pb,
  "users",
  "user@example.com",
  "user-password",
  "my-app-token"
)

# Later, login with token
{:ok, auth} = CustomTokenAuth.auth_with_token(pb, "users", "my-app-token")
IO.puts("Authenticated as: #{auth["record"]["email"]}")

# Unbind token when done
{:ok, _} = CustomTokenAuth.unbind_token(
  pb,
  "users",
  "user@example.com",
  "user-password",
  "my-app-token"
)
```

## Notes

- Binding and unbinding require a valid email and password for the target account.
- The same token value can be used for either `users` or `_superusers` collections; the collection is enforced during login.
- MFA and existing auth rules still apply when authenticating with a token.

## Related Documentation

- [Authentication](./AUTHENTICATION.md) - Standard authentication methods
- [API Records](./API_RECORDS.md) - Record operations

