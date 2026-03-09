defmodule ExCode do
  @moduledoc """
  Documentation for `ExCode`.
  """

  alias ExCode.Cli

  def main(args) do
    Cli.start(args)
  end
end
