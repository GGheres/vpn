#!/usr/bin/env bash
set -euo pipefail

echo "Sending USR1 to xray (hot reload)..."
docker kill -s USR1 xray
echo "OK"

