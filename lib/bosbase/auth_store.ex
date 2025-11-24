defmodule Bosbase.AuthStore do
  @moduledoc """
  In-memory auth store mirroring the JS SDK behavior.
  Keeps the current token and auth record and notifies listeners on change.
  """

  defstruct [:agent]

  @type t :: %__MODULE__{agent: pid()}
  @type listener_id :: String.t()

  @doc "Creates a new store backed by an Agent."
  @spec new() :: t()
  def new do
    {:ok, pid} =
      Agent.start_link(fn ->
        %{token: "", record: nil, listeners: %{}, counter: 0}
      end)

    %__MODULE__{agent: pid}
  end

  @doc "Returns the saved token or an empty string."
  @spec token(t()) :: String.t()
  def token(%__MODULE__{agent: pid}) do
    Agent.get(pid, & &1.token)
  end

  @doc "Returns a shallow copy of the stored auth record."
  @spec record(t()) :: map() | nil
  def record(%__MODULE__{agent: pid}) do
    Agent.get(pid, fn
      %{record: nil} -> nil
      %{record: rec} -> Map.new(rec)
    end)
  end

  @doc "Checks if a non-expired JWT token is stored."
  @spec valid?(t()) :: boolean()
  def valid?(store) do
    with token when token not in [nil, ""] <- token(store),
         [_h, payload, _s] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(payload, padding: false),
         {:ok, data} <- Jason.decode(json),
         exp when is_integer(exp) <- normalize_exp(data["exp"]) do
      exp > System.os_time(:second)
    else
      _ -> false
    end
  end

  defp normalize_exp(exp) when is_integer(exp), do: exp
  defp normalize_exp(exp) when is_float(exp), do: trunc(exp)
  defp normalize_exp(_), do: nil

  @doc "Registers a listener callback invoked with `{token, record}` on change."
  @spec add_listener(t(), (String.t(), map() | nil -> any())) :: listener_id()
  def add_listener(%__MODULE__{agent: pid}, fun) when is_function(fun, 2) do
    Agent.get_and_update(pid, fn state ->
      id = "listener-" <> Integer.to_string(state.counter + 1)
      listeners = Map.put(state.listeners, id, fun)
      {id, %{state | listeners: listeners, counter: state.counter + 1}}
    end)
  end

  @doc "Removes a listener by id."
  @spec remove_listener(t(), listener_id()) :: :ok
  def remove_listener(%__MODULE__{agent: pid}, id) do
    Agent.update(pid, fn state ->
      %{state | listeners: Map.delete(state.listeners, id)}
    end)
  end

  @doc "Saves token and record, notifying listeners."
  @spec save(t(), String.t(), map() | nil) :: :ok
  def save(%__MODULE__{agent: pid} = _store, token, record) do
    listeners =
      Agent.get_and_update(pid, fn state ->
        %{listeners: listeners} = state
        {Map.values(listeners), %{state | token: token || "", record: record}}
      end)

    Enum.each(listeners, fn fun ->
      safe_run(fun, token || "", record)
    end)

    :ok
  end

  @doc "Clears token and record."
  @spec clear(t()) :: :ok
  def clear(store), do: save(store, "", nil)

  defp safe_run(fun, token, record) do
    try do
      fun.(token, record)
    rescue
      _ -> :ok
    end
  end
end
