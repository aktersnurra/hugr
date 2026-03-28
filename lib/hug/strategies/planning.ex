defmodule Hug.Strategies.Planning do
  @moduledoc """
  Default planning strategy. Passthrough — lets the LLM decompose tasks natively.
  This module can be rewritten by the agent at runtime.
  """

  @behaviour Hug.Strategy

  @impl true
  def apply(context) do
    {:ok, context}
  end
end
