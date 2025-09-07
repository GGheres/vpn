## Runtime config for bot (evaluated at boot time).
## Pulls TOKEN from ENV; suitable for containerized deploys.
import Config

# Глобальный токен по умолчанию
config :ex_gram, token: System.get_env("TELEGRAM_BOT_TOKEN")

# Явная привязка токена к бот-имени :vpn_bot (на случай мульти-ботов)
config :ex_gram, bots: [
  vpn_bot: [token: System.get_env("TELEGRAM_BOT_TOKEN")]
]
