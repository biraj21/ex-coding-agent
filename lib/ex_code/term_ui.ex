defmodule ExCode.TermUI do
  @reset "\e[0m"

  @black "\e[30m"
  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @magenta "\e[35m"
  @cyan "\e[36m"
  @white "\e[37m"
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
end
