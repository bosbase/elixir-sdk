defmodule Bosbase.BaseCrudService do
  @moduledoc false
  alias Bosbase.{Client, ClientResponseError, Utils}

  defstruct [:client, :path_fun]

  @type t :: %__MODULE__{client: any(), path_fun: (-> String.t())}

  def new(client, path_fun) when is_function(path_fun, 0) do
    %__MODULE__{client: client, path_fun: path_fun}
  end

  def base_path(%__MODULE__{path_fun: fun}), do: fun.()

  def get_full_list(crud, batch, opts \\ %{})

  def get_full_list(_crud, batch, _opts) when batch <= 0 do
    {:error,
     %ClientResponseError{
       status: 400,
       response: %{"message" => "batch must be > 0"}
     }}
  end

  def get_full_list(%__MODULE__{} = crud, batch, opts) do
    do_full_list(crud, batch, opts || %{}, 1, [])
  end

  defp do_full_list(crud, batch, opts, page, acc) do
    list_opts =
      opts
      |> Map.put(:page, page)
      |> Map.put(:per_page, batch)
      |> Map.put(:skip_total, true)

    case get_list(crud, list_opts) do
      {:error, err} ->
        {:error, err}

      {:ok, %{"items" => items} = res} ->
        per_page = res["perPage"] || res["per_page"] || batch
        combined = acc ++ List.wrap(items)

        if length(items) < per_page do
          {:ok, combined}
        else
          do_full_list(crud, batch, opts, page + 1, combined)
        end

      {:ok, _} ->
        {:ok, acc}
    end
  end

  def get_list(crud, opts \\ %{})
  def get_list(%__MODULE__{} = crud, opts) do
    options = Map.merge(%{page: 1, per_page: 30}, opts || %{})
    params = Map.new(options[:query] || options["query"] || %{})

    params =
      params
      |> Map.put("page", options[:page] || options["page"] || 1)
      |> Map.put("perPage", options[:per_page] || options["per_page"] || 30)
      |> maybe_put(options, [:skip_total, "skip_total", :skipTotal, "skipTotal"], "skipTotal")
      |> maybe_put(options, [:filter, "filter"], "filter")
      |> maybe_put(options, [:sort, "sort"], "sort")
      |> maybe_put(options, [:expand, "expand"], "expand")
      |> maybe_put(options, [:fields, "fields"], "fields")

    Client.send(crud.client, base_path(crud), %{
      method: :get,
      query: params,
      headers: options[:headers] || options["headers"]
    })
  end

  def get_one(crud, record_id, opts \\ %{})

  def get_one(crud, record_id, _opts) when record_id in [nil, ""] do
    {:error,
     %ClientResponseError{
       url: Client.build_url(crud.client, base_path(crud) <> "/", %{}),
       status: 404,
       response: %{
         "code" => 404,
         "message" => "Missing required record id.",
         "data" => %{}
       }
     }}
  end

  def get_one(%__MODULE__{} = crud, record_id, opts) do
    options = opts || %{}
    params = Map.new(options[:query] || options["query"] || %{})

    params =
      params
      |> maybe_put(options, [:expand, "expand"], "expand")
      |> maybe_put(options, [:fields, "fields"], "fields")

    encoded = Utils.encode_path_segment(record_id)

    Client.send(crud.client, "#{base_path(crud)}/#{encoded}", %{
      method: :get,
      query: params,
      headers: options[:headers] || options["headers"]
    })
  end

  def get_first_list_item(crud, filter, opts \\ %{})
  def get_first_list_item(%__MODULE__{} = crud, filter, opts) do
    options = opts || %{}

    list_opts = %{
      page: 1,
      per_page: 1,
      skip_total: true,
      filter: filter,
      expand: options[:expand] || options["expand"],
      fields: options[:fields] || options["fields"],
      query: options[:query] || options["query"],
      headers: options[:headers] || options["headers"]
    }

    case get_list(crud, list_opts) do
      {:error, err} ->
        {:error, err}

      {:ok, %{"items" => [first | _]}} ->
        {:ok, first}

      {:ok, _} ->
        {:error,
         %ClientResponseError{
           status: 404,
           response: %{
             "code" => 404,
             "message" => "The requested resource wasn't found.",
             "data" => %{}
           }
         }}
    end
  end

  def create(crud, opts \\ %{})
  def create(%__MODULE__{} = crud, opts) do
    options = opts || %{}
    params = Map.new(options[:query] || options["query"] || %{})

    params =
      params
      |> maybe_put(options, [:expand, "expand"], "expand")
      |> maybe_put(options, [:fields, "fields"], "fields")

    Client.send(crud.client, base_path(crud), %{
      method: :post,
      body: options[:body] || options["body"],
      query: params,
      files: options[:files] || options["files"] || %{},
      headers: options[:headers] || options["headers"]
    })
  end

  def update(crud, record_id, opts \\ %{})
  def update(%__MODULE__{} = crud, record_id, opts) do
    options = opts || %{}
    params = Map.new(options[:query] || options["query"] || %{})

    params =
      params
      |> maybe_put(options, [:expand, "expand"], "expand")
      |> maybe_put(options, [:fields, "fields"], "fields")

    encoded = Utils.encode_path_segment(record_id)

    Client.send(crud.client, "#{base_path(crud)}/#{encoded}", %{
      method: :patch,
      body: options[:body] || options["body"],
      query: params,
      files: options[:files] || options["files"] || %{},
      headers: options[:headers] || options["headers"]
    })
  end

  def delete(crud, record_id, opts \\ %{})
  def delete(%__MODULE__{} = crud, record_id, opts) do
    options = opts || %{}
    encoded = Utils.encode_path_segment(record_id)

    Client.send(crud.client, "#{base_path(crud)}/#{encoded}", %{
      method: :delete,
      body: options[:body] || options["body"],
      query: options[:query] || options["query"],
      headers: options[:headers] || options["headers"]
    })
    |> case do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  defp maybe_put(params, _options, _keys, _target) when params == nil, do: params

  defp maybe_put(params, options, keys, target_key) do
    keys
    |> Enum.find_value(fn k -> Map.get(options, k) end)
    |> case do
      nil -> params
      "" -> params
      value -> Map.put(params, target_key, value)
    end
  end
end
