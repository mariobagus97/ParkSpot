#!/usr/bin/env bash
# Rebuilds the app icon from Scripts/icon.html.
#
# 1. Screenshot Scripts/icon.html at exactly 1024x1024 (the repo's icon was rendered with the
#    browser harness; any browser's device-emulation screenshot works) and save it as icon-raw.png.
# 2. Run: bash Scripts/make-icon.sh icon-raw.png
#
# The JPEG round trip is what strips the alpha channel an App Store icon must not have.
set -euo pipefail
raw=${1:-icon-raw.png}
out=ParkSpot/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
tmp=$(mktemp -d)
sips -s format jpeg -s formatOptions 100 "$raw" --out "$tmp/icon.jpg" >/dev/null
sips -s format png "$tmp/icon.jpg" --out "$out" >/dev/null
rm -rf "$tmp"
sips -g pixelWidth -g pixelHeight -g hasAlpha "$out"
