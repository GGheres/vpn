#!/usr/bin/env bash
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

