defmodule Hug.LLM do
  @moduledoc """
  Behaviour defining the contract for LLM providers.
  """

  @type message :: %{role: String.t(), content: any()}
  @type tool_use :: %{id: String.t(), name: String.t(), input: map()}
  @type stream_event ::
          {:text_delta, String.t()}
          | {:thinking_delta, String.t()}
          | {:tool_use, tool_use()}
          | :done

  @callback complete(messages :: [message()], system :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback stream(
              messages :: [message()],
              system :: String.t(),
              opts :: keyword(),
              callback :: (stream_event() -> any())
            ) :: {:ok, String.t()} | {:tool_calls, String.t(), [tool_use()]} | {:error, term()}

  @callback parse_response(response :: map()) :: {String.t(), [tool_use()]}

  @callback format_tools(tools :: [map()]) :: any()
  @callback format_tool_results(tool_uses :: [tool_use()], results :: [term()]) :: message()
  @callback format_assistant_tool_message(response :: map()) :: message()
end
