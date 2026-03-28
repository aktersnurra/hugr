defmodule Hug.Capability do
  @moduledoc """
  Behaviour for agent capabilities (tools).

  Each capability is an Elixir module that describes itself and can execute actions.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback parameters() :: map()
  @callback execute(args :: map()) :: {:ok, term()} | {:error, term()}

  @doc """
  Returns the tool schema for a capability module, formatted for LLM APIs.
  """
  def tool_schema(module) do
    %{
      name: module.name(),
      description: module.description(),
      parameters: module.parameters()
    }
  end
end
