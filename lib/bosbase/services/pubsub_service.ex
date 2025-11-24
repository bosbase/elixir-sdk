defmodule Bosbase.PubSubService do
  @moduledoc "WebSocket pub/sub helper."
  use WebSockex

  alias Bosbase.Client

  defstruct [:client, subs: %{}]

  ## Public API

  def publish(%Client{} = client, topic, data) do
    with {:ok, pid} <- ensure_socket(client) do
      WebSockex.cast(pid, {:publish, topic, data})
    end
  end

  def subscribe(%Client{} = client, topic, callback) when is_function(callback, 1) do
    with {:ok, pid} <- ensure_socket(client) do
      case GenServer.call(pid, {:subscribe, topic, callback}) do
        {:ok, id} -> {:ok, fn -> unsubscribe_by_id(client, topic, id) end}
        other -> other
      end
    end
  end

  def unsubscribe(%Client{} = client, topic) do
    with {:ok, pid} <- ensure_socket(client) do
      WebSockex.cast(pid, {:unsubscribe, topic})
    end
  end

  def unsubscribe_by_id(%Client{} = client, topic, id) do
    with {:ok, pid} <- ensure_socket(client) do
      WebSockex.cast(pid, {:unsubscribe_id, topic, id})
    end
  end

  ## WebSockex callbacks

  def start_link(%Client{} = client) do
    url = build_ws_url(client)
    WebSockex.start_link(url, __MODULE__, %{client: client, subs: %{}}, name: via(client))
  end

  @impl true
  def handle_connect(_conn, state) do
    Enum.each(Map.keys(state.subs), fn topic -> send_subscribe(state, topic) end)
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, topic, data}, state) do
    payload = %{"type" => "publish", "topic" => topic, "data" => data}
    _ = WebSockex.send_frame(self(), {:text, Jason.encode!(payload)})
    {:noreply, state}
  end

  def handle_cast({:unsubscribe, topic}, state) do
    payload = %{"type" => "unsubscribe", "topic" => topic}
    _ = WebSockex.send_frame(self(), {:text, Jason.encode!(payload)})
    {:noreply, %{state | subs: Map.delete(state.subs, topic)}}
  end

  def handle_cast({:unsubscribe_id, topic, id}, state) do
    listeners = Map.get(state.subs, topic, [])
    filtered = Enum.reject(listeners, fn %{id: lid} -> lid == id end)

    cond do
      filtered == [] ->
        payload = %{"type" => "unsubscribe", "topic" => topic}
        _ = WebSockex.send_frame(self(), {:text, Jason.encode!(payload)})
        {:noreply, %{state | subs: Map.delete(state.subs, topic)}}

      true ->
        {:noreply, %{state | subs: Map.put(state.subs, topic, filtered)}}
    end
  end

  def handle_call({:subscribe, topic, callback}, _from, state) do
    counter = Enum.reduce(state.subs, 0, fn {_k, v}, acc -> acc + length(v) end) + 1
    listener = %{id: "l-#{counter}", callback: callback}
    listeners = Map.get(state.subs, topic, [])
    new_state = %{state | subs: Map.put(state.subs, topic, listeners ++ [listener])}
    send_subscribe(new_state, topic)
    {:reply, {:ok, listener.id}, new_state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"type" => "message", "topic" => topic} = data} ->
        Enum.each(Map.get(state.subs, topic, []), fn %{callback: cb} ->
          safe_invoke(cb, %{
            "id" => data["id"],
            "topic" => topic,
            "created" => data["created"],
            "data" => data["data"]
          })
        end)

        {:ok, state}

      {:ok, _} ->
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_disconnect(_status, state) do
    {:reconnect, state}
  end

  ## Internal helpers

  defp ensure_socket(%Client{} = client) do
    case WebSockex.start_link(build_ws_url(client), __MODULE__, %{client: client, subs: %{}},
           name: via(client)
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  defp via(%Client{} = client) do
    key = :erlang.phash2({client.base_url, client.auth_store})
    {:via, :global, {:bosbase_pubsub, key}}
  end

  defp build_ws_url(%Client{} = client) do
    query =
      case Bosbase.AuthStore.valid?(client.auth_store) do
        true -> %{"token" => Bosbase.AuthStore.token(client.auth_store)}
        _ -> %{}
      end

    Client.build_url(client, "/api/pubsub", query)
    |> URI.parse()
    |> convert_scheme()
    |> URI.to_string()
  end

  defp convert_scheme(%URI{scheme: "https"} = uri), do: %URI{uri | scheme: "wss"}
  defp convert_scheme(%URI{} = uri), do: %URI{uri | scheme: "ws"}

  defp send_subscribe(_state, topic) do
    payload = %{"type" => "subscribe", "topic" => topic}
    _ = WebSockex.send_frame(self(), {:text, Jason.encode!(payload)})
    :ok
  end

  defp safe_invoke(fun, payload) do
    try do
      fun.(payload)
    rescue
      _ -> :ok
    end
  end
end
