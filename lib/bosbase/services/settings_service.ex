defmodule Bosbase.SettingsService do
  @moduledoc "Settings management."
  alias Bosbase.Client

  def get_all(client, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/settings", %{query: query, headers: headers})
  end

  def update(client, body \\ %{}, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/settings", %{method: :patch, body: body, query: query, headers: headers})
  end

  def test_s3(client, filesystem, body \\ %{}, query \\ %{}, headers \\ %{}) do
    payload = Map.put(Map.new(body || %{}), "filesystem", filesystem)

    Client.send(client, "/api/settings/test/s3", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def test_email(
        client,
        to_email,
        template,
        collection \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("email", to_email)
      |> Map.put("template", template)
      |> maybe_put("collection", collection)

    Client.send(client, "/api/settings/test/email", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def generate_apple_client_secret(
        client,
        client_id,
        team_id,
        key_id,
        private_key,
        duration,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("clientId", client_id)
      |> Map.put("teamId", team_id)
      |> Map.put("keyId", key_id)
      |> Map.put("privateKey", private_key)
      |> Map.put("duration", duration)

    Client.send(client, "/api/settings/apple/generate-client-secret", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def get_category(client, category, query \\ %{}, headers \\ %{}) do
    with {:ok, settings} <- get_all(client, query, headers) do
      cond do
        is_nil(category) or category == "" -> {:ok, settings}
        is_map(settings) -> {:ok, Map.get(settings, category)}
        true -> {:ok, nil}
      end
    end
  end

  def update_meta(
        client,
        app_name \\ nil,
        app_url \\ nil,
        sender_name \\ nil,
        sender_address \\ nil,
        hide_controls \\ nil,
        query \\ %{},
        headers \\ %{}
      ) do
    meta = %{}
    meta = if present?(app_name), do: Map.put(meta, "appName", app_name), else: meta
    meta = if present?(app_url), do: Map.put(meta, "appURL", app_url), else: meta
    meta = if present?(sender_name), do: Map.put(meta, "senderName", sender_name), else: meta

    meta =
      if present?(sender_address), do: Map.put(meta, "senderAddress", sender_address), else: meta

    meta =
      if is_boolean(hide_controls), do: Map.put(meta, "hideControls", hide_controls), else: meta

    update(client, %{"meta" => meta}, query, headers)
  end

  def get_application_settings(client, query \\ %{}, headers \\ %{}) do
    with {:ok, settings} <- get_all(client, query, headers),
         true <- is_map(settings) do
      {:ok,
       %{
         "meta" => settings["meta"],
         "trustedProxy" => settings["trustedProxy"],
         "rateLimits" => settings["rateLimits"],
         "batch" => settings["batch"]
       }}
    end
  end

  def update_application_settings(
        client,
        meta \\ nil,
        trusted_proxy \\ nil,
        rate_limits \\ nil,
        batch \\ nil,
        query \\ %{},
        headers \\ %{}
      ) do
    payload = %{}
    payload = if meta, do: Map.put(payload, "meta", meta), else: payload
    payload = if trusted_proxy, do: Map.put(payload, "trustedProxy", trusted_proxy), else: payload
    payload = if rate_limits, do: Map.put(payload, "rateLimits", rate_limits), else: payload
    payload = if batch, do: Map.put(payload, "batch", batch), else: payload

    update(client, payload, query, headers)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp present?(val), do: val not in [nil, ""]
end
