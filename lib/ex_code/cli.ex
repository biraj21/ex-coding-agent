defmodule ExCode.Cli do
  alias ExCode.Env
  alias ExCode.REPL
  alias ExCode.TermUI

  def start(_args) do
    draw_banner(30)

    IO.puts(TermUI.blue("\nBase URL: #{TermUI.underline(Env.openai_base_url())}"))
    IO.puts(TermUI.blue("Model: #{TermUI.underline(Env.openai_model())}\n"))

    REPL.new() |> REPL.start()
  end

  defp draw_banner(width) do
    title = "ExCode"
    # subtract border chars
    inner = width - 2

    padded =
      String.pad_leading(title, div(inner + String.length(title), 2))
      |> String.pad_trailing(inner)

    top = "┌" <> String.duplicate("─", inner) <> "┐"
    middle = "│" <> padded <> "│"
    bottom = "└" <> String.duplicate("─", inner) <> "┘"

    IO.puts(TermUI.blue(top))
    IO.puts(TermUI.blue(middle))
    IO.puts(TermUI.blue(bottom))
  end
end
