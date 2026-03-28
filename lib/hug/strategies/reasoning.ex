defmodule Hug.Strategies.Reasoning do
  @moduledoc """
  Default reasoning strategy. Passthrough — lets the LLM handle reasoning natively.
  This module can be rewritten by the agent at runtime.
  """

  @behaviour Hug.Strategy

  @impl true
  def apply(context) do
    {:ok, context}
  end
end
