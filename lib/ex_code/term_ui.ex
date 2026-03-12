defmodule ExCode.TermUI do
  @reset "\e[0m"

  @black "\e[38;2;85;85;85m"
  @red "\e[38;2;255;85;85m"
  @green "\e[38;2;80;250;123m"
  @yellow "\e[38;2;241;250;140m"
  @blue "\e[38;2;139;233;253m"
  @magenta "\e[38;2;255;121;198m"
  @cyan "\e[38;2;139;233;253m"
  @white "\e[38;2;255;255;255m"
  @light_orange "\e[38;2;255;168;106m"

  @bold "\e[1m"
  @underline "\e[4m"

  def black(text), do: wrap(@black, text)

  def red(text), do: wrap(@red, text)

  def green(text), do: wrap(@green, text)

  def yellow(text), do: wrap(@yellow, text)

  def blue(text), do: wrap(@blue, text)

  def magenta(text), do: wrap(@magenta, text)

  def cyan(text), do: wrap(@cyan, text)

  def white(text), do: wrap(@white, text)

  def light_orange(text), do: wrap(@light_orange, text)

  def bold(text), do: wrap(@bold, text)

  def underline(text), do: wrap(@underline, text)

  defp wrap(code, text) do
    code <> text <> @reset
  end

  def columns() do
    case :io.columns() do
      {:ok, cols} -> cols
      _ -> 80
    end
  end
end
