#!/usr/bin/env bash
#
# Wait until xcodebuild can use the watchOS simulator the Agent-watchOS tests run on.
#
# Why: xcode-27-arm64 GitHub runners can start a job while the watchOS simulator runtime
# is still being re-registered: `simctl runtime list` shows several copies of the same
# runtime image in "Deleting", "Copying" and "Ready" states. Until that settles, xcodebuild
# sees the watch devices with `runtime: (null)` and lists no watchOS destination, and
# fastlane falls back to an iPhone. Restarting CoreSimulatorService, rescanning the runtime
# disk images and re-running `xcodebuild -downloadPlatform watchOS` don't help; waiting does.
#
# Usage (from the repo root):
#   scripts/ensure_watchos_simulator.sh [timeout_seconds]   # default 900
#
set -u

# Keep in sync with the runWatchOSTests device in fastlane/TestFastfile.
SIM_NAME="Apple Watch SE 3 (40mm)"
WORKSPACE="Agent.xcworkspace"
SCHEME="Agent-watchOS"
TIMEOUT="${1:-900}"

# Prints "<build> <state>" for every watchOS runtime image that isn't Ready yet.
unsettled_watch_runtimes() {
  xcrun simctl runtime list -j | jq -r '
    [.[] | select(.platformIdentifier == "com.apple.platform.watchsimulator" and .state != "Ready")
         | "\(.build) \(.state)"] | join(", ")'
}

sim_visible() {
  local destinations
  destinations="$(xcodebuild -showdestinations -workspace "$WORKSPACE" -scheme "$SCHEME" 2>&1)"
  # Real simulators carry an arch; the placeholder destinations do not.
  grep -F "name:$SIM_NAME }" <<<"$destinations" | grep -q "platform:watchOS Simulator, arch:"
}

print_diagnostics() {
  echo "::group::Simulator state"
  xcodebuild -version
  xcrun simctl runtime list -v
  xcrun simctl runtime match list
  xcrun simctl list devices watchOS
  echo "::endgroup::"
}

start=$SECONDS
while true; do
  unsettled="$(unsettled_watch_runtimes)"
  visible=false
  sim_visible && visible=true

  if [ -z "$unsettled" ] && $visible; then
    echo "watchOS simulator runtime is ready after $((SECONDS - start))s."
    exit 0
  fi

  if (( SECONDS - start >= TIMEOUT )); then
    break
  fi

  echo "Waiting for the watchOS simulator runtime ($((SECONDS - start))s): images not ready: ${unsettled:-none}; xcodebuild sees $SIM_NAME: $visible"
  sleep 15
done

if $visible; then
  echo "::warning::watchOS runtime images still not settled after ${TIMEOUT}s (${unsettled}), but xcodebuild can see $SIM_NAME; continuing."
  exit 0
fi

echo "::error::xcodebuild still can't see the $SIM_NAME simulator after ${TIMEOUT}s."
print_diagnostics
exit 1
