defmodule Hug.Capability.Registry do
  @moduledoc """
  Registry of available capabilities. Holds a map of name -> module.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def register(module) do
    Agent.update(__MODULE__, fn caps ->
      Map.put(caps, module.name(), module)
    end)
  end

  def lookup(name) do
    case Agent.get(__MODULE__, &Map.get(&1, name)) do
      nil -> {:error, :not_found}
      module -> {:ok, module}
    end
  end

  def list do
    Agent.get(__MODULE__, &Map.keys/1)
  end

  def all do
    Agent.get(__MODULE__, & &1)
  end

  def tools_schema do
    Agent.get(__MODULE__, fn caps ->
      caps
      |> Map.values()
      |> Enum.map(&Hug.Capability.tool_schema/1)
    end)
  end
end
