defmodule Hug.Strategies.ToolSelection do
  @moduledoc """
  Default tool selection strategy. Passthrough — lets the LLM select tools natively.
  This module can be rewritten by the agent at runtime.
  """

  @behaviour Hug.Strategy

  @impl true
  def apply(context) do
    {:ok, context}
  end
end
