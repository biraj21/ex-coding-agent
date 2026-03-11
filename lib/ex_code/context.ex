defmodule ExCode.Context do
  alias ExCode.TermUI

  @type t :: %__MODULE__{}

  defstruct messages: []

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @spec add(t(), map()) :: t()
  def add(ctx, new_msg) do
    %{ctx | messages: [new_msg | ctx.messages]}
  end

  @spec add_many(t(), [map()]) :: t()
  def add_many(ctx, new_msgs) do
    %{ctx | messages: Enum.reverse(new_msgs) ++ ctx.messages}
  end

  @spec get(t()) :: [map()]
  def get(ctx) do
    Enum.reverse(ctx.messages)
  end

  @spec print(t()) :: :ok
  def print(ctx) do
    IO.puts("\n#{TermUI.cyan("===== Context (messages) =====")}\n")

    get(ctx)
    |> Enum.each(fn msg ->
      pretty = Jason.encode!(msg, pretty: [indent: "  "])

      colored =
        case msg[:role] || msg["role"] do
          "system" -> TermUI.yellow(pretty)
          "assistant" -> TermUI.light_orange(pretty)
          "tool" -> TermUI.cyan(pretty)
          _ -> pretty
        end

      IO.puts(colored)
    end)
  end
end
