defmodule Hug.Memory do
  @moduledoc """
  Facade for the file-based memory system.
  """

  @memory_dir "memory"

  def memory_dir do
    Path.join(Application.get_env(:hug, :project_root, File.cwd!()), @memory_dir)
  end

  def load_core_facts do
    path = Path.join(memory_dir(), "core_facts.md")

    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> ""
    end
  end

  def search(query) do
    dir = memory_dir()

    case System.cmd("rg", ["-i", "-C", "2", "--no-heading", "--no-ignore", query, dir], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {_, 1} -> {:ok, "No results found for: #{query}"}
      {output, _} -> {:error, output}
    end
  end

  def conversations_dir, do: Path.join(memory_dir(), "conversations")
  def summaries_dir, do: Path.join(memory_dir(), "summaries")
end
