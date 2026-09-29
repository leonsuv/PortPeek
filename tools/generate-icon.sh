#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d /tmp/PortPeek-Icon.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
swift tools/make-icon.swift PortPeek "$WORK/AppIcon.iconset"
iconutil -c icns "$WORK/AppIcon.iconset" -o assets/AppIcon.icns
