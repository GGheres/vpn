# Bot config: sets Telegram bot token from ENV for all environments.
import Config
config :ex_gram, token: System.get_env("TELEGRAM_BOT_TOKEN")
