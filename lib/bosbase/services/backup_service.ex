defmodule Bosbase.BackupService do
  @moduledoc "Backup management helpers."
  alias Bosbase.{Client, Utils}

  def get_full_list(client, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/backups", %{query: query, headers: headers})
  end

  def create(client, name, body \\ %{}, query \\ %{}, headers \\ %{}) do
    payload = Map.put(Map.new(body || %{}), "name", name)
    Client.send(client, "/api/backups", %{method: :post, body: payload, query: query, headers: headers})
  end

  def upload(client, files, body \\ %{}, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/backups/upload", %{
      method: :post,
      body: body,
      query: query,
      headers: headers,
      files: files
    })
  end

  def delete(client, key, body \\ %{}, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/backups/" <> Utils.encode_path_segment(key), %{
      method: :delete,
      body: body,
      query: query,
      headers: headers
    })
    |> case do
      {:ok, _} -> :ok
      other -> other
    end
  end

  def restore(client, key, body \\ %{}, query \\ %{}, headers \\ %{}) do
    Client.send(client, "/api/backups/#{Utils.encode_path_segment(key)}/restore", %{
      method: :post,
      body: body,
      query: query,
      headers: headers
    })
  end

  def get_download_url(client, token, key, query \\ %{}) do
    params = Map.put(Map.new(query || %{}), "token", token)
    Client.build_url(client, "/api/backups/#{Utils.encode_path_segment(key)}", params)
  end
end
