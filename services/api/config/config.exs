
import Config

config :logger, :console, format: "$message
"

config :vpn_api, VpnApi.Repo,
  database: System.get_env("POSTGRES_DB", "vpn"),
  username: System.get_env("POSTGRES_USER", "vpn"),
  password: System.get_env("POSTGRES_PASSWORD", "vpn"),
  hostname: System.get_env("POSTGRES_HOST", "db"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  pool_size: 10

config :vpn_api,
  app_port: String.to_integer(System.get_env("APP_PORT", "4000")),
  app_host: System.get_env("APP_HOST", "0.0.0.0"),
  app_secret: System.get_env("APP_SECRET", "please_change_me")
