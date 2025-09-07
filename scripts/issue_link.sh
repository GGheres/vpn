#!/usr/bin/env bash
set -euo pipefail

# Loads .env if present, then tries to issue vless link for a TG user.
# Usage:
#   scripts/issue_link.sh [TG_ID]
# Env overrides:
#   HOST, PORT, LABEL           # preferred simple names
#   VLESS_HOST, XRAY_LISTEN_PORT, LABEL  # legacy/compatible

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
fi

TG_ID="${1:-${TG_ID:-12345}}"
API_BASE="${API_BASE:-http://localhost:4000}"

# Parameterization
HOST="${HOST:-${VLESS_HOST:-localhost}}"
PORT="${PORT:-${XRAY_LISTEN_PORT:-443}}"
XRAY_PUBLIC_KEY="${XRAY_PUBLIC_KEY:-}"
XRAY_SHORT_ID="${XRAY_SHORT_ID:-}"
XRAY_REALITY_SERVER_NAME="${XRAY_REALITY_SERVER_NAME:-}"
LABEL="${LABEL:-vpn}"

payload() {
  cat <<JSON
{
  "tg_id": ${TG_ID},
  "host": "${HOST}",
  "port": ${PORT},
  "public_key": "${XRAY_PUBLIC_KEY}",
  "short_id": "${XRAY_SHORT_ID}",
  "server_name": "${XRAY_REALITY_SERVER_NAME}",
  "label": "${LABEL}"
}
JSON
}

extract_link() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$@" <<'PY'
import sys, json
try:
    print(json.load(sys.stdin)["vless"])  # noqa: T201
except Exception:
    sys.exit(1)
PY
  else
    # Fallback: naive grep/sed (may fail if JSON formatting changes)
    grep -o '"vless":"[^"]*' | sed -E 's/.*"vless":"(.*)/\1/'
  fi
}

echo "Issuing config for tg_id=${TG_ID} host=${HOST} port=${PORT} label=${LABEL} via ${API_BASE} ..." 1>&2
RESP=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/v1/issue" \
  -H 'Content-Type: application/json' \
  -d "$(payload)")

BODY=$(printf "%s" "${RESP}" | sed '$d')
CODE=$(printf "%s" "${RESP}" | tail -n1)

if [[ "${CODE}" == "200" ]]; then
  printf "%s" "${BODY}" | extract_link
  exit 0
fi

# If user not found, create and retry
if printf "%s" "${BODY}" | grep -q '"user_not_found"'; then
  echo "User not found. Creating tg_id=${TG_ID} ..." 1>&2
  curl -fsS -X POST "${API_BASE}/v1/users" \
    -H 'Content-Type: application/json' \
    -d "{\"tg_id\": ${TG_ID}, \"status\": \"active\"}" >/dev/null || true

  echo "Retrying issue ..." 1>&2
  RESP=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/v1/issue" \
    -H 'Content-Type: application/json' \
    -d "$(payload)")
  BODY=$(printf "%s" "${RESP}" | sed '$d')
  CODE=$(printf "%s" "${RESP}" | tail -n1)
  if [[ "${CODE}" == "200" ]]; then
    printf "%s" "${BODY}" | extract_link
    exit 0
  fi
fi

echo "Failed to issue link (HTTP ${CODE}): ${BODY}" 1>&2
exit 1
