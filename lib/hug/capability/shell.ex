defmodule Hug.Capability.Shell do
  @moduledoc """
  Shell command execution capability.
  """

  @behaviour Hug.Capability

  @impl true
  def name, do: "shell"

  @impl true
  def description, do: "Execute a shell command and return its output."

  @impl true
  def parameters do
    %{
      type: "object",
      properties: %{
        command: %{
          type: "string",
          description: "The shell command to execute"
        }
      },
      required: ["command"]
    }
  end

  @impl true
  def execute(%{"command" => command}) do
    case System.cmd("sh", ["-c", command], stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:ok, "exit code #{code}:\n#{output}"}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end
end
