defmodule Bosbase do
  @moduledoc """
  BosBase Elixir SDK.

  The API mirrors the JS SDK surface: construct a client with `new/2`, then access
  helpers like `collection/2`, `create_batch/1`, `files`, `realtime`, `pubsub`,
  `vectors`, `llm_documents`, `langchaingo`, `graphql`, `settings`, `cache`, `sql`, etc.
  """

  alias Bosbase.Client

  @doc "Builds a new client."
  def new(base_url \\ "/", opts \\ []), do: Client.new(base_url, opts)

  @doc "Returns a RecordService for a collection."
  def collection(client, id), do: Client.collection(client, id)

  @doc "Creates a batch builder."
  def create_batch(client), do: Client.create_batch(client)

  @doc "Helper to build filter expressions."
  def filter(raw, params \\ %{}), do: Client.filter(raw, params)

  @doc "Convenience accessors for services."
  def files, do: Bosbase.FileService
  def settings, do: Bosbase.SettingsService
  def health, do: Bosbase.HealthService
  def logs, do: Bosbase.LogService
  def realtime, do: Bosbase.RealtimeService
  def pubsub, do: Bosbase.PubSubService
  def backups, do: Bosbase.BackupService
  def crons, do: Bosbase.CronService
  def vectors, do: Bosbase.VectorService
  def llm_documents, do: Bosbase.LLMDocumentService
  def langchaingo, do: Bosbase.LangChaingoService
  def sql, do: Bosbase.SQLService
  def caches, do: Bosbase.CacheService
  def graphql, do: Bosbase.GraphQLService
  def collections, do: Bosbase.CollectionService
end
