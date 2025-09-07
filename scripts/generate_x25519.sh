#!/usr/bin/env bash
# Purpose: Generate an X25519 keypair using the teddysun/xray container.
set -euo pipefail

echo "Generating x25519 keypair using teddysun/xray image..." 1>&2
OUT=$(docker run --rm teddysun/xray xray x25519)
echo "" 1>&2
echo "${OUT}" 1>&2

PRIV=$(printf "%s" "${OUT}" | awk '/Private key:/ {print $3}')
PUB=$(printf "%s" "${OUT}" | awk '/Public key:/ {print $3}')

if [[ -z "${PRIV}" || -z "${PUB}" ]]; then
  echo "Could not parse keys. Raw output above." 1>&2
  exit 1
fi

cat <<ENV
# Copy the lines below into your .env
XRAY_PRIVATE_KEY=${PRIV}
XRAY_PUBLIC_KEY=${PUB}
ENV

# Optional: automatically write into .env when WRITE_ENV=1 or --write flag is set
if [[ "${1:-}" == "--write" || "${WRITE_ENV:-}" == "1" ]]; then
  if [[ ! -f .env ]]; then
    echo ".env not found; creating new .env" 1>&2
    touch .env
  fi

  TS=$(date +%Y%m%d-%H%M%S)
  cp .env ".env.bak.${TS}"

  # Portable in-place update: write to temp then move
  tmpfile=$(mktemp .env.tmp.XXXX)
  # Remove existing XRAY_PRIVATE_KEY / XRAY_PUBLIC_KEY lines
  grep -vE '^(XRAY_PRIVATE_KEY|XRAY_PUBLIC_KEY)=' .env >"${tmpfile}" || true
  {
    echo "XRAY_PRIVATE_KEY=${PRIV}"
    echo "XRAY_PUBLIC_KEY=${PUB}"
  } >>"${tmpfile}"
  mv "${tmpfile}" .env
  echo "Updated .env (backup: .env.bak.${TS})" 1>&2
fi
