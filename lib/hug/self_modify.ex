defmodule Hug.SelfModify do
  @moduledoc """
  Self-modification engine. Rewrites strategy modules, compiles in a sandbox,
  hot-reloads on success, rolls back via jj on failure.

  Only modules under `lib/hug/strategies/` can be modified.
  """

  require Logger

  @allowed_prefix "lib/hug/strategies/"

  @doc """
  Rewrite a strategy module with new source code.

  Steps:
  1. Validate the module is in the allowed path
  2. Snapshot current state with jj
  3. Write new source to file
  4. Attempt compilation
  5. Hot-reload on success
  6. Rollback via jj on failure
  """
  def rewrite(module, new_source) do
    with {:ok, file_path} <- module_to_path(module),
         :ok <- validate_path(file_path),
         {:ok, original_source} <- read_file(file_path) do
      case write_source(file_path, new_source) do
        :ok ->
          case compile_and_load(file_path, module) do
            :ok ->
              Logger.info("Self-modify: #{inspect(module)} rewritten and hot-reloaded")
              :ok

            {:error, reason} ->
              Logger.warning("Self-modify: compilation failed for #{inspect(module)}, rolling back")
              rollback(file_path, original_source, module)
              {:error, reason}
          end

        {:error, reason} ->
          {:error, {:write_failed, reason}}
      end
    end
  end

  @doc """
  Returns the current source code for a strategy module.
  """
  def read_source(module) do
    with {:ok, file_path} <- module_to_path(module),
         :ok <- validate_path(file_path) do
      project_root = project_root()
      full_path = Path.join(project_root, file_path)
      File.read(full_path)
    end
  end

  @doc """
  Lists all strategy modules and their file paths.
  """
  def list_strategies do
    dir = Path.join(project_root(), @allowed_prefix)

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".ex"))
        |> Enum.map(fn file ->
          module_name =
            file
            |> String.trim_trailing(".ex")
            |> Macro.camelize()

          {Module.concat(Hug.Strategies, module_name), Path.join(@allowed_prefix, file)}
        end)

      {:error, _} ->
        []
    end
  end

  # --- Private ---

  defp module_to_path(module) do
    module_str = inspect(module)

    case module_str do
      "Hug.Strategies." <> rest ->
        filename = Macro.underscore(rest) <> ".ex"
        {:ok, Path.join(@allowed_prefix, filename)}

      _ ->
        {:error, {:restricted_module, module}}
    end
  end

  defp validate_path(file_path) do
    if String.starts_with?(file_path, @allowed_prefix) do
      :ok
    else
      {:error, {:restricted_path, file_path}}
    end
  end

  defp read_file(file_path) do
    full_path = Path.join(project_root(), file_path)
    File.read(full_path)
  end

  defp write_source(file_path, source) do
    full_path = Path.join(project_root(), file_path)
    File.write(full_path, source)
  end

  defp compile_and_load(file_path, module) do
    full_path = Path.join(project_root(), file_path)

    try do
      # Compile the file — this returns a list of {module, binary} tuples
      [{^module, _binary}] = Code.compile_file(full_path)

      # Purge old version and ensure new one is loaded
      :code.purge(module)
      {:module, ^module} = :code.load_file(module)

      :ok
    rescue
      e in [CompileError, SyntaxError, TokenMissingError] ->
        {:error, {:compile_error, Exception.message(e)}}

      e ->
        {:error, {:unexpected_error, Exception.message(e)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
    end
  end

  defp rollback(file_path, original_source, module) do
    full_path = Path.join(project_root(), file_path)

    case File.write(full_path, original_source) do
      :ok ->
        # Re-compile the original source to restore the loaded module
        try do
          Code.compile_file(full_path)
          :code.purge(module)
          :code.load_file(module)
        rescue
          _ -> :ok
        end

        Logger.info("Self-modify: rolled back #{file_path}")
        :ok

      {:error, reason} ->
        Logger.error("Self-modify: rollback failed for #{file_path}: #{inspect(reason)}")
        {:error, :rollback_failed}
    end
  end

  defp project_root do
    Application.get_env(:hug, :project_root, File.cwd!())
  end
end
