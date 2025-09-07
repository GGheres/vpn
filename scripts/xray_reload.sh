#!/usr/bin/env bash
# Purpose: Hot-reload the xray container by sending USR1.
set -euo pipefail

echo "Sending USR1 to xray (hot reload)..."
docker kill -s USR1 xray
echo "OK"
