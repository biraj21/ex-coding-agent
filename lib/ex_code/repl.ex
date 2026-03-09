defmodule ExCode.REPL do
  @moduledoc """
  Interactive REPL for ExCode.
  """

  alias OpenaiEx.ChatMessage
  alias ExCode.Context
  alias ExCode.SystemPrompt
  alias ExCode.TermUI

  def start(client) do
    ctx =
      Context.new()
      |> Context.add(ChatMessage.system(SystemPrompt.get()))

    loop(client, ctx)
  end

  defp loop(client, ctx) do
    case IO.gets("> ") do
      :eof ->
        IO.puts(TermUI.green("Exiting..."))
        :ok

      prompt ->
        prompt = String.trim(prompt)

        case process_input(client, prompt, ctx) do
          {:continue, updated_ctx} -> loop(client, updated_ctx)
          :stop -> :ok
        end
    end
  end

  defp process_input(client, prompt, ctx) do
    case prompt do
      "" ->
        {:continue, ctx}

      "/exit" ->
        IO.puts(TermUI.green("Exiting..."))
        :stop

      "/quit" ->
        IO.puts(TermUI.green("Exiting..."))
        :stop

      "/ctx" ->
        Context.print(ctx)
        {:continue, ctx}

      _ ->
        handle_query(client, prompt, ctx)
    end
  end

  defp handle_query(client, prompt, ctx) do
    case ExCode.Execute.execute(client, prompt, ctx) do
      {:ok, updated_ctx, _usage} ->
        {:continue, updated_ctx}

      {:error, reason} ->
        IO.puts(TermUI.red("Error: #{inspect(reason)}"))
        {:continue, ctx}
    end
  end
end
