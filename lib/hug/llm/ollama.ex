defmodule Hug.LLM.Ollama do
  @moduledoc """
  Ollama /api/chat provider with NDJSON streaming.
  """

  @behaviour Hug.LLM

  @impl true
  def complete(messages, system, opts \\ []) do
    model = Keyword.get(opts, :model, Application.get_env(:hug, :model))
    tools = Keyword.get(opts, :tools, [])
    base_url = Application.get_env(:hug, :ollama_base_url, "http://localhost:11434")
    messages = maybe_prepend_system(messages, system)

    body =
      %{model: model, messages: messages, stream: false}
      |> maybe_put_tools(tools)

    case Req.post(req(base_url), json: body) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def stream(messages, system, opts \\ [], callback) do
    model = Keyword.get(opts, :model, Application.get_env(:hug, :model))
    tools = Keyword.get(opts, :tools, [])
    base_url = Application.get_env(:hug, :ollama_base_url, "http://localhost:11434")
    messages = maybe_prepend_system(messages, system)

    body =
      %{model: model, messages: messages, stream: true}
      |> maybe_put_tools(tools)

    acc = %{text: "", buffer: "", tool_calls: []}

    into_fun = fn {:data, data}, {req, resp} ->
      acc_ref = Process.get(:hug_stream_acc, acc)
      new_acc = process_chunks(acc_ref.buffer <> data, callback, acc_ref)
      Process.put(:hug_stream_acc, new_acc)
      {:cont, {req, resp}}
    end

    Process.put(:hug_stream_acc, acc)

    case Req.post(req(base_url), json: body, into: into_fun) do
      {:ok, %Req.Response{status: 200}} ->
        final = Process.delete(:hug_stream_acc) || acc

        if final.tool_calls != [] do
          tool_uses =
            Enum.map(final.tool_calls, fn tc ->
              %{
                id: tc["id"] || generate_id(),
                name: get_in(tc, ["function", "name"]),
                input: get_in(tc, ["function", "arguments"]) || %{}
              }
            end)

          {:tool_calls, final.text, tool_uses}
        else
          callback.(:done)
          {:ok, final.text}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Process.delete(:hug_stream_acc)
        {:error, {status, body}}

      {:error, reason} ->
        Process.delete(:hug_stream_acc)
        {:error, reason}
    end
  end

  @impl true
  def parse_response(%{"message" => %{"content" => content, "tool_calls" => tool_calls}})
      when is_list(tool_calls) and tool_calls != [] do
    tool_uses =
      Enum.map(tool_calls, fn tc ->
        %{
          id: tc["id"] || generate_id(),
          name: get_in(tc, ["function", "name"]),
          input: get_in(tc, ["function", "arguments"]) || %{}
        }
      end)

    {content || "", tool_uses}
  end

  def parse_response(%{"message" => %{"content" => content}}) do
    {content || "", []}
  end

  def parse_response(_), do: {"", []}

  @impl true
  def format_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        type: "function",
        function: %{
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      }
    end)
  end

  @impl true
  def format_tool_results(tool_uses, results) do
    Enum.zip(tool_uses, results)
    |> Enum.map(fn {_tool_use, result} ->
      content =
        case result do
          {:ok, val} -> to_string(val)
          {:error, reason} -> "Error: #{inspect(reason)}"
        end

      %{"role" => "tool", "content" => content}
    end)
  end

  @impl true
  def format_assistant_tool_message(%{"message" => message}) do
    %{"role" => "assistant", "content" => message["content"] || "", "tool_calls" => message["tool_calls"]}
  end

  def format_assistant_tool_message(_), do: %{"role" => "assistant", "content" => ""}

  # --- NDJSON chunk processing ---

  defp process_chunks(data, callback, acc) do
    case String.split(data, "\n", parts: 2) do
      [line, rest] ->
        acc = process_line(String.trim(line), callback, acc)
        process_chunks(rest, callback, acc)

      [incomplete] ->
        %{acc | buffer: incomplete}
    end
  end

  defp process_line("", _callback, acc), do: acc

  defp process_line(line, callback, acc) do
    case Jason.decode(line) do
      {:ok, %{"message" => message}} ->
        acc = emit_deltas(message, callback, acc)
        acc

      _ ->
        acc
    end
  end

  defp emit_deltas(message, callback, acc) do
    acc =
      case message do
        %{"thinking" => thinking} when thinking != "" and thinking != nil ->
          callback.({:thinking_delta, thinking})
          acc

        _ ->
          acc
      end

    acc =
      case message do
        %{"tool_calls" => tool_calls} when is_list(tool_calls) and tool_calls != [] ->
          %{acc | tool_calls: acc.tool_calls ++ tool_calls}

        _ ->
          acc
      end

    case message do
      %{"content" => content} when content != "" and content != nil ->
        callback.({:text_delta, content})
        %{acc | text: acc.text <> content}

      _ ->
        acc
    end
  end

  # --- Helpers ---

  defp req(base_url) do
    Req.new(
      url: "#{base_url}/api/chat",
      headers: [{"content-type", "application/json"}],
      receive_timeout: 300_000
    )
  end

  defp maybe_prepend_system(messages, ""), do: messages
  defp maybe_prepend_system(messages, nil), do: messages

  defp maybe_prepend_system(messages, system) do
    [%{"role" => "system", "content" => system} | messages]
  end

  defp maybe_put_tools(body, []), do: body
  defp maybe_put_tools(body, tools), do: Map.put(body, :tools, format_tools(tools))

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower)
  end
end
