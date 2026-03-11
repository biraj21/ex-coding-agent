defmodule ExCode.Execute do
  @moduledoc """
  Handles interactions with the OpenAI/Cerebras API.
  """

  alias OpenaiEx.Chat
  alias OpenaiEx.ChatMessage

  alias ExCode.Env
  alias ExCode.Context
  alias ExCode.Tools
  alias ExCode.TermUI

  @spec execute(
          %OpenaiEx{},
          String.t(),
          ExCode.Context.t()
        ) :: {:error, struct()} | {:ok, ExCode.Context.t()}
  def execute(client, prompt, ctx) do
    user_msg = ChatMessage.user(prompt)

    ctx
    |> Context.add(user_msg)
    |> run_until_done(client)
  end

  defp run_until_done(ctx, client) do
    case run_completion(client, ctx) do
      {:done, ctx} -> {:ok, ctx}
      {:tools, ctx} -> run_until_done(ctx, client)
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_completion(client, ctx) do
    IO.puts("Running...")

    chat_req =
      Chat.Completions.new(
        model: Env.openai_model(),
        messages: Context.get(ctx),
        tools: Tools.tools(),
        parallel_tool_calls: true
      )

    case Chat.Completions.create(client, chat_req) do
      {:ok, resp} -> handle_response(resp, ctx)
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_response(resp, ctx) do
    %{
      "choices" => [
        %{
          "message" => message,
          "finish_reason" => finish_reason
        }
      ]
    } = resp

    usage = resp["usage"]

    reasoning = message["reasoning"] || message["reasoning_content"]
    content = message["content"]
    tool_calls = message["tool_calls"] || []

    if reasoning && reasoning != "" do
      "\nReasoning: #{reasoning}"
      |> TermUI.cyan()
      |> IO.puts()
    end

    if content && content != "" do
      "\n===== Response =====\n#{content}"
      |> TermUI.light_orange()
      |> IO.puts()
    end

    ctx = Context.add(ctx, message)

    IO.puts(TermUI.magenta("\nFinish Reason: #{TermUI.underline(finish_reason)}"))

    if tool_calls != [] do
      "Handling #{length(tool_calls)} tool calls..."
      |> TermUI.yellow()
      |> IO.puts()
    end

    tool_call_outputs =
      tool_calls
      |> execute_tool_calls()
      |> Enum.map(fn tool_result ->
        print_tool_result(tool_result)
        tool_result.tool_message
      end)

    ctx = Context.add_many(ctx, tool_call_outputs)

    if usage != nil do
      ("Usage: " <> Jason.encode!(usage, pretty: [indent: "  "]))
      |> TermUI.magenta()
      |> IO.puts()
    end

    IO.puts("---------------------------------------")

    if tool_call_outputs == [] do
      {:done, ctx}
    else
      {:tools, ctx}
    end
  end

  defp execute_tool_calls(tool_calls) do
    tool_calls
    |> Enum.map(&prepare_tool_call/1)
    |> Enum.chunk_by(&parallel_read?/1)
    |> Enum.flat_map(fn [tool_call | _] = chunk ->
      if parallel_read?(tool_call) do
        execute_parallel_read_batch(chunk)
      else
        Enum.map(chunk, &execute_tool_call/1)
      end
    end)
  end

  defp prepare_tool_call(tool_call) do
    %{
      "id" => id,
      "function" => %{
        "name" => name,
        "arguments" => args_json
      }
    } = tool_call

    args_pretty =
      args_json
      |> Jason.decode!()
      |> Jason.encode!(pretty: [indent: "  "])

    %{
      id: id,
      name: name,
      args_json: args_json,
      args_pretty: args_pretty
    }
  end

  defp parallel_read?(%{name: "read_file"}), do: true
  defp parallel_read?(_tool_call), do: false

  defp execute_parallel_read_batch(tool_calls) do
    max_concurrency = 16

    "\nRunning #{length(tool_calls)} tool calls (max #{max_concurrency} concurrent)"
    |> TermUI.cyan()
    |> IO.puts()

    Enum.each(tool_calls, fn %{name: name, args_pretty: args_pretty} ->
      "→ #{name} #{args_pretty}"
      |> TermUI.cyan()
      |> IO.puts()
    end)

    tool_results =
      Task.async_stream(tool_calls, &execute_tool_call/1,
        ordered: true,
        max_concurrency: max_concurrency,
        timeout: 15_000
      )

    Enum.zip(tool_calls, tool_results)
    |> Enum.map(fn {tool_call, result} ->
      case result do
        {:ok, tool_result} ->
          tool_result

        {:exit, reason} ->
          %{id: id, name: name, args_pretty: args_pretty} = tool_call
          output = "Error: task exited: #{inspect(reason)}"

          %{
            name: name,
            args_pretty: args_pretty,
            colored_output: TermUI.red("error: task exited: #{Exception.format_exit(reason)}"),
            tool_message: ChatMessage.tool(id, name, output)
          }
      end
    end)
  end

  defp execute_tool_call(%{
         id: id,
         name: name,
         args_json: args_json,
         args_pretty: args_pretty
       }) do
    result = Tools.handle_tool_call(name, args_json)

    {output, colored_output} =
      case result do
        {:ok, output} -> {output, TermUI.cyan(output)}
        {:error, reason} -> {"Error: #{reason}", TermUI.red("error: #{reason}")}
      end

    %{
      name: name,
      args_pretty: args_pretty,
      colored_output: colored_output,
      tool_message: ChatMessage.tool(id, name, output)
    }
  end

  defp print_tool_result(tool_result) do
    [
      "\n===== Tool Call =====",
      "Name: #{tool_result.name}",
      "Args: #{tool_result.args_pretty}",
      "Output:\n#{tool_result.colored_output}"
    ]
    |> Enum.join("\n")
    |> TermUI.cyan()
    |> IO.puts()
  end
end
