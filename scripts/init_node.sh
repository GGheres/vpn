#!/usr/bin/env bash
# Purpose: Ensure a default node exists in the API using values from .env
set -euo pipefail

# Load .env if present, but do NOT override already-set env vars
_PRESET_API_BASE="${API_BASE:-}"
if [[ -f .env ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      val="${BASH_REMATCH[2]}"
      if [[ -z "${!key+x}" || -z "${!key}" ]]; then
        export "$key=$val"
      fi
    fi
  done < ./.env
fi

API_BASE="${API_BASE:-http://localhost:4000}"
if [[ "${USE_LOCALHOST:-}" == "1" && -z "${_PRESET_API_BASE}" ]]; then
  API_BASE="http://localhost:4000"
fi

REGION="${REGION:-default}"
NODE_IP="${NODE_IP:-${VLESS_HOST:-localhost}}"
XRAY_PRIVATE_KEY="${XRAY_PRIVATE_KEY:-}"
XRAY_PUBLIC_KEY="${XRAY_PUBLIC_KEY:-}"
XRAY_REALITY_SERVER_NAME="${XRAY_REALITY_SERVER_NAME:-www.cloudflare.com}"
XRAY_SHORT_ID="${XRAY_SHORT_ID:-0123456789abcdef}"
XRAY_DEST="${XRAY_DEST:-www.cloudflare.com:443}"
XRAY_LISTEN_PORT="${XRAY_LISTEN_PORT:-443}"

echo "Ensuring default node exists at ${API_BASE} ..." 1>&2
LIST=$(curl -fsS "${API_BASE}/v1/nodes")
if echo "${LIST}" | grep -q '\[\]'; then
  echo "Creating node ..." 1>&2
  curl -fsS -X POST "${API_BASE}/v1/nodes" \
    -H 'Content-Type: application/json' \
    -d "{\
      \"region\": \"${REGION}\",\
      \"ip\": \"${NODE_IP}\",\
      \"status\": \"active\",\
      \"version\": \"1\",\
      \"listen_port\": ${XRAY_LISTEN_PORT},\
      \"reality_dest\": \"${XRAY_DEST}\",\
      \"reality_public_key\": \"${XRAY_PUBLIC_KEY}\",\
      \"reality_server_names\": [\"${XRAY_REALITY_SERVER_NAME}\"],\
      \"reality_short_ids\": [\"${XRAY_SHORT_ID}\"]\
    }"
  echo
else
  echo "Node already exists, skipping creation." 1>&2
fi

exit 0

