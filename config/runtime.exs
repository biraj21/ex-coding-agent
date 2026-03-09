import Config
import Dotenvy

# load .env file
source!([".env", System.get_env()])

config :ex_code,
  openai_base_url: env!("OPENAI_BASE_URL", :string!),
  openai_api_key: env!("OPENAI_API_KEY", :string!),
  openai_model: env!("OPENAI_MODEL", :string!)
