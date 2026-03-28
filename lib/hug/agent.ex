defmodule Hug.Agent do
  @moduledoc """
  Main agent GenServer. Holds conversation state and dispatches to the configured LLM provider.
  Implements an agentic loop: dispatches tool calls until the LLM stops requesting tools.
  """

  use GenServer

  require Logger

  defstruct [:provider, :model, :max_tokens, :system, messages: []]

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def chat(pid \\ __MODULE__, content) do
    GenServer.call(pid, {:chat, content}, :infinity)
  end

  def stream_chat(pid \\ __MODULE__, content, callback) do
    GenServer.call(pid, {:stream_chat, content, callback}, :infinity)
  end

  # --- Callbacks ---

  @impl true
  def init(opts) do
    system =
      case Keyword.get(opts, :system) do
        nil -> Hug.Memory.load_core_facts()
        s -> s
      end

    state = %__MODULE__{
      provider: Keyword.get(opts, :provider, Application.get_env(:hug, :provider)),
      model: Keyword.get(opts, :model, Application.get_env(:hug, :model)),
      max_tokens: Keyword.get(opts, :max_tokens, Application.get_env(:hug, :max_tokens, 8192)),
      system: system
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:chat, content}, _from, state) do
    message = %{"role" => "user", "content" => content}
    log(message)
    messages = state.messages ++ [message]

    case agentic_loop(messages, state) do
      {:ok, text, messages} ->
        log(%{"role" => "assistant", "content" => text})
        {:reply, {:ok, text}, %{state | messages: messages}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:stream_chat, content, callback}, _from, state) do
    message = %{"role" => "user", "content" => content}
    log(message)
    messages = state.messages ++ [message]

    case stream_agentic_loop(messages, state, callback) do
      {:ok, text, messages} ->
        log(%{"role" => "assistant", "content" => text})
        {:reply, {:ok, text}, %{state | messages: messages}}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  defp log(message) do
    Hug.Memory.ConversationLogger.log_message(message)
  end

  defp apply_strategies(context) do
    context
    |> apply_strategy(Hug.Strategies.Reasoning)
    |> apply_strategy(Hug.Strategies.Planning)
    |> apply_strategy(Hug.Strategies.ToolSelection)
  end

  defp apply_strategy(context, module) do
    case module.apply(context) do
      {:ok, new_context} -> new_context
      {:error, reason} ->
        Logger.warning("Strategy #{inspect(module)} failed: #{inspect(reason)}, using fallback")
        context
    end
  rescue
    e ->
      Logger.warning("Strategy #{inspect(module)} crashed: #{Exception.message(e)}, using fallback")
      context
  end

  # --- Agentic loop (non-streaming, used for tool calling) ---

  defp agentic_loop(messages, state) do
    tools = Hug.Capability.Registry.tools_schema()
    opts = [model: state.model, max_tokens: state.max_tokens, tools: tools]

    case state.provider.complete(messages, state.system, opts) do
      {:ok, response} ->
        {text, tool_uses} = state.provider.parse_response(response)

        if tool_uses == [] do
          assistant_message = %{"role" => "assistant", "content" => text}
          {:ok, text, messages ++ [assistant_message]}
        else
          Logger.info("Tool calls: #{Enum.map_join(tool_uses, ", ", & &1.name)}")

          results = Enum.map(tool_uses, &Hug.ToolDispatcher.dispatch/1)

          assistant_msg = state.provider.format_assistant_tool_message(response)
          tool_result_msgs = state.provider.format_tool_results(tool_uses, results)

          messages = messages ++ [assistant_msg | tool_result_msgs]
          agentic_loop(messages, state)
        end

      {:error, _reason} = error ->
        error
    end
  end

  # --- Streaming agentic loop ---
  # Streams the first call. If tools are returned, falls back to non-streaming
  # loop for tool dispatch, then streams the final response.

  defp stream_agentic_loop(messages, state, callback) do
    tools = Hug.Capability.Registry.tools_schema()
    opts = [model: state.model, max_tokens: state.max_tokens, tools: tools]

    case state.provider.stream(messages, state.system, opts, callback) do
      {:ok, text} ->
        assistant_message = %{"role" => "assistant", "content" => text}
        {:ok, text, messages ++ [assistant_message]}

      {:tool_calls, text, tool_uses} ->
        Logger.info("Tool calls: #{Enum.map_join(tool_uses, ", ", & &1.name)}")
        callback.({:tool_status, :executing, tool_uses})

        results = Enum.map(tool_uses, &Hug.ToolDispatcher.dispatch/1)

        # Build messages: assistant message with tool_calls, then tool results
        assistant_msg = %{"role" => "assistant", "content" => text || "", "tool_calls" =>
          Enum.map(tool_uses, fn tu ->
            %{"id" => tu.id, "function" => %{"name" => tu.name, "arguments" => tu.input}}
          end)
        }
        tool_result_msgs = state.provider.format_tool_results(tool_uses, results)
        messages = messages ++ [assistant_msg | tool_result_msgs]

        # Continue streaming for the next response
        stream_agentic_loop(messages, state, callback)

      {:error, _reason} = error ->
        error
    end
  end
end
