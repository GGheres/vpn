#!/usr/bin/env bash
# Purpose: Sync Xray node config with the API by posting REALITY params.
set -euo pipefail

# Load .env if present, but do NOT override already-set env vars
# Remember if API_BASE was preset by the caller (to not override it later)
# capture initial API_BASE if set (for information only)
_PRESET_API_BASE="${API_BASE:-}"
if [[ -f .env ]]; then
  while IFS= read -r line; do
    # skip comments/empty
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # only KEY=VALUE pairs
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      # export only if unset or empty
      if [[ -z "${!key+x}" || -z "${!key}" ]]; then
        export "$key=$val"
      fi
    fi
  done < ./.env
fi

NODE_ID="${NODE_ID:-${1:-1}}"
API_BASE="${API_BASE:-http://localhost:4000}"

# Force localhost base when USE_LOCALHOST=1 (host-side scripts)
if [[ "${USE_LOCALHOST:-}" == "1" ]]; then
  API_BASE="http://localhost:4000"
fi

XRAY_PRIVATE_KEY="${XRAY_PRIVATE_KEY:-}"
XRAY_PUBLIC_KEY="${XRAY_PUBLIC_KEY:-}"
XRAY_REALITY_SERVER_NAME="${XRAY_REALITY_SERVER_NAME:-www.cloudflare.com}"
XRAY_SHORT_ID="${XRAY_SHORT_ID:-0123456789abcdef}"
XRAY_DEST="${XRAY_DEST:-www.cloudflare.com:443}"
XRAY_LISTEN_PORT="${XRAY_LISTEN_PORT:-443}"
XRAY_LOG_LEVEL="${XRAY_LOG_LEVEL:-error}"
XRAY_ENABLE_STATS="${XRAY_ENABLE_STATS:-0}"

JSON=$(cat <<JSON
{
  "privateKey": "${XRAY_PRIVATE_KEY}",
  "publicKey": "${XRAY_PUBLIC_KEY}",
  "dest": "${XRAY_DEST}",
  "serverNames": ["${XRAY_REALITY_SERVER_NAME}"],
  "shortIds": ["${XRAY_SHORT_ID}"],
  "listen_port": ${XRAY_LISTEN_PORT},
  "loglevel": "${XRAY_LOG_LEVEL}",
  "enable_stats": ${XRAY_ENABLE_STATS}
}
JSON
)

echo "Syncing node ${NODE_ID} to ${API_BASE} ..."
curl -fsS -X POST "${API_BASE}/v1/nodes/${NODE_ID}/sync" \
  -H 'Content-Type: application/json' \
  -d "${JSON}"
echo
