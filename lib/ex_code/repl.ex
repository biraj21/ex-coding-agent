defmodule ExCode.REPL do
  @moduledoc """
  Interactive REPL for ExCode.
  """

  alias OpenaiEx.ChatMessage
  alias ExCode.Context
  alias ExCode.SystemPrompt
  alias ExCode.TermUI
  alias ExCode.Env

  defstruct client: nil,
            ctx: nil

  @type t :: %__MODULE__{}

  @spec new() :: t()
  def new() do
    %__MODULE__{
      client:
        OpenaiEx.new(Env.openai_api_key())
        |> OpenaiEx.with_base_url(Env.openai_base_url())
        |> OpenaiEx.with_receive_timeout(45_000),
      ctx:
        Context.new()
        |> Context.add(ChatMessage.system(SystemPrompt.get()))
    }
  end

  def start(repl) do
    loop(repl)
  end

  defp print_exit_msg(), do: IO.puts(TermUI.green("Exiting..."))

  defp loop(repl) do
    case IO.gets("> ") do
      :eof ->
        print_exit_msg()
        :ok

      input ->
        case process_input(repl, input) do
          {:continue, repl} -> loop(repl)
          :stop -> :ok
        end
    end
  end

  defp process_input(repl, input) do
    input = String.trim(input)

    case input do
      "" ->
        {:continue, repl}

      cmd when cmd in ["/exit", "/quit"] ->
        print_exit_msg()
        :stop

      "/ctx" ->
        Context.print(repl.ctx)
        {:continue, repl}

      _ ->
        handle_query(repl, input)
    end
  end

  defp handle_query(repl, input) do
    case execute_with_retry(repl, input) do
      {:ok, updated_ctx} ->
        {:continue, %{repl | ctx: updated_ctx}}

      {:error, reason} ->
        IO.puts(TermUI.red("Error: #{inspect(reason)}"))
        {:continue, repl}
    end
  end

  defp execute_with_retry(repl, input, attempt \\ 0) do
    case ExCode.Execute.execute(repl.client, input, repl.ctx) do
      {:ok, updated_ctx} ->
        {:ok, updated_ctx}

      {:error, %OpenaiEx.Error{kind: :rate_limit} = err} when attempt < 2 ->
        delay_secs = backoff(attempt + 1)

        IO.puts(TermUI.red("Error: #{inspect(err)}"))
        IO.puts(TermUI.yellow("Rate limited. Retrying in #{delay_secs}s..."))

        Process.sleep(delay_secs * 1000)
        execute_with_retry(repl, input, attempt + 1)

      {:error, err} ->
        {:error, err}
    end
  end

  defp backoff(attempt), do: trunc(:math.pow(2, attempt))
end
