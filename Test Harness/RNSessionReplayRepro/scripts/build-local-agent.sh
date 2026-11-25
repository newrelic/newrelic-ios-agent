#!/usr/bin/env bash
# Builds the iOS agent from this repo for the simulator and wraps it in an
# xcframework the local NewRelicAgent podspec vends, so the repro app runs the
# working-tree agent instead of the published binary.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$APP_DIR/../.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-/tmp/nr-agent-dd}"
OUT="$APP_DIR/ios/LocalNewRelicAgent/NewRelic.xcframework"

xcodebuild -project "$REPO_ROOT/Agent.xcodeproj" -scheme Agent-iOS -configuration Debug \
  -sdk iphonesimulator -derivedDataPath "$DERIVED_DATA" \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES build -quiet

rm -rf "$OUT"
xcodebuild -create-xcframework \
  -framework "$DERIVED_DATA/Build/Products/Debug-iphonesimulator/NewRelic.framework" \
  -output "$OUT"
# CocoaPods' "[CP] Copy XCFrameworks" phase keeps its copy if it looks up to date, which
# would leave the app running the previous agent. Drop the copies so the next app build
# takes this one. APP_DERIVED_DATA adds an app derived data path to clear.
for dd in "$HOME/Library/Developer/Xcode/DerivedData" /tmp/DerivedData-ios ${APP_DERIVED_DATA:-}; do
  find "$dd" -type d -path '*XCFrameworkIntermediates/NewRelicAgent' -prune -exec rm -rf {} + 2>/dev/null || true
done
echo "Built $OUT"
