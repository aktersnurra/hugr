defmodule Hug.Memory.Summarizer do
  @moduledoc """
  Summarizes conversations via the LLM and writes summaries to disk.
  """

  require Logger

  @summary_prompt """
  Summarize the following conversation concisely. Focus on:
  - What was discussed and decided
  - Key facts learned
  - Actions taken (tool calls and their results)
  - Any unresolved questions

  Use bullet points. Be specific — include names, paths, and values mentioned.
  """

  def summarize(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider, Application.get_env(:hug, :provider))
    model = Keyword.get(opts, :model, Application.get_env(:hug, :model))

    conversation_text =
      messages
      |> Enum.map(fn msg ->
        role = msg["role"] || to_string(msg[:role])
        content = msg["content"] || msg[:content]
        content_str = if is_binary(content), do: content, else: inspect(content)
        "#{role}: #{content_str}"
      end)
      |> Enum.join("\n\n")

    summary_messages = [
      %{"role" => "user", "content" => "#{@summary_prompt}\n\n---\n\n#{conversation_text}"}
    ]

    case provider.complete(summary_messages, "", model: model) do
      {:ok, response} ->
        {text, _} = provider.parse_response(response)
        {:ok, text}

      {:error, _} = error ->
        error
    end
  end

  def summarize_and_save(messages, opts \\ []) do
    case summarize(messages, opts) do
      {:ok, summary} ->
        dir = Hug.Memory.summaries_dir()
        File.mkdir_p!(dir)

        timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^\w]/, "_")
        path = Path.join(dir, "#{timestamp}.md")
        File.write!(path, summary)

        Logger.info("Conversation summary saved to #{path}")
        {:ok, summary, path}

      {:error, _} = error ->
        error
    end
  end
end
