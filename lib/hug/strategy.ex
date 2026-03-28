defmodule Hug.Strategy do
  @moduledoc """
  Behaviour for agent strategies. Strategies are the mutable surface
  of the agent — they can be rewritten and hot-reloaded at runtime.
  """

  @callback apply(context :: map()) :: {:ok, term()} | {:error, term()}
end
