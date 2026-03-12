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
          Context.t()
        ) :: {:ok, Context.t()} | {:error, any(), Context.t()}
  def execute(client, ctx) do
    run_until_done(ctx, client)
  end

  defp run_until_done(ctx, client) do
    case run_completion(client, ctx) do
      {:done, ctx} -> {:ok, ctx}
      {:tools, ctx} -> run_until_done(ctx, client)
      {:error, reason} -> {:error, reason, ctx}
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
      |> Enum.map(fn execution ->
        print_tool_result(execution)

        %{call: call, result: result} = execution

        output_content =
          case result do
            {:ok, output} -> output
            {:error, reason} -> "Error: #{reason}"
          end

        ChatMessage.tool(call.id, call.name, output_content)
      end)

    ctx = Context.add_many(ctx, tool_call_outputs)

    if usage != nil do
      ("Usage: " <> Jason.encode!(usage, pretty: [indent: "  "]))
      |> TermUI.magenta()
      |> IO.puts()
    end

    print_divider()

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
        {:ok, execution} ->
          execution

        {:exit, reason} ->
          %{
            call: tool_call,
            result: {:error, "task exited: #{inspect(reason)}"}
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

    %{
      call: %{
        id: id,
        name: name,
        args_json: args_json,
        args_pretty: args_pretty
      },
      result: result
    }
  end

  defp print_tool_result(%{call: call, result: result}) do
    {output, color_func} =
      case result do
        {:ok, output} ->
          if call.name == "read_file" do
            {"Result: File read successfully", &TermUI.green/1}
          else
            {"Result: #{output}", &TermUI.green/1}
          end

        {:error, reason} ->
          {"Error: #{reason}", &TermUI.red/1}
      end

    [
      "\n===== Tool #{call.name} =====",
      "Args: #{call.args_pretty}",
      output
    ]
    |> Enum.join("\n")
    |> color_func.()
    |> IO.puts()
  end

  defp print_divider() do
    String.duplicate("-", TermUI.columns())
    |> IO.puts()
  end
end
