defmodule Bosbase.CollectionService do
  @moduledoc "Admin collection helpers."

  alias Bosbase.{BaseCrudService, ClientResponseError, Utils}

  defstruct [:client, :crud]

  def new(client) do
    crud = BaseCrudService.new(client, fn -> "/api/collections" end)
    %__MODULE__{client: client, crud: crud}
  end

  def get_full_list(%__MODULE__{crud: crud}, batch, opts \\ %{}),
    do: BaseCrudService.get_full_list(crud, batch, opts)

  def get_list(%__MODULE__{crud: crud}, opts \\ %{}), do: BaseCrudService.get_list(crud, opts)

  def get_one(%__MODULE__{crud: crud}, id, opts \\ %{}),
    do: BaseCrudService.get_one(crud, id, opts)

  def get_first_list_item(%__MODULE__{crud: crud}, filter, opts \\ %{}),
    do: BaseCrudService.get_first_list_item(crud, filter, opts)

  def create(%__MODULE__{crud: crud}, opts \\ %{}), do: BaseCrudService.create(crud, opts)
  def update(%__MODULE__{crud: crud}, id, opts \\ %{}), do: BaseCrudService.update(crud, id, opts)
  def delete(%__MODULE__{crud: crud}, id, opts \\ %{}), do: BaseCrudService.delete(crud, id, opts)

  def delete_collection(%__MODULE__{} = svc, id_or_name, opts \\ %{}),
    do: delete(svc, id_or_name, opts)

  def truncate(%__MODULE__{} = svc, id_or_name, body \\ %{}, query \\ %{}, headers \\ %{}) do
    path =
      "#{BaseCrudService.base_path(svc.crud)}/#{Utils.encode_path_segment(id_or_name)}/truncate"

    svc.client.send(path, %{method: :delete, body: body, query: query, headers: headers})
  end

  def import_collections(
        %__MODULE__{} = svc,
        collections,
        delete_missing \\ false,
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    payload =
      body
      |> Map.new()
      |> Map.put("collections", collections)
      |> Map.put("deleteMissing", delete_missing)

    svc.client.send(BaseCrudService.base_path(svc.crud) <> "/import", %{
      method: :put,
      body: payload,
      query: query,
      headers: headers
    })
  end

  def get_scaffolds(%__MODULE__{} = svc, body \\ %{}, query \\ %{}, headers \\ %{}) do
    svc.client.send(BaseCrudService.base_path(svc.crud) <> "/meta/scaffolds", %{
      body: body,
      query: query,
      headers: headers
    })
  end

  def create_base(
        %__MODULE__{} = svc,
        name,
        overrides \\ %{},
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    create_from_scaffold(svc, "base", name, overrides, body, query, headers)
  end

  def create_auth(
        %__MODULE__{} = svc,
        name,
        overrides \\ %{},
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    create_from_scaffold(svc, "auth", name, overrides, body, query, headers)
  end

  def create_view(
        %__MODULE__{} = svc,
        name,
        view_query \\ nil,
        overrides \\ %{},
        body \\ %{},
        query \\ %{},
        headers \\ %{}
      ) do
    scaffold_overrides =
      overrides
      |> Map.new()
      |> maybe_put("viewQuery", view_query)

    create_from_scaffold(svc, "view", name, scaffold_overrides, body, query, headers)
  end

  def add_index(
        %__MODULE__{} = svc,
        collection,
        columns,
        unique \\ false,
        index_name \\ nil,
        query \\ %{},
        headers \\ %{}
      ) do
    if Enum.empty?(columns) do
      {:error,
       %ClientResponseError{response: %{"message" => "at least one column must be specified"}}}
    else
      with {:ok, current} <- get_one(svc, collection, %{query: query, headers: headers}),
           true <- is_map(current) do
        cname = current["name"] || collection
        idx_name = index_name || "idx_#{cname}_#{Enum.join(columns, "_")}"
        columns_sql = Enum.map(columns, &"`#{&1}`") |> Enum.join(", ")

        sql =
          "CREATE #{if(unique, do: "UNIQUE ", else: "")}INDEX `#{idx_name}` ON `#{cname}` (#{columns_sql})"

        indexes = Map.get(current, "indexes", [])

        if sql in indexes do
          {:error, %ClientResponseError{response: %{"message" => "index already exists"}}}
        else
          updated = Map.put(current, "indexes", indexes ++ [sql])
          update(svc, collection, %{body: updated, query: query, headers: headers})
        end
      end
    end
  end

  def remove_index(%__MODULE__{} = svc, collection, columns, query \\ %{}, headers \\ %{}) do
    if Enum.empty?(columns) do
      {:error,
       %ClientResponseError{response: %{"message" => "at least one column must be specified"}}}
    else
      with {:ok, current} <- get_one(svc, collection, %{query: query, headers: headers}),
           indexes when is_list(indexes) <- Map.get(current, "indexes", []) do
        filtered =
          Enum.reject(indexes, fn idx ->
            Enum.all?(columns, fn col ->
              String.contains?(to_string(idx), "`#{col}`") or
                String.contains?(to_string(idx), "(#{col}")
            end)
          end)

        if length(filtered) == length(indexes) do
          {:error, %ClientResponseError{response: %{"message" => "index not found"}}}
        else
          update(svc, collection, %{
            body: Map.put(current, "indexes", filtered),
            query: query,
            headers: headers
          })
        end
      end
    end
  end

  def get_indexes(%__MODULE__{} = svc, collection, query \\ %{}, headers \\ %{}) do
    with {:ok, current} <- get_one(svc, collection, %{query: query, headers: headers}) do
      {:ok, Enum.map(current["indexes"] || [], &to_string/1)}
    end
  end

  def get_schema(%__MODULE__{} = svc, collection, query \\ %{}, headers \\ %{}) do
    svc.client.send(
      "#{BaseCrudService.base_path(svc.crud)}/#{Utils.encode_path_segment(collection)}/schema",
      %{query: query, headers: headers}
    )
  end

  defp create_from_scaffold(
         %__MODULE__{} = svc,
         scaffold_type,
         name,
         overrides,
         body,
         query,
         headers
       ) do
    with {:ok, scaffolds} <- get_scaffolds(svc, nil, query, headers),
         true <- is_map(scaffolds),
         scaffold when is_map(scaffold) <- Map.get(scaffolds, scaffold_type) do
      data =
        scaffold
        |> Map.put("name", name)
        |> Map.merge(overrides || %{})
        |> Map.merge(body || %{})

      create(svc, %{body: data, query: query, headers: headers})
    else
      _ ->
        {:error,
         %ClientResponseError{
           response: %{"message" => "scaffold for type '#{scaffold_type}' not found"}
         }}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end
