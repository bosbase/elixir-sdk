defmodule Bosbase.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Bosbase.Finch},
      {Task.Supervisor, name: Bosbase.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Bosbase.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
