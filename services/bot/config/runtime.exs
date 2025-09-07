## Runtime config for bot (evaluated at boot time).
## Pulls TOKEN from ENV; suitable for containerized deploys.
import Config

config :ex_gram, token: System.get_env("TELEGRAM_BOT_TOKEN")
