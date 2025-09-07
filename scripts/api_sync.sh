#!/usr/bin/env bash
# Purpose: Sync Xray node config with the API by posting REALITY params.
set -euo pipefail

# Load .env if present
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
fi

NODE_ID="${NODE_ID:-${1:-1}}"
API_BASE="${API_BASE:-http://localhost:4000}"

XRAY_PRIVATE_KEY="${XRAY_PRIVATE_KEY:-}"
XRAY_PUBLIC_KEY="${XRAY_PUBLIC_KEY:-}"
XRAY_REALITY_SERVER_NAME="${XRAY_REALITY_SERVER_NAME:-www.cloudflare.com}"
XRAY_SHORT_ID="${XRAY_SHORT_ID:-0123456789abcdef}"
XRAY_DEST="${XRAY_DEST:-www.cloudflare.com:443}"
XRAY_LISTEN_PORT="${XRAY_LISTEN_PORT:-443}"

read -r -d '' JSON <<JSON
{
  "privateKey": "${XRAY_PRIVATE_KEY}",
  "publicKey": "${XRAY_PUBLIC_KEY}",
  "dest": "${XRAY_DEST}",
  "serverNames": ["${XRAY_REALITY_SERVER_NAME}"],
  "shortIds": ["${XRAY_SHORT_ID}"],
  "listen_port": ${XRAY_LISTEN_PORT}
}
JSON

echo "Syncing node ${NODE_ID} to ${API_BASE} ..."
curl -fsS -X POST "${API_BASE}/v1/nodes/${NODE_ID}/sync" \
  -H 'Content-Type: application/json' \
  -d "${JSON}"
echo
