# API config (compile-time defaults). Reads DB and app settings from ENV with
# graceful fallbacks, and configures console JSON logging.
import Config

# helpers for robust env parsing (handle nil/empty)
env_int = fn var, default ->
  case System.get_env(var) do
    nil -> default
    "" -> default
    v -> String.to_integer(v)
  end
end

env = fn var, default ->
  case System.get_env(var) do
    nil -> default
    "" -> default
    v -> v
  end
end

config :logger, :console, format: "$message\n"

config :vpn_api, ecto_repos: [VpnApi.Repo]

config :vpn_api, VpnApi.Repo,
  database: env.("POSTGRES_DB", "vpn"),
  username: env.("POSTGRES_USER", "vpn"),
  password: env.("POSTGRES_PASSWORD", "vpn"),
  hostname: env.("POSTGRES_HOST", "db"),
  port: env_int.("POSTGRES_PORT", 5432),
  pool_size: 10

config :vpn_api,
  app_port: env_int.("APP_PORT", 4000),
  app_host: env.("APP_HOST", "0.0.0.0"),
  app_secret: env.("APP_SECRET", "please_change_me")
