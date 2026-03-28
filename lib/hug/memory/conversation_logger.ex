defmodule Hug.Memory.ConversationLogger do
  @moduledoc """
  GenServer that logs conversation messages as JSONL files.
  Messages are cast (fire-and-forget) so the Agent is never blocked.
  """

  use GenServer

  require Logger

  defstruct [:file, :path]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def log_message(message) do
    GenServer.cast(__MODULE__, {:log, message})
  end

  def current_path do
    GenServer.call(__MODULE__, :current_path)
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    dir = Hug.Memory.conversations_dir()
    File.mkdir_p!(dir)

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic) |> String.replace(~r/[^\w]/, "_")
    path = Path.join(dir, "#{timestamp}.jsonl")
    {:ok, file} = File.open(path, [:append, :raw])

    {:ok, %__MODULE__{file: file, path: path}}
  end

  @impl true
  def handle_cast({:log, message}, state) do
    line = Jason.encode!(Map.put(message, "timestamp", DateTime.utc_now() |> DateTime.to_iso8601()))
    IO.binwrite(state.file, line <> "\n")
    {:noreply, state}
  end

  @impl true
  def handle_call(:current_path, _from, state) do
    {:reply, state.path, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.file, do: File.close(state.file)
  end
end
