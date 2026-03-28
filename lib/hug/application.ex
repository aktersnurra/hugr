defmodule Hug.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hug.Capability.Registry,
      {Task.Supervisor, name: Hug.TaskSupervisor},
      Hug.Memory.ConversationLogger,
      Hug.Agent
    ]

    opts = [strategy: :one_for_one, name: Hug.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        register_capabilities()
        {:ok, pid}

      error ->
        error
    end
  end

  defp register_capabilities do
    Hug.Capability.Registry.register(Hug.Capability.Shell)
    Hug.Capability.Registry.register(Hug.Capability.MemorySearch)
    Hug.Capability.Registry.register(Hug.Capability.SelfModify)
  end
end
