defmodule Hug.Capability.SelfModify do
  @moduledoc """
  Capability that allows the agent to rewrite its own strategy modules.
  """

  @behaviour Hug.Capability

  @impl true
  def name, do: "self_modify"

  @impl true
  def description do
    "Rewrite one of the agent's strategy modules (reasoning, planning, tool_selection). " <>
      "Use read_source action first to see current code, then rewrite action to modify it. " <>
      "Only modules under Hug.Strategies.* can be modified."
  end

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{
        action: %{
          type: "string",
          description: "Action to perform: 'read_source', 'rewrite', or 'list'",
          enum: ["read_source", "rewrite", "list"]
        },
        module: %{
          type: "string",
          description: "Module name, e.g. 'Hug.Strategies.Reasoning'"
        },
        source: %{
          type: "string",
          description: "New Elixir source code (only for rewrite action)"
        }
      },
      required: ["action"]
    }
  end

  @impl true
  def execute(%{"action" => "list"}) do
    strategies = Hug.SelfModify.list_strategies()

    result =
      Enum.map_join(strategies, "\n", fn {module, path} ->
        "#{inspect(module)} -> #{path}"
      end)

    {:ok, result}
  end

  def execute(%{"action" => "read_source", "module" => module_str}) do
    module = string_to_module(module_str)

    case Hug.SelfModify.read_source(module) do
      {:ok, source} -> {:ok, source}
      {:error, reason} -> {:error, reason}
    end
  end

  def execute(%{"action" => "rewrite", "module" => module_str, "source" => source}) do
    module = string_to_module(module_str)

    case Hug.SelfModify.rewrite(module, source) do
      :ok -> {:ok, "Successfully rewrote and hot-reloaded #{module_str}"}
      {:error, reason} -> {:error, "Rewrite failed: #{inspect(reason)}"}
    end
  end

  def execute(%{"action" => "rewrite"}) do
    {:error, "rewrite action requires both 'module' and 'source' parameters"}
  end

  def execute(%{"action" => "read_source"}) do
    {:error, "read_source action requires 'module' parameter"}
  end

  defp string_to_module(str) do
    str
    |> String.trim_leading("Elixir.")
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
    |> Module.concat()
  end
end
