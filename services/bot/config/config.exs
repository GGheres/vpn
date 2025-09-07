# Bot config: sets Telegram bot token from ENV for all environments.
import Config
config :ex_gram, token: System.get_env("TELEGRAM_BOT_TOKEN")
config :ex_gram, bots: [
  vpn_bot: [token: System.get_env("TELEGRAM_BOT_TOKEN")]
]

# Use Mint (pure Elixir) as Tesla HTTP adapter to avoid hackney dependency
config :tesla, adapter: Tesla.Adapter.Mint
