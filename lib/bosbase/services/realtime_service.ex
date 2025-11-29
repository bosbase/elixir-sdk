defmodule Bosbase.RealtimeService do
  @moduledoc """
  Minimal Server-Sent Events client used for realtime subscriptions.
  """
  use GenServer
  alias Bosbase.Client

  @connect_path "/api/realtime"

  ## Public API

  def subscribe(%Client{} = client, topic, callback, query \\ %{}, headers \\ %{})
      when is_function(callback, 1) do
    with {:ok, pid} <- ensure_server(client) do
      GenServer.call(pid, {:subscribe, topic, callback, query || %{}, headers || %{}})
      |> case do
        {:ok, id} -> {:ok, fn -> unsubscribe_by_id(client, topic, id) end}
        other -> other
      end
    end
  end

  def unsubscribe(%Client{} = client, topic \\ nil) do
    with {:ok, pid} <- ensure_server(client) do
      GenServer.cast(pid, {:unsubscribe, topic})
    end
  end

  def unsubscribe_by_id(%Client{} = client, topic, id) do
    with {:ok, pid} <- ensure_server(client) do
      GenServer.cast(pid, {:unsubscribe_id, topic, id})
    end
  end

  def unsubscribe_prefix(%Client{} = client, prefix) do
    with {:ok, pid} <- ensure_server(client) do
      GenServer.cast(pid, {:unsubscribe_prefix, prefix})
    end
  end

  def ensure_connected(%Client{} = client, timeout_ms \\ 10_000) do
    with {:ok, pid} <- ensure_server(client) do
      GenServer.call(pid, :ensure_connected, timeout_ms)
    end
  end

  ## GenServer

  def start_link(client) do
    GenServer.start_link(__MODULE__, client, name: via(client))
  end

  @impl true
  def init(client) do
    state = %{
      client: client,
      subscriptions: %{},
      buffer: "",
      stream_task: nil,
      client_id: nil,
      ready: false,
      counter: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:ensure_connected, _from, state) do
    new_state = maybe_start_stream(state)

    if new_state.ready do
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :not_connected}, new_state}
    end
  end

  def handle_call({:subscribe, topic, callback, query, headers}, _from, state) do
    cond do
      is_nil(topic) or topic == "" ->
        {:reply, {:error, "topic must be set"}, state}

      true ->
        key = build_key(topic, query, headers)
        counter = state.counter + 1
        listener = %{id: "l-#{counter}", callback: callback}
        listeners = Map.get(state.subscriptions, key, []) ++ [listener]

        new_state = %{
          state
          | subscriptions: Map.put(state.subscriptions, key, listeners),
            counter: counter
        }

        new_state = maybe_start_stream(new_state)
        if new_state.ready, do: submit_subscriptions(new_state)
        {:reply, {:ok, listener.id}, new_state}
    end
  end

  @impl true
  def handle_cast({:unsubscribe, topic}, state) do
    new_state =
      cond do
        is_nil(topic) or topic == "" ->
          %{state | subscriptions: %{}}

        true ->
          filtered =
            state.subscriptions
            |> Enum.reject(fn {key, _} ->
              key == topic or String.starts_with?(key, topic <> "?")
            end)
            |> Map.new()

          %{state | subscriptions: filtered}
      end

    if map_size(new_state.subscriptions) == 0 do
      if new_state.stream_task, do: Process.exit(new_state.stream_task, :kill)
      {:noreply, %{new_state | stream_task: nil, ready: false, client_id: nil}}
    else
      submit_subscriptions(new_state)
      {:noreply, new_state}
    end
  end

  def handle_cast({:unsubscribe_prefix, prefix}, state) do
    handle_cast({:unsubscribe, prefix}, state)
  end

  def handle_cast({:unsubscribe_id, topic, id}, state) do
    new_subs =
      state.subscriptions
      |> Enum.map(fn {key, listeners} ->
        if key == topic or String.starts_with?(key, topic <> "?") do
          {key, Enum.reject(listeners, fn l -> l.id == id end)}
        else
          {key, listeners}
        end
      end)
      |> Enum.reject(fn {_k, listeners} -> listeners == [] end)
      |> Map.new()

    new_state = %{state | subscriptions: new_subs}

    if map_size(new_state.subscriptions) == 0 do
      if new_state.stream_task, do: Process.exit(new_state.stream_task, :kill)
      {:noreply, %{new_state | stream_task: nil, ready: false, client_id: nil}}
    else
      submit_subscriptions(new_state)
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:realtime_event, %{"event" => "PB_CONNECT"} = evt}, state) do
    payload = evt["data"] || %{}
    client_id = payload["clientId"] || evt["id"]
    submit_subscriptions(%{state | client_id: client_id, ready: true})
    {:noreply, %{state | client_id: client_id, ready: true}}
  end

  @impl true
  def handle_info({:realtime_event, evt}, state) do
    topic = evt["event"] || "message"
    data = evt["data"] || %{}
    listeners = Map.get(state.subscriptions, topic, [])

    Enum.each(listeners, fn %{callback: cb} ->
      safe_invoke(cb, data)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:realtime_done, state) do
    if map_size(state.subscriptions) > 0 do
      {:noreply, %{state | stream_task: nil, ready: false, client_id: nil}, {:continue, :restart}}
    else
      {:noreply, %{state | stream_task: nil, ready: false, client_id: nil}}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _}, %{stream_task: pid} = state) do
    {:noreply, %{state | stream_task: nil, ready: false, client_id: nil}}
  end

  @impl true
  def handle_info({:realtime_error, _reason}, state) do
    {:noreply, %{state | stream_task: nil, ready: false, client_id: nil}}
  end

  @impl true
  def handle_continue(:restart, state) do
    new_state = maybe_start_stream(state)
    {:noreply, new_state}
  end

  ## Internal

  defp ensure_server(%Client{} = client) do
    case GenServer.start_link(__MODULE__, client, name: via(client)) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  defp via(%Client{} = client) do
    key = :erlang.phash2({client.base_url, client.auth_store})
    {:via, :global, {:bosbase_realtime, key}}
  end

  defp maybe_start_stream(%{stream_task: pid} = state) when is_pid(pid), do: state

  defp maybe_start_stream(state) do
    task =
      Task.Supervisor.async_nolink(Bosbase.TaskSupervisor, fn ->
        stream_loop(state.client, self())
      end)

    %{state | stream_task: task.pid}
  end

  defp submit_subscriptions(%{client_id: nil}), do: :ok

  defp submit_subscriptions(state) do
    payload = %{
      "clientId" => state.client_id,
      "subscriptions" => Map.keys(state.subscriptions)
    }

    _ = Client.send(state.client, @connect_path, %{method: :post, body: payload})
    :ok
  end

  defp stream_loop(client, server) do
    url = Client.build_url(client, @connect_path, %{})

    headers =
      %{
        "Accept" => "text/event-stream",
        "Cache-Control" => "no-store",
        "Accept-Language" => client.lang,
        "User-Agent" => Client.user_agent()
      }
      |> maybe_put_auth(client)
      |> Enum.to_list()

    req = Finch.build(:get, url, headers)

    _ =
      Finch.stream(client.finch_name, req, %{buffer: ""}, fn
        {:status, _req, _status}, acc ->
          acc

        {:headers, _req, _headers}, acc ->
          acc

        {:data, _req, chunk}, %{buffer: buffer} = acc ->
          {events, rest} = parse_sse(buffer <> chunk)
          Enum.each(events, fn evt -> send(server, {:realtime_event, evt}) end)
          %{acc | buffer: rest}

        {:done, _req}, acc ->
          send(server, :realtime_done)
          acc
      end)

    send(server, :realtime_done)
  rescue
    _ ->
      send(server, {:realtime_error, :connection_failed})
  end

  defp maybe_put_auth(headers, client) do
    case Bosbase.AuthStore.valid?(client.auth_store) do
      true -> Map.put(headers, "Authorization", Bosbase.AuthStore.token(client.auth_store))
      _ -> headers
    end
  end

  defp parse_sse(data) do
    lines = String.split(data, ~r/\r?\n/)
    {events, rest} = do_parse(lines, %{"event" => "message", "data" => "", "id" => ""}, [])
    {Enum.reverse(events), rest}
  end

  defp do_parse([], current, events) do
    {events, current["data"]}
  end

  defp do_parse([line | rest], current, events) do
    cond do
      line == "" ->
        evt = Map.put(current, "data", decode_json(current["data"]))
        do_parse(rest, %{"event" => "message", "data" => "", "id" => ""}, [evt | events])

      String.starts_with?(line, ":") ->
        do_parse(rest, current, events)

      true ->
        [field, value] =
          case String.split(line, ":", parts: 2) do
            [f, v] -> [f, String.trim_leading(v, " ")]
            [f] -> [f, ""]
          end

        updated =
          case field do
            "event" -> Map.put(current, "event", value)
            "data" -> Map.update(current, "data", value <> "\n", fn d -> d <> value <> "\n" end)
            "id" -> Map.put(current, "id", value)
            _ -> current
          end

        do_parse(rest, updated, events)
    end
  end

  defp decode_json(data) do
    payload = String.trim_trailing(data || "", "\n")

    case Jason.decode(payload) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp build_key(topic, query, headers) do
    opts = %{}
    opts = if map_size(query || %{}) > 0, do: Map.put(opts, :query, query), else: opts
    opts = if map_size(headers || %{}) > 0, do: Map.put(opts, :headers, headers), else: opts

    if map_size(opts) == 0 do
      topic
    else
      encoded = opts |> Jason.encode!() |> URI.encode()
      topic <> "?options=" <> encoded
    end
  end

  defp safe_invoke(fun, payload) do
    try do
      fun.(payload)
    rescue
      _ -> :ok
    end
  end
end
