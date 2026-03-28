defmodule Hug.ToolDispatcher do
  @moduledoc """
  Dispatches tool calls to capabilities via the TaskSupervisor.
  """

  @default_timeout 30_000

  def dispatch(%{name: name, input: input}) do
    dispatch(%{name: name, input: input}, @default_timeout)
  end

  def dispatch(%{name: name, input: input}, timeout) do
    case Hug.Capability.Registry.lookup(name) do
      {:ok, module} ->
        task =
          Task.Supervisor.async_nolink(Hug.TaskSupervisor, fn ->
            module.execute(input)
          end)

        case Task.yield(task, timeout) || Task.shutdown(task) do
          {:ok, {:ok, result}} -> {:ok, result}
          {:ok, {:error, reason}} -> {:error, reason}
          {:exit, reason} -> {:error, {:crashed, reason}}
          nil -> {:error, :timeout}
        end

      {:error, :not_found} ->
        {:error, {:unknown_tool, name}}
    end
  end
end
