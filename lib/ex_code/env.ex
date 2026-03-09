defmodule ExCode.Env do
  @spec openai_api_key() :: String.t()
  def openai_api_key, do: Application.fetch_env!(:ex_code, :openai_api_key)

  @spec openai_base_url() :: String.t()
  def openai_base_url, do: Application.fetch_env!(:ex_code, :openai_base_url)

  @spec openai_model() :: String.t()
  def openai_model, do: Application.fetch_env!(:ex_code, :openai_model)
end
