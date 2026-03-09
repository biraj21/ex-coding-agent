defmodule ExCode.Context do
  alias ExCode.TermUI

  @type t :: %__MODULE__{messages: :queue.queue(any())}

  defstruct messages: :queue.new()

  @spec new() :: t()
  def new() do
    %__MODULE__{}
  end

  @spec add(t(), any()) :: t()
  def add(%__MODULE__{messages: q} = ctx, msg) do
    %{ctx | messages: :queue.in(msg, q)}
  end

  @spec add_many(t(), [any()]) :: t()
  def add_many(%__MODULE__{messages: q} = ctx, messages) when is_list(messages) do
    new_q =
      Enum.reduce(messages, q, fn msg, acc ->
        :queue.in(msg, acc)
      end)

    %{ctx | messages: new_q}
  end

  @spec to_list(t()) :: [any()]
  def to_list(%__MODULE__{messages: q}) do
    :queue.to_list(q)
  end

  @spec print(t()) :: :ok
  def print(%__MODULE__{} = ctx) do
    IO.puts("\n#{TermUI.cyan("===== Context (messages) =====")}\n")

    ctx
    |> to_list()
    |> Enum.each(fn msg ->
      IO.puts(TermUI.yellow("--------"))
      IO.inspect(msg, pretty: true, limit: :infinity)
      IO.puts("")
    end)
  end
end
