defmodule Hug.REPL do
  @moduledoc """
  Simple blocking REPL with streaming output. Call `Hug.REPL.start()` from iex.
  """

  def start do
    IO.puts("Hug REPL — Ctrl-C to exit\n")
    loop()
  end

  defp loop do
    case IO.gets("hug> ") do
      :eof ->
        IO.puts("\nGoodbye.")

      {:error, _reason} ->
        IO.puts("\nGoodbye.")

      input ->
        input = String.trim(input)

        if input != "" do
          IO.write("\n")

          callback = fn
            {:thinking_delta, text} ->
              unless Process.get(:hug_repl_in_thinking, false) do
                Process.put(:hug_repl_in_thinking, true)
                IO.write(IO.ANSI.faint() <> "thinking: ")
              end

              IO.write(text)

            {:text_delta, text} ->
              if Process.get(:hug_repl_in_thinking, false) do
                Process.put(:hug_repl_in_thinking, false)
                IO.write(IO.ANSI.reset() <> "\n\n")
              end

              IO.write(text)

            :done ->
              if Process.get(:hug_repl_in_thinking, false) do
                Process.put(:hug_repl_in_thinking, false)
                IO.write(IO.ANSI.reset())
              end

              IO.write("\n\n")

            {:tool_status, :executing, tool_uses} ->
              if Process.get(:hug_repl_in_thinking, false) do
                Process.put(:hug_repl_in_thinking, false)
                IO.write(IO.ANSI.reset() <> "\n")
              end

              names = Enum.map_join(tool_uses, ", ", & &1.name)
              IO.write(IO.ANSI.cyan() <> "[calling: #{names}]" <> IO.ANSI.reset() <> "\n\n")

            _ ->
              :ok
          end

          case Hug.Agent.stream_chat(input, callback) do
            {:ok, _text} ->
              :ok

            {:error, reason} ->
              IO.puts("[error] #{inspect(reason)}\n")
          end
        end

        loop()
    end
  end
end
