#!/usr/bin/env bash
# Generate a QR code PNG from stdin or argument text.
# Usage examples:
#   echo "vless://..." | scripts/qr_from_text.sh -o qrs/vless.png
#   scripts/qr_from_text.sh -o qrs/vless.png "vless://..."
#   scripts/issue_link.sh 653848276 | scripts/qr_from_text.sh -o qrs/vless-653848276.png

set -euo pipefail

out="qr.png"
while getopts ":o:" opt; do
  case $opt in
    o) out="$OPTARG" ;;
    *) echo "Usage: $0 [-o output.png] [text]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND-1))

if [[ $# -gt 0 ]]; then
  data="$*"
else
  # If stdin is a TTY, nothing was piped
  if [[ -t 0 ]]; then
    echo "No input data. Pipe or pass the text to encode." >&2
    exit 1
  fi
  data="$(cat)"
fi

data="${data%%$'\n'}"  # trim trailing newline
if [[ -z "$data" ]]; then
  echo "No input data. Pipe or pass the text to encode." >&2
  exit 1
fi

mkdir -p "$(dirname "$out")"

# Use Python inside a container to avoid host deps
docker run --rm -i -v "$PWD":/work -w /work python:3-alpine \
  sh -lc "pip -q install qrcode[pil] >/dev/null 2>&1; python - <<'PY' \"$out\"
import sys
path = sys.argv[1]
data = sys.stdin.read()
try:
    import qrcode
except Exception:
    raise
img = qrcode.make(data)
img.save(path)
print(f'Wrote {path}')
PY
" <<EOF
${data}
EOF
