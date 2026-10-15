#!/usr/bin/env bash
#
# Wait until xcodebuild can use the watchOS simulator the Agent-watchOS tests run on.
#
# Why: on xcode-27-arm64 GitHub runners the watchOS 27.0 simulator runtime image keeps
# being re-staged after the job starts (`simctl runtime list` cycles the same 24R362 image
# through Unusable/Copying/Deleting/Ready). While that happens xcodebuild sees the watch
# devices with `runtime: (null)` and fastlane falls back to an iPhone. Once the image
# settles it can come back Ready but unregistered, with every watch device gone.
#
# So this polls xcodebuild and returns as soon as it can see the simulator. While it
# can't: if the runtime is registered but the device is missing, it creates the device;
# if the images have settled but the runtime isn't registered, it restarts
# CoreSimulatorService so it picks the runtime up.
#
# Usage (from the repo root):
#   scripts/ensure_watchos_simulator.sh [timeout_seconds]   # default 900
#
set -u

# Keep in sync with the runWatchOSTests device in fastlane/TestFastfile.
SIM_NAME="Apple Watch SE 3 (40mm)"
SIM_TYPE="com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-3-40mm"
# The runtime Xcode 27.0's watchsimulator27.0 SDK runs on.
RUNTIME_ID="com.apple.CoreSimulator.SimRuntime.watchOS-27-0"
WORKSPACE="Agent.xcworkspace"
SCHEME="Agent-watchOS"
TIMEOUT="${1:-900}"
RESTART_INTERVAL=120

sim_visible() {
  local destinations
  destinations="$(xcodebuild -showdestinations -workspace "$WORKSPACE" -scheme "$SCHEME" 2>&1)"
  # Real simulators carry an arch; the placeholder destinations do not.
  grep -F "name:$SIM_NAME }" <<<"$destinations" | grep -q "platform:watchOS Simulator, arch:"
}

# "<build> <state>" for every watchOS runtime disk image, comma separated.
watch_images() {
  xcrun simctl runtime list -j | jq -r '
    [.[] | select(.platformIdentifier == "com.apple.platform.watchsimulator") | "\(.build) \(.state)"]
    | join(", ")'
}

images_settled() {
  xcrun simctl runtime list -j | jq -e '
    [.[] | select(.platformIdentifier == "com.apple.platform.watchsimulator")]
    | length > 0 and all(.state == "Ready")' >/dev/null
}

runtime_registered() {
  xcrun simctl list -j runtimes available \
    | jq -e --arg rt "$RUNTIME_ID" 'any(.runtimes[]; .identifier == $rt)' >/dev/null
}

device_exists() {
  xcrun simctl list -j devices available \
    | jq -e --arg rt "$RUNTIME_ID" --arg name "$SIM_NAME" \
        '(.devices[$rt] // []) | any(.name == $name)' >/dev/null
}

restart_simulator_service() {
  xcrun simctl shutdown all >/dev/null 2>&1
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1
  # Any simctl call relaunches the service, which rediscovers the installed runtimes.
  xcrun simctl list runtimes >/dev/null 2>&1
}

print_diagnostics() {
  echo "::group::Simulator state"
  xcode-select -p
  xcodebuild -version
  xcrun simctl runtime list -v
  xcrun simctl runtime match list
  xcrun simctl list runtimes
  xcrun simctl list devices
  echo "::endgroup::"
}

start=$SECONDS
last_restart=$((SECONDS - RESTART_INTERVAL))
while true; do
  elapsed=$((SECONDS - start))
  if sim_visible; then
    echo "xcodebuild can see the $SIM_NAME simulator after ${elapsed}s."
    xcrun simctl list devices watchOS
    exit 0
  fi

  if (( elapsed >= TIMEOUT )); then
    break
  fi

  images="$(watch_images)"
  registered=false
  runtime_registered && registered=true
  echo "Waiting for the watchOS simulator (${elapsed}s): images: ${images:-none}; $RUNTIME_ID registered: $registered"

  if $registered && ! device_exists; then
    echo "Creating the $SIM_NAME simulator on $RUNTIME_ID"
    xcrun simctl create "$SIM_NAME" "$SIM_TYPE" "$RUNTIME_ID" && continue
  fi

  # Images settled (all Ready) but xcodebuild still can't use the simulator.
  if images_settled && (( SECONDS - last_restart >= RESTART_INTERVAL )); then
    echo "watchOS runtime images are settled; restarting CoreSimulatorService"
    restart_simulator_service
    last_restart=$SECONDS
    continue
  fi

  sleep 15
done

echo "::error::xcodebuild still can't see the $SIM_NAME simulator after ${TIMEOUT}s."
print_diagnostics
exit 1
