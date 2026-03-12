defmodule ExCode.Tools do
  alias ExCode.TermUI

  @tools [
    %{
      "type" => "function",
      "function" => %{
        "name" => "read_file",
        "string" => true,
        "description" =>
          "Read and return the contents of a file. Each returned line is prefixed with '<line_number>:<content_hash> | '. These prefixes are metadata added by the tool and are NOT part of the actual file contents.",
        "parameters" => %{
          "type" => "object",
          "required" => ["file_path"],
          "properties" => %{
            "file_path" => %{
              "type" => "string",
              "description" => "The path to the file to read"
            }
          }
        }
      }
    },
    %{
      "type" => "function",
      "function" => %{
        "name" => "write_file",
        "string" => true,
        "description" => "Write content to a file",
        "parameters" => %{
          "type" => "object",
          "required" => ["file_path", "content"],
          "properties" => %{
            "file_path" => %{
              "type" => "string",
              "description" => "The path to the file to read"
            },
            "content" => %{
              "type" => "string",
              "description" => "The content to write to the file"
            }
          }
        }
      }
    },
    %{
      "type" => "function",
      "function" => %{
        "name" => "run_bash_command",
        "string" => true,
        "description" => "Execute a shell command.",
        "parameters" => %{
          "type" => "object",
          "required" => ["command"],
          "properties" => %{
            "command" => %{
              "type" => "string",
              "description" => "The command to execute"
            }
          }
        }
      }
    },
    %{
      "type" => "function",
      "function" => %{
        "name" => "edit_file",
        "string" => true,
        "description" =>
          "Edit a range of lines in a file. Use the hashes to verify the correct lines.",
        "parameters" => %{
          "type" => "object",
          "required" => [
            "file_path",
            "start_line",
            "end_line",
            "start_hash",
            "end_hash",
            "new_content"
          ],
          "properties" => %{
            "file_path" => %{"type" => "string"},
            "start_line" => %{"type" => "integer"},
            "end_line" => %{"type" => "integer"},
            "start_hash" => %{"type" => "string"},
            "end_hash" => %{"type" => "string"},
            "new_content" => %{
              "type" => "string",
              "description" => "Replacement content for the specified line range"
            }
          }
        }
      }
    }
  ]

  def tools(), do: @tools

  def handle_tool_call(name, args_json) do
    try do
      args = Jason.decode!(args_json)

      case name do
        "read_file" -> read_file(args)
        "write_file" -> write_file(args)
        "run_bash_command" -> run_bash_command(args)
        "edit_file" -> edit_file(args)
        _ -> {:error, "unknown tool: #{name}"}
      end
    rescue
      error ->
        {:error, "tool call failed: #{Exception.message(error)}"}
    end
  end

  defp read_file(%{"file_path" => file_path}) do
    case File.read(file_path) do
      {:ok, content} ->
        lines =
          content
          |> String.split("\n")
          |> Enum.with_index(1)
          |> Enum.map(fn {line, i} ->
            "#{i}:#{line_hash(line)} | #{line}"
          end)
          |> Enum.join("\n")

        {:ok, lines}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp line_hash(line) do
    :crypto.hash(:sha256, line)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 2)
  end

  defp write_file(%{
         "file_path" => file_path,
         "content" => content
       }) do
    case File.write(file_path, content) do
      :ok ->
        {:ok, "Successfully wrote to #{file_path}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def run_bash_command(%{"command" => command}) do
    if user_permission?("$ #{command}\nCan I run this command?") do
      shell =
        case System.find_executable("bash") do
          nil -> "sh"
          path -> path
        end

      {output, exit_code} = System.cmd(shell, ["-c", command], stderr_to_stdout: true)

      if exit_code == 0 do
        {:ok, output}
      else
        {:error, "exit code #{exit_code}\n#{output}"}
      end
    else
      {:error, "user denied the permission"}
    end
  end

  @spec user_permission?(String.t()) :: bool
  defp user_permission?(message) do
    case IO.gets(TermUI.yellow("#{message} [y/N] > ")) do
      :eof -> false
      answer -> String.trim(answer) |> String.downcase() == "y"
    end
  end

  defp edit_file(%{
         "file_path" => file_path,
         "start_line" => start_line,
         "end_line" => end_line,
         "start_hash" => start_hash,
         "end_hash" => end_hash,
         "new_content" => new_content
       }) do
    with {:ok, content} <- File.read(file_path) do
      lines = String.split(content, "\n")

      start_idx = start_line - 1
      end_idx = end_line - 1

      cond do
        start_idx > end_idx ->
          {:error, "invalid line range: start_line must be <= end_line"}

        start_idx < 0 or end_idx >= length(lines) ->
          {:error, "line range out of bounds"}

        line_hash(Enum.at(lines, start_idx)) != start_hash ->
          {:error, "start hash mismatch"}

        line_hash(Enum.at(lines, end_idx)) != end_hash ->
          {:error, "end hash mismatch"}

        true ->
          replacement = String.split(new_content, "\n")

          new_lines =
            lines
            |> Enum.take(start_idx)
            |> Kernel.++(replacement)
            |> Kernel.++(Enum.drop(lines, end_idx + 1))

          case File.write(file_path, Enum.join(new_lines, "\n")) do
            :ok -> {:ok, "Successfully edited #{file_path}"}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end
end
