defmodule Hug.LLM.Message do
  @moduledoc """
  Internal message representation.

  Provider modules handle serialization to their own wire format.
  """

  @type role :: :user | :assistant | :system
  @type t :: %__MODULE__{role: role(), content: String.t()}

  defstruct [:role, :content]

  def user(content), do: %__MODULE__{role: :user, content: content}
  def assistant(content), do: %__MODULE__{role: :assistant, content: content}

  def to_map(%__MODULE__{role: role, content: content}) do
    %{"role" => to_string(role), "content" => content}
  end
end
