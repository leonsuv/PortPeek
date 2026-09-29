#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
for theme in dark light; do
  "dist/PortPeek.app/Contents/MacOS/PortPeek" --demo "--$theme" "--snapshot=assets/screenshot-$theme.png"
done
