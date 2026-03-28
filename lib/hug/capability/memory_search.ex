defmodule Hug.Capability.MemorySearch do
  @moduledoc """
  Search the agent's memory using ripgrep.
  """

  @behaviour Hug.Capability

  @impl true
  def name, do: "memory_search"

  @impl true
  def description, do: "Search the agent's memory files for a query string. Returns matching lines with context."

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{
        query: %{
          type: "string",
          description: "The search query (supports regex)"
        }
      },
      required: ["query"]
    }
  end

  @impl true
  def execute(%{"query" => query}) do
    Hug.Memory.search(query)
  end
end
