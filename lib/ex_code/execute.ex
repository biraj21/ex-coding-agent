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

  def execute(client, prompt, ctx) do
    user_msg = ChatMessage.user(prompt)

    case run_completion(client, Context.add(ctx, user_msg)) do
      {:done, ctx} -> {:ok, ctx}
      {:tools, ctx} -> run_completion(client, ctx)
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_completion(client, ctx) do
    IO.puts("Running...")

    chat_req =
      Chat.Completions.new(
        model: Env.openai_model(),
        messages: Context.get(ctx),
        tools: Tools.tools()
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
    tool_calls = message["tool_calls"]

    if reasoning && reasoning != "" do
      IO.puts(TermUI.cyan("\nReasoning: #{reasoning}"))
    end

    if content != "" do
      IO.puts("\n#{TermUI.light_orange("===== Response =====")}")
      IO.puts(TermUI.light_orange(content))
    end

    ctx = Context.add(ctx, message)

    IO.puts(TermUI.magenta("\nFinish Reason: #{TermUI.underline(finish_reason)}"))

    tool_call_outputs =
      Enum.map(tool_calls, fn tool_call ->
        %{
          "id" => id,
          "function" => %{
            "name" => name,
            "arguments" => args_json
          }
        } = tool_call

        IO.puts("\n#{TermUI.cyan("===== Tool Call =====")}")
        IO.puts(TermUI.cyan("Name: #{TermUI.underline(name)}"))

        pretty =
          args_json
          |> Jason.decode!()
          |> Jason.encode!(pretty: [indent: "  "])

        IO.puts(TermUI.cyan("Args: #{pretty}\n"))
        result = Tools.handle_tool_call(name, args_json)

        {output, colored_output} =
          case result do
            {:ok, output} -> {output, TermUI.cyan(output)}
            {:error, reason} -> {"Error: #{reason}", TermUI.red("error: #{reason}")}
          end

        IO.puts(TermUI.cyan("  === Tool Output ==="))
        IO.puts(colored_output)

        ChatMessage.tool(id, name, output)
      end)

    ctx = Context.add_many(ctx, tool_call_outputs)

    if usage != nil do
      usage_pretty = Jason.encode!(usage, pretty: [indent: "  "])
      IO.puts(TermUI.magenta("Usage: " <> usage_pretty))
    end

    IO.puts("---------------------------------------")

    if tool_call_outputs == [] do
      {:done, ctx}
    else
      {:tools, ctx}
    end
  end
end
