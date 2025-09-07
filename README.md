
# VPN Starter — REALITY (VLESS + XTLS/Vision) + Elixir API + Telegram Bot + Docker

This is a runnable MVP starter for a VPN service with Xray (REALITY/VLESS/XTLS-Vision), an Elixir API
(Plug/Bandit; Phoenix-compatible structure), and a Telegram bot (ExGram). Target: Mac M4 (arm64).

## Quick start
```bash
cp .env.example .env
make up           # uses compose --profile dev
# API: http://localhost:4000/health
```

## Production (releases)

```bash
cp .env.example .env
make prod-up      # uses compose -f docker-compose.prod.yml --profile prod
# API: http://localhost:4000/health
```

API endpoints and nodes CRUD are listed in `docs/api.md`.

## Make targets

Convenience targets for local/dev:

```bash
# stack controls
make up            # compose up --build
make down          # compose down
make logs          # tails all logs

# xray helpers (read values from .env)
make xray-sync     # POST /v1/nodes/1/sync with REALITY params
make xray-reload   # docker kill -s USR1 xray

# health check
make health

# user/link helpers
make issue         # create user if needed and print vless link
make gen-keys      # generate x25519 private/public keys
```

To change node id or API base when syncing:

```bash
NODE_ID=2 API_BASE=http://localhost:4000 make xray-sync
```

## Hot reload from API

The API can trigger `xray` hot reload via `docker kill -s USR1 xray`.
This repo mounts the Docker socket into the API container and includes `docker-cli` so POST `/v1/nodes/:id/reload` works when running via docker compose.

## Optional: HTTPS for API via Caddy

An example `caddy/Caddyfile` and overlay compose file are provided. They proxy `api.example.com` to `api:4000`.

Run alongside the prod stack (uses 8080/8443 on host by default to avoid clashing with xray:443):

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.caddy.yml up -d --build caddy
# HTTPS on https://localhost:8443 (replace with your domain and DNS)
```

Adjust the site block in `caddy/Caddyfile` to your domain.
