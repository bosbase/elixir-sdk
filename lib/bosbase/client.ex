defmodule Bosbase.Client do
  @moduledoc """
  BosBase Elixir client mirroring the JS SDK surface.

  The client exposes service helpers and a low-level `send/3` for custom calls.
  """

  alias Bosbase.{
    AuthStore,
    ClientResponseError,
    FileParam,
    Utils
  }

  @user_agent "bosbase-elixir-sdk/0.1.0"

  @type send_options :: %{
          optional(:method) => String.t() | atom(),
          optional(:headers) => map(),
          optional(:query) => map(),
          optional(:body) => any(),
          optional(:files) => %{optional(String.t()) => FileParam.t()},
          optional(:timeout) => non_neg_integer()
        }
  @type t :: %__MODULE__{}

  defstruct base_url: "/",
            lang: "en-US",
            timeout: 30_000,
            auth_store: nil,
            before_send: nil,
            after_send: nil,
            finch_name: Bosbase.Finch,
            record_services: %{}

  @doc """
  Builds a new client instance.

  Options:
    * `:lang` - Accept-Language header (default "en-US")
    * `:auth_store` - custom `Bosbase.AuthStore`
    * `:timeout` - request timeout in milliseconds
    * `:before_send` - hook `(url, options) -> %{url: new_url, options: new_opts}`
    * `:after_send` - hook `(response, data, options) -> data`
    * `:finch_name` - custom Finch pool name
  """
  def new(base_url \\ "/", opts \\ []) do
    %__MODULE__{
      base_url: String.trim_trailing(base_url || "/", "/"),
      lang: Keyword.get(opts, :lang, "en-US"),
      timeout: Keyword.get(opts, :timeout, 30_000),
      auth_store: Keyword.get(opts, :auth_store, AuthStore.new()),
      before_send: Keyword.get(opts, :before_send),
      after_send: Keyword.get(opts, :after_send),
      finch_name: Keyword.get(opts, :finch_name, Bosbase.Finch)
    }
    |> init_services()
  end

  defp init_services(client) do
    client
  end

  @doc "Returns a RecordService for a collection."
  def collection(%__MODULE__{} = client, id_or_name) when is_binary(id_or_name),
    do: Bosbase.RecordService.new(client, id_or_name)

  @doc "Creates a new BatchService builder."
  def create_batch(%__MODULE__{} = client), do: Bosbase.BatchService.new(client)

  @doc "Builds a file download URL for a record file."
  def get_file_url(client, record, filename, opts \\ %{}) do
    Bosbase.FileService.get_url(client, record, filename, opts)
  end

  @doc "Resolves an absolute API URL for a path."
  def build_url(%__MODULE__{} = client, path, query \\ %{}) do
    base =
      client.base_url
      |> case do
        "" -> "/"
        "/" -> "/"
        other -> other
      end

    base =
      if String.ends_with?(base, "/") do
        String.trim_trailing(base, "/")
      else
        base
      end

    rel = String.trim_leading(path || "", "/")

    full =
      case {base, rel} do
        {"/", ""} -> "/"
        {"/", r} -> "/" <> r
        {b, ""} -> b
        {b, r} -> b <> "/" <> r
      end

    query_params = Utils.normalize_query_params(query)

    if query_params == [] do
      full
    else
      full <> "?" <> URI.encode_query(query_params)
    end
  end

  @doc """
  Interpolates placeholders (`{:name}`) in a filter expression.
  """
  def filter(raw, params \\ %{}) when is_binary(raw) do
    Enum.reduce(params || %{}, raw, fn {key, val}, acc ->
      placeholder = "{:" <> to_string(key) <> "}"

      replacement =
        case val do
          true ->
            "true"

          false ->
            "false"

          v when is_number(v) ->
            to_string(v)

          v when is_binary(v) ->
            "'#{String.replace(v, "'", "\\'")}'"

          %DateTime{} = dt ->
            "'#{DateTime.to_iso8601(dt) |> String.replace("T", " ") |> String.replace("Z", "")}'"

          %NaiveDateTime{} = ndt ->
            "'#{NaiveDateTime.to_iso8601(ndt) |> String.replace("T", " ")}'"

          %Date{} = d ->
            "'#{Date.to_iso8601(d)} 00:00:00'"

          nil ->
            "null"

          %{} = map ->
            map
            |> Jason.encode!()
            |> String.replace("'", "\\'")
            |> then(&"'#{&1}'")

          other ->
            other
            |> Jason.encode!()
            |> String.replace("'", "\\'")
            |> then(&"'#{&1}'")
        end

      String.replace(acc, placeholder, replacement)
    end)
  end

  @doc """
  Sends an HTTP request to the BosBase API.
  Returns `{:ok, data}` or `{:error, %ClientResponseError{}}`.
  """
  @spec send(t(), String.t(), send_options() | keyword()) ::
          {:ok, any()} | {:error, ClientResponseError.t()}
  def send(%__MODULE__{} = client, path, options \\ %{}) do
    opts =
      options
      |> to_map()
      |> Map.merge(%{
        method: Map.get(options, :method, Map.get(options, "method", :get)),
        headers: Map.get(options, :headers, Map.get(options, "headers", %{})),
        query: Map.get(options, :query, Map.get(options, "query", %{})),
        body: Map.get(options, :body, Map.get(options, "body")),
        files: Map.get(options, :files, Map.get(options, "files", %{})),
        timeout: Map.get(options, :timeout, Map.get(options, "timeout", client.timeout))
      })

    method_atom = normalize_method(opts.method)
    query = Map.new(opts.query || %{})
    url = build_url(client, path, query)

    headers =
      opts.headers
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.merge(%{
        "Accept-Language" => client.lang,
        "User-Agent" => @user_agent
      })
      |> maybe_add_auth(client)

    hook_opts = %{
      method: method_atom,
      headers: headers,
      query: query,
      body: opts.body,
      files: opts.files,
      timeout: opts.timeout
    }

    {maybe_url, hook_opts} = apply_before_send(client, url, hook_opts)
    hook_opts = Map.update(hook_opts, :method, method_atom, &normalize_method/1)
    url = build_url(client, path, hook_opts.query || %{})
    url = maybe_url || url

    request_opts =
      [
        method: hook_opts.method,
        url: url,
        headers: Map.to_list(hook_opts.headers || %{}),
        finch: client.finch_name,
        receive_timeout: hook_opts.timeout,
        connect_timeout: hook_opts.timeout,
        pool_timeout: hook_opts.timeout
      ]
      |> attach_body(hook_opts.body, hook_opts.files)

    case Req.request(request_opts) do
      {:ok, %Req.Response{} = resp} ->
        data = maybe_decode_body(resp.body)

        with_data =
          case client.after_send do
            fun when is_function(fun, 3) -> safe_after_send(fun, resp, data, hook_opts)
            fun when is_function(fun, 2) -> safe_after_send(fun, resp, data, hook_opts)
            _ -> {:ok, data}
          end

        case with_data do
          {:error, %ClientResponseError{} = err} ->
            {:error, err}

          {:ok, new_data} ->
            if resp.status >= 400 do
              {:error,
               %ClientResponseError{
                 url: url,
                 status: resp.status,
                 response: to_map(new_data)
               }}
            else
              {:ok, new_data}
            end
        end

      {:error, exception} ->
        {:error,
         %ClientResponseError{
           url: url,
           original_error: exception,
           is_abort: timeout?(exception)
         }}
    end
  end

  defp apply_before_send(%__MODULE__{before_send: nil}, url, opts), do: {url, opts}

  defp apply_before_send(%__MODULE__{before_send: hook}, url, opts) do
    try do
      case hook.(url, opts) do
        %{url: new_url, options: new_opts} ->
          {new_url || url, Map.merge(opts, to_map(new_opts || %{}))}

        %{url: new_url} ->
          {new_url || url, opts}

        %{options: new_opts} ->
          {url, Map.merge(opts, to_map(new_opts || %{}))}

        %{} = new_opts ->
          {url, Map.merge(opts, to_map(new_opts))}

        _ ->
          {url, opts}
      end
    rescue
      _ -> {url, opts}
    end
  end

  defp attach_body(opts, body, files) do
    cond do
      files != nil and files != %{} ->
        payload = Utils.to_serializable(body) || %{}
        json_payload = Jason.encode!(payload)

        fields =
          [{"@jsonPayload", json_payload}] ++
            Enum.map(files || %{}, fn {field, file} ->
              %FileParam{filename: fname, content: content, content_type: ctype} =
                normalize_file(file, field)

              {field,
               {content,
                [
                  filename: fname || field,
                  content_type: ctype || "application/octet-stream"
                ]}}
            end)

        Keyword.put(opts, :form_multipart, fields)

      is_nil(body) ->
        opts

      true ->
        Keyword.put(opts, :json, Utils.to_serializable(body))
    end
  end

  defp maybe_decode_body(body), do: body

  defp normalize_method(nil), do: :get
  defp normalize_method(atom) when is_atom(atom), do: atom
  defp normalize_method(str) when is_binary(str), do: String.downcase(str) |> String.to_atom()

  defp normalize_file(%FileParam{} = file, _field), do: file

  defp normalize_file(%{filename: _} = file, field) do
    %FileParam{
      filename: Map.get(file, :filename) || Map.get(file, "filename") || field,
      content: Map.get(file, :content) || Map.get(file, "content"),
      content_type: Map.get(file, :content_type) || Map.get(file, "content_type")
    }
  end

  defp normalize_file(content, field) do
    %FileParam{filename: field, content: content, content_type: "application/octet-stream"}
  end

  defp to_map(%{} = map), do: map
  defp to_map(list) when is_list(list), do: Enum.into(list, %{})
  defp to_map(_), do: %{}

  defp timeout?(%Finch.Error{reason: :timeout}), do: true
  defp timeout?(%Mint.TransportError{reason: :timeout}), do: true
  defp timeout?(_), do: false

  defp maybe_add_auth(headers, %__MODULE__{auth_store: %AuthStore{} = store}) do
    case {Map.get(headers, "Authorization"), AuthStore.valid?(store)} do
      {nil, true} -> Map.put(headers, "Authorization", AuthStore.token(store))
      _ -> headers
    end
  end

  defp safe_after_send(fun, resp, data, opts) do
    try do
      case :erlang.fun_info(fun, :arity) do
        {:arity, 3} -> {:ok, fun.(resp, data, opts)}
        {:arity, 2} -> {:ok, fun.(resp, data)}
        _ -> {:ok, data}
      end
    rescue
      _ ->
        {:error,
         %ClientResponseError{
           url: resp.url,
           response: to_map(data),
           status: resp.status
         }}
    end
  end

  @doc false
  def user_agent, do: @user_agent
end
