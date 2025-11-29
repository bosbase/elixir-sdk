defmodule Bosbase.RecordService do
  @moduledoc """
  CRUD and auth helpers for a specific collection.
  """

  alias Bosbase.{AuthStore, BaseCrudService, Client, Utils}

  defstruct [:client, :collection, :crud]

  def new(%Client{} = client, collection) do
    crud =
      BaseCrudService.new(client, fn ->
        "/api/collections/#{Utils.encode_path_segment(collection)}/records"
      end)

    %__MODULE__{client: client, collection: collection, crud: crud}
  end

  # CRUD proxies
  def get_full_list(%__MODULE__{crud: crud}, batch, opts \\ %{}),
    do: BaseCrudService.get_full_list(crud, batch, opts)

  def get_list(%__MODULE__{crud: crud}, opts \\ %{}), do: BaseCrudService.get_list(crud, opts)

  def get_one(%__MODULE__{crud: crud}, id, opts \\ %{}),
    do: BaseCrudService.get_one(crud, id, opts)

  def get_first_list_item(%__MODULE__{crud: crud}, filter, opts \\ %{}),
    do: BaseCrudService.get_first_list_item(crud, filter, opts)

  def create(%__MODULE__{crud: crud}, opts \\ %{}) do
    case BaseCrudService.create(crud, opts) do
      {:ok, item} -> {:ok, item}
      other -> other
    end
  end

  def update(%__MODULE__{crud: crud} = svc, record_id, opts \\ %{}) do
    case BaseCrudService.update(crud, record_id, opts) do
      {:ok, item} = res ->
        maybe_update_auth_record(svc, item)
        res

      other ->
        other
    end
  end

  def delete(%__MODULE__{crud: crud} = svc, record_id, opts \\ %{}) do
    case BaseCrudService.delete(crud, record_id, opts) do
      :ok ->
        if is_auth_record?(svc, record_id), do: AuthStore.clear(svc.client.auth_store)
        :ok

      other ->
        other
    end
  end

  def get_count(
        %__MODULE__{} = svc,
        filter \\ nil,
        expand \\ nil,
        fields \\ nil,
        query \\ %{},
        headers \\ %{}
      ) do
    params =
      query
      |> Map.new()
      |> maybe_put("filter", filter)
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    Client.send(svc.client, base_collection_path(svc) <> "/count", %{query: params, headers: headers})
  end

  def list_auth_methods(%__MODULE__{} = svc, fields \\ nil, query \\ %{}, headers \\ %{}) do
    params =
      query
      |> Map.new()
      |> Map.put("fields", fields || "mfa,otp,password,oauth2")

    Client.send(svc.client, base_collection_path(svc) <> "/auth-methods", %{
      query: params,
      headers: headers
    })
  end

  def auth_with_password(
        %__MODULE__{} = svc,
        identity,
        password,
        expand \\ nil,
        fields \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("identity", identity)
      |> Map.put("password", password)

    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    case Client.send(svc.client, base_collection_path(svc) <> "/auth-with-password", %{
           method: :post,
           body: payload,
           query: params,
           headers: headers
         }) do
      {:ok, data} -> {:ok, auth_response(svc, data)}
      other -> other
    end
  end

  def auth_with_oauth2_code(
        %__MODULE__{} = svc,
        provider,
        code,
        code_verifier,
        redirect_url,
        create_data \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{},
        expand \\ nil,
        fields \\ nil
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("provider", provider)
      |> Map.put("code", code)
      |> Map.put("codeVerifier", code_verifier)
      |> Map.put("redirectURL", redirect_url)
      |> maybe_put("createData", create_data)

    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    case Client.send(svc.client, base_collection_path(svc) <> "/auth-with-oauth2", %{
           method: :post,
           body: payload,
           query: params,
           headers: headers
         }) do
      {:ok, data} -> {:ok, auth_response(svc, data)}
      other -> other
    end
  end

  def auth_refresh(
        %__MODULE__{} = svc,
        expand \\ nil,
        fields \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    case Client.send(svc.client, base_collection_path(svc) <> "/auth-refresh", %{
           method: :post,
           body: body,
           query: params,
           headers: headers
         }) do
      {:ok, data} -> {:ok, auth_response(svc, data)}
      other -> other
    end
  end

  def request_password_reset(
        %__MODULE__{} = svc,
        email,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload = body |> Map.new() |> Map.put("email", email)

    Client.send(svc.client, base_collection_path(svc) <> "/request-password-reset", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def confirm_password_reset(
        %__MODULE__{} = svc,
        token,
        password,
        password_confirm,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("token", token)
      |> Map.put("password", password)
      |> Map.put("passwordConfirm", password_confirm)

    Client.send(svc.client, base_collection_path(svc) <> "/confirm-password-reset", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def request_verification(%__MODULE__{} = svc, email, body \\ %{}, query \\ %{}, headers \\ %{}) do
    payload = body |> Map.new() |> Map.put("email", email)

    Client.send(svc.client, base_collection_path(svc) <> "/request-verification", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def confirm_verification(%__MODULE__{} = svc, token, body \\ %{}, query \\ %{}, headers \\ %{}) do
    payload = body |> Map.new() |> Map.put("token", token)

    case Client.send(svc.client, base_collection_path(svc) <> "/confirm-verification", %{
           method: :post,
           body: payload,
           query: query,
           headers: headers
         }) do
      {:ok, res} ->
        mark_verified(svc, token)
        {:ok, res}

      other ->
        other
    end
  end

  def request_email_change(
        %__MODULE__{} = svc,
        new_email,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload = body |> Map.new() |> Map.put("newEmail", new_email)

    Client.send(svc.client, base_collection_path(svc) <> "/request-email-change", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def confirm_email_change(
        %__MODULE__{} = svc,
        token,
        password,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("token", token)
      |> Map.put("password", password)

    case Client.send(svc.client, base_collection_path(svc) <> "/confirm-email-change", %{
           method: :post,
           body: payload,
           query: query,
           headers: headers
         }) do
      {:ok, res} ->
        clear_if_same_token(svc, token)
        {:ok, res}

      other ->
        other
    end
  end

  def request_otp(%__MODULE__{} = svc, email, body \\ %{}, query \\ %{}, headers \\ %{}) do
    payload = body |> Map.new() |> Map.put("email", email)

    Client.send(svc.client, base_collection_path(svc) <> "/request-otp", %{
      method: :post,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def auth_with_otp(
        %__MODULE__{} = svc,
        otp_id,
        password,
        expand \\ nil,
        fields \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("otpId", otp_id)
      |> Map.put("password", password)

    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    case Client.send(svc.client, base_collection_path(svc) <> "/auth-with-otp", %{
           method: :post,
           body: payload,
           query: params,
           headers: headers
         }) do
      {:ok, data} -> {:ok, auth_response(svc, data)}
      other -> other
    end
  end

  def impersonate(
        %__MODULE__{} = svc,
        record_id,
        duration,
        expand \\ nil,
        fields \\ nil,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("duration", duration)

    params =
      query
      |> Map.new()
      |> maybe_put("expand", expand)
      |> maybe_put("fields", fields)

    enriched_headers =
      case AuthStore.valid?(svc.client.auth_store) do
        true -> Map.put(headers || %{}, "Authorization", AuthStore.token(svc.client.auth_store))
        _ -> headers || %{}
      end

    new_client = Client.new(svc.client.base_url, lang: svc.client.lang)

    case Client.send(new_client, 
           "#{base_collection_path(svc)}/impersonate/#{Utils.encode_path_segment(record_id)}",
           %{method: :post, body: payload, query: params, headers: enriched_headers}
         ) do
      {:ok, %{"token" => token, "record" => record}} ->
        if token && record, do: AuthStore.save(new_client.auth_store, token, record)
        {:ok, new_client}

      other ->
        other
    end
  end

  # Realtime subscriptions
  def subscribe(%__MODULE__{} = svc, topic, callback, query \\ %{}, headers \\ %{}) do
    full_topic = "#{svc.collection}/#{topic}"
    Bosbase.RealtimeService.subscribe(svc.client, full_topic, callback, query, headers)
  end

  def unsubscribe(%__MODULE__{} = svc, topic \\ nil) do
    if topic do
      Bosbase.RealtimeService.unsubscribe(svc.client, "#{svc.collection}/#{topic}")
    else
      Bosbase.RealtimeService.unsubscribe_prefix(svc.client, svc.collection)
    end
  end

  # Helpers
  defp base_collection_path(%__MODULE__{collection: collection}) do
    "/api/collections/#{Utils.encode_path_segment(collection)}"
  end

  defp auth_response(%__MODULE__{} = svc, data) do
    token = data["token"]
    record = data["record"]
    if token && record, do: AuthStore.save(svc.client.auth_store, token, record)
    data
  end

  defp maybe_update_auth_record(%__MODULE__{} = svc, item) do
    current = AuthStore.record(svc.client.auth_store)

    cond do
      is_nil(current) ->
        :ok

      to_string(current["id"]) != to_string(item["id"]) ->
        :ok

      not same_collection?(current, svc.collection) ->
        :ok

      true ->
        merged = Map.merge(current, item || %{})

        merged =
          case {current["expand"], item["expand"]} do
            {%{} = cur, %{} = new} -> Map.put(merged, "expand", Map.merge(cur, new))
            _ -> merged
          end

        AuthStore.save(svc.client.auth_store, AuthStore.token(svc.client.auth_store), merged)
    end
  end

  defp mark_verified(%__MODULE__{} = svc, token) do
    with current when not is_nil(current) <- AuthStore.record(svc.client.auth_store),
         %{"id" => id, "collectionId" => cid} <- decode_token_payload(token),
         true <- to_string(current["id"]) == to_string(id),
         true <- to_string(current["collectionId"]) == to_string(cid),
         false <- current["verified"] do
      AuthStore.save(
        svc.client.auth_store,
        AuthStore.token(svc.client.auth_store),
        Map.put(current, "verified", true)
      )
    else
      _ -> :ok
    end
  end

  defp clear_if_same_token(%__MODULE__{} = svc, token) do
    with current when not is_nil(current) <- AuthStore.record(svc.client.auth_store),
         %{"id" => id, "collectionId" => cid} <- decode_token_payload(token),
         true <- to_string(current["id"]) == to_string(id),
         true <- to_string(current["collectionId"]) == to_string(cid) do
      AuthStore.clear(svc.client.auth_store)
    else
      _ -> :ok
    end
  end

  defp decode_token_payload(token) do
    parts = String.split(token || "", ".")

    with [_, payload, _] <- parts,
         {:ok, decoded} <- Base.url_decode64(payload, padding: false),
         {:ok, map} <- Jason.decode(decoded) do
      map
    else
      _ -> nil
    end
  end

  defp same_collection?(record, collection) do
    to_string(record["collectionId"]) == to_string(collection) ||
      to_string(record["collectionName"]) == to_string(collection)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp is_auth_record?(%__MODULE__{} = svc, record_id) do
    case AuthStore.record(svc.client.auth_store) do
      nil ->
        false

      rec ->
        to_string(rec["id"]) == to_string(record_id) &&
          same_collection?(rec, svc.collection)
    end
  end
end
