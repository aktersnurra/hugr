import Config

config :hug,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  ollama_base_url: System.get_env("OLLAMA_BASE_URL", "http://localhost:11434")
