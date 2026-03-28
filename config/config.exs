import Config

config :hug,
  provider: Hug.LLM.Ollama,
  model: "qwen3.5:latest",
  max_tokens: 8192

import_config "#{config_env()}.exs"
