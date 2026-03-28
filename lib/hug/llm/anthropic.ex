defmodule Hug.LLM.Anthropic do
  @moduledoc """
  Anthropic Messages API provider.
  """

  @behaviour Hug.LLM

  @api_url "https://api.anthropic.com/v1/messages"
  @api_version "2023-06-01"

  @impl true
  def complete(messages, system, opts \\ []) do
    model = Keyword.get(opts, :model, Application.get_env(:hug, :model))
    max_tokens = Keyword.get(opts, :max_tokens, Application.get_env(:hug, :max_tokens, 8192))

    tools = Keyword.get(opts, :tools, [])

    body =
      %{
        model: model,
        max_tokens: max_tokens,
        messages: messages
      }
      |> maybe_put_system(system)
      |> maybe_put_tools(tools)

    case Req.post(req(), json: body) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def stream(_messages, _system, _opts \\ [], _callback) do
    # TODO: Implement SSE streaming for Anthropic
    {:error, :not_implemented}
  end

  @impl true
  def parse_response(%{"content" => content}) do
    text =
      content
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map_join(& &1["text"])

    tool_uses =
      content
      |> Enum.filter(&(&1["type"] == "tool_use"))
      |> Enum.map(fn tu ->
        %{id: tu["id"], name: tu["name"], input: tu["input"]}
      end)

    {text, tool_uses}
  end

  def parse_response(_), do: {"", []}

  @impl true
  def format_tools(tools) do
    Enum.map(tools, fn tool ->
      %{
        name: tool.name,
        description: tool.description,
        input_schema: tool.parameters
      }
    end)
  end

  @impl true
  def format_tool_results(tool_uses, results) do
    content =
      Enum.zip(tool_uses, results)
      |> Enum.map(fn {tool_use, result} ->
        {content, is_error} =
          case result do
            {:ok, val} -> {to_string(val), false}
            {:error, reason} -> {"Error: #{inspect(reason)}", true}
          end

        %{
          "type" => "tool_result",
          "tool_use_id" => tool_use.id,
          "content" => content,
          "is_error" => is_error
        }
      end)

    [%{"role" => "user", "content" => content}]
  end

  @impl true
  def format_assistant_tool_message(%{"content" => content}) do
    %{"role" => "assistant", "content" => content}
  end

  def format_assistant_tool_message(_), do: %{"role" => "assistant", "content" => ""}

  defp req do
    api_key = Application.get_env(:hug, :anthropic_api_key)

    Req.new(
      url: @api_url,
      headers: [
        {"x-api-key", api_key},
        {"anthropic-version", @api_version},
        {"content-type", "application/json"}
      ]
    )
  end

  defp maybe_put_system(body, ""), do: body
  defp maybe_put_system(body, nil), do: body
  defp maybe_put_system(body, system), do: Map.put(body, :system, system)

  defp maybe_put_tools(body, []), do: body
  defp maybe_put_tools(body, tools), do: Map.put(body, :tools, format_tools(tools))
end
