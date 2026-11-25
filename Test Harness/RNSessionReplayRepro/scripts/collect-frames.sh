#!/usr/bin/env bash
# Copies the agent's on-disk session replay frames out of the simulator app
# container while the app runs. The agent rewrites frame_N.json after every
# harvest, so each file is stored under a hash of its contents.
#   scripts/collect-frames.sh <simulator-udid> <out-dir>
set -uo pipefail
UDID="$1"; OUT="$2"; BUNDLE_ID="${BUNDLE_ID:-org.reactjs.native.example.RNSessionReplayRepro}"
mkdir -p "$OUT"
while true; do
  # Re-resolved every pass: reinstalling the app moves its data container.
  FRAMES="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data 2>/dev/null)/Documents/SessionReplayFrames"
  if [ -d "$FRAMES" ]; then
    find "$FRAMES" -name 'frame_*.json' -type f 2>/dev/null | while read -r f; do
      h="$(shasum "$f" | cut -c1-16)"
      [ -f "$OUT/$h.json" ] || cp "$f" "$OUT/$h.json" 2>/dev/null || true
    done
  fi
  sleep 0.5
done
