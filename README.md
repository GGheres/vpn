
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

### Bot issuing links with TTL

The Telegram bot now issues time‑limited links by default and triggers Xray sync + hot reload automatically:

- `/config` or `/trial` — trial link valid for 24h
- `/week` — paid link valid for 7 days
- `/month` — paid link valid for 30 days

The API stores credential expiry and `xray` sync includes only non‑expired credentials. To prune expired clients regularly, schedule periodic sync, e.g. via cron:

```
*/15 * * * * cd /opt/vpn && USE_LOCALHOST=1 NODE_ID=1 bash scripts/api_sync.sh >/dev/null 2>&1
```

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

Parameterize `issue` with environment variables (HOST/PORT/LABEL), for example:

```bash
HOST=vpn.example.com PORT=443 LABEL=myvpn TG_ID=555 make issue
# Legacy vars also work: VLESS_HOST=... XRAY_LISTEN_PORT=... LABEL=...
```

Key generation can auto-write into `.env`:

```bash
WRITE_ENV=1 make gen-keys     # or: scripts/generate_x25519.sh --write
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

Default overlay maps to host 8080/8443 (avoids collision with Xray:443):

```bash
docker compose -f docker-compose.prod.yml -f docker-compose.caddy.yml up -d --build caddy
# HTTPS on https://localhost:8443 (replace with your domain and DNS)
```

Adjust the site block in `caddy/Caddyfile` to your domain.

### Caddy on :443 with separate IPs

If your host has two public IPs, bind Xray to one and Caddy to the other:

```bash
# Set IPs in environment or .env
export XRAY_BIND_IP=203.0.113.10     # IP for Xray (REALITY)
export CADDY_BIND_IP=203.0.113.20    # IP for API (HTTPS)

docker compose \
  -f docker-compose.prod.yml \
  -f docker-compose.caddy.yml \
  -f docker-compose.caddy443.yml \
  --profile prod up -d --build caddy xray
```

This overlay remaps ports so both services can use 443 on different host IPs.

### Single IP :443 with SNI split (HAProxy)

When only one public IP is available, use HAProxy to split TLS by SNI:

```bash
# Edit haproxy/haproxy.cfg and set your API domain (default: api.example.com)

docker compose \
  -f docker-compose.prod.yml \
  -f docker-compose.caddy.yml \
  -f docker-compose.haproxy.yml \
  --profile prod up -d --build haproxy caddy xray
```

In this setup HAProxy listens on 443/80 and forwards TLS by SNI: requests for
`api.example.com` go to Caddy (API), everything else to Xray. Caddy still
obtains certificates (TLS-ALPN-01 or HTTP-01 via port 80 passthrough).
