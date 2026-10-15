#!/usr/bin/env bash
#
# Make sure xcodebuild can see the watchOS simulator the Agent-watchOS tests run on.
#
# Why: some xcode-27-arm64 GitHub runners come up with the watchOS simulator runtime
# visible to `simctl` but not to xcodebuild: its watch devices log
# "SimDevice native architecture is nil ... runtime={ ...watchOS-27-0: (null) }" and
# -showdestinations lists only the "Any watchOS Simulator Device" placeholder. Checking
# with simctl is not enough, so this asks xcodebuild directly and, while the simulator
# is missing, tries progressively heavier repairs: restart CoreSimulatorService, rescan
# the runtime disk images, then download the watchOS platform for the selected Xcode.
#
# Usage (from the repo root):
#   scripts/ensure_watchos_simulator.sh
#
set -u

# Keep in sync with the runWatchOSTests destination in fastlane/TestFastfile.
SIM_NAME="Apple Watch SE 3 (40mm)"
WORKSPACE="Agent.xcworkspace"
SCHEME="Agent-watchOS"

sim_visible() {
  local destinations
  destinations="$(xcodebuild -showdestinations -workspace "$WORKSPACE" -scheme "$SCHEME" 2>&1)"
  # Real simulators carry an arch; the placeholder destinations do not.
  grep -F "name:$SIM_NAME }" <<<"$destinations" | grep -q "platform:watchOS Simulator, arch:"
}

restart_simulator_service() {
  xcrun simctl shutdown all >/dev/null 2>&1
  killall -9 com.apple.CoreSimulator.CoreSimulatorService >/dev/null 2>&1
  # Any simctl call relaunches the service, which rediscovers the installed runtimes.
  xcrun simctl list runtimes >/dev/null 2>&1
}

print_diagnostics() {
  echo "::group::Simulator state"
  xcodebuild -version
  xcrun simctl runtime list -v
  xcrun simctl runtime match list
  xcrun simctl list runtimes
  xcrun simctl list devices watchOS
  echo "::endgroup::"
}

if sim_visible; then
  echo "xcodebuild can see the $SIM_NAME simulator."
  exit 0
fi

echo "::warning::xcodebuild can't see the $SIM_NAME simulator; repairing the runner's simulator setup."
print_diagnostics

echo "Restarting CoreSimulatorService"
restart_simulator_service
sim_visible && { echo "Fixed by restarting CoreSimulatorService."; exit 0; }

echo "Rescanning simulator runtime disk images"
xcrun simctl runtime scan-and-mount
restart_simulator_service
sim_visible && { echo "Fixed by rescanning runtime disk images."; exit 0; }

echo "Downloading the watchOS platform"
xcodebuild -downloadPlatform watchOS
restart_simulator_service
sim_visible && { echo "Fixed by downloading the watchOS platform."; exit 0; }

echo "::error::xcodebuild still can't see the $SIM_NAME simulator after all repairs."
print_diagnostics
exit 1
