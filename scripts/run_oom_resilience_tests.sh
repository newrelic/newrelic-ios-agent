#!/usr/bin/env bash
#
# Verify that the handled-exception path cannot kill the host app when the device
# is out of memory, and that it never writes a malformed report to disk.
#
# Two stages:
#   harness (fast)  Compiles the agent's Hex C++ into a standalone binary, replaces
#                   global operator new so 1-in-N allocations throw std::bad_alloc,
#                   and drives HexStore::store() in a tight loop. Then verifies every
#                   .fbad it wrote is a well-formed HexAgentData buffer. No simulator.
#   app             Builds NRTestApp, injects the same failure behaviour with
#                   DYLD_INSERT_LIBRARIES, and drives -[NewRelic recordError:] in a
#                   tight loop on a simulator. This is the end-to-end test: it
#                   exercises the real Objective-C crash boundary.
#
# Both stages must be built WITHOUT NDEBUG. FLATBUFFERS_ASSERT(!nested) is the
# detector for a swallowed mid-table exception, and release builds compile it out.
#
# See Tests/OOM-RESILIENCE.md for background and for what each failure means.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

SRC_DIR="Tests/OOM-Resilience"
WORKSPACE="Agent.xcworkspace"
SCHEME="NRTestApp"
BUNDLE_ID="com.newrelic.NRApp.bitcode"
OUT_DIR="build/oom-resilience"

FAIL_ONE_IN=1000
HARNESS_ITERATIONS=50000
APP_ITERATIONS=20000
INJECT_DELAY=12
START_DELAY=16
APP_TIMEOUT=600
SIMULATOR=""
STAGES="harness app"
NO_BUILD=0
EXPECT_CRASH=0

usage() {
  cat <<USAGE
usage: scripts/run_oom_resilience_tests.sh [options]

  --harness-only        Run only the fast native harness (no simulator).
  --app-only            Run only the on-simulator end-to-end test.
  --fail-one-in N       Fail 1 in N heap allocations. Default ${FAIL_ONE_IN}. Below ~100 the
                        app's own startup allocations start failing; that is a false
                        positive, not an agent bug.
  --iterations N        recordError calls in the app stage. Default ${APP_ITERATIONS}.
  --harness-iterations N  Calls in the harness stage. Default ${HARNESS_ITERATIONS}.
  --simulator <id>      Simulator name or UDID. Default: a booted iPhone, else the
                        newest available iPhone.
  --expect-crash        Invert the app stage: PASS only if the app DOES die. Use this
                        after reverting the fix, to confirm the test is not vacuous.
  --timeout N           Seconds to wait for the app stage verdict. Default ${APP_TIMEOUT}.
  --out <path>          Default: ${OUT_DIR}
  --no-build            Reuse an existing NRTestApp build.
  -h, --help            This message.

examples:
  scripts/run_oom_resilience_tests.sh
  scripts/run_oom_resilience_tests.sh --harness-only
  scripts/run_oom_resilience_tests.sh --app-only --fail-one-in 500
  scripts/run_oom_resilience_tests.sh --app-only --expect-crash    # against pre-fix code
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness-only)       STAGES="harness"; shift ;;
    --app-only)           STAGES="app"; shift ;;
    --fail-one-in)        FAIL_ONE_IN="$2"; shift 2 ;;
    --iterations)         APP_ITERATIONS="$2"; shift 2 ;;
    --harness-iterations) HARNESS_ITERATIONS="$2"; shift 2 ;;
    --simulator)          SIMULATOR="$2"; shift 2 ;;
    --expect-crash)       EXPECT_CRASH=1; shift ;;
    --timeout)            APP_TIMEOUT="$2"; shift 2 ;;
    --out)                OUT_DIR="$2"; shift 2 ;;
    --no-build)           NO_BUILD=1; shift ;;
    -h|--help)            usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo >&2; usage >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT_DIR"
HARNESS_RESULT="skipped"
VERIFY_RESULT="skipped"
APP_RESULT="skipped"

# ---- harness stage -----------------------------------------------------------------
run_harness() {
  local lib="libMobileAgent"
  local inc="$OUT_DIR/include"

  # The Hex sources include their headers as <Hex/Foo.hpp> but the tree nests them
  # under include/Hex/report/... . Xcode papers over this with a recursive header
  # search path; reproduce that here by flattening into one directory of symlinks.
  echo "==> preparing include tree"
  rm -rf "$inc"
  mkdir -p "$inc/Hex" "$inc/Utilities" "$inc/Analytics"
  local group
  for group in Hex Utilities Analytics; do
    find "$lib/src/$group/include" -type f \( -name '*.hpp' -o -name '*.h' \) \
      -exec ln -sf "$REPO_ROOT/{}" "$inc/$group/" \;
  done

  if [[ ! -d "$lib/ext/flatbuffers/include" ]]; then
    echo "error: $lib/ext/flatbuffers is empty. Run: git submodule update --init --recursive" >&2
    HARNESS_RESULT="ERROR (missing flatbuffers submodule)"
    return 1
  fi

  local sources=(
    "$lib/src/Hex/src/HexStore.cxx"
    "$lib/src/Hex/src/LibraryController.cxx"
    "$lib/src/Hex/src/report/HexReport.cxx"
    "$lib/src/Hex/src/report/AgentData.cxx"
    "$lib/src/Hex/src/report/AppInfo.cxx"
    "$lib/src/Hex/src/report/ApplicationLicense.cxx"
    "$lib/src/Hex/src/report/exception/HandledException.cxx"
    "$lib/src/Hex/src/report/exception/Library.cxx"
    "$lib/src/Hex/src/report/exception/Thread.cxx"
    "$lib/src/Hex/src/report/exception/Frame.cxx"
    "$lib/src/Utilities/src/libLogger.cxx"
    "$lib/src/Utilities/src/DefaultLogger.cxx"
    "$lib/src/Utilities/src/BaseValue.cxx"
    "$lib/src/Utilities/src/String.cxx"
    "$lib/src/Utilities/src/Boolean.cxx"
    "$lib/src/Utilities/src/Number.cxx"
    "$lib/src/Utilities/src/Value.cxx"
    "$lib/src/Utilities/src/Util.cxx"
    "$lib/src/Analytics/src/AttributeValidator.cxx"
    "$lib/src/Analytics/src/AttributeBase.cxx"
    "$lib/src/Analytics/src/Attribute.cxx"
  )
  local attrs=("$lib"/src/Hex/src/report/attributes/*.cxx)

  # -O0 and NO -DNDEBUG on purpose: FLATBUFFERS_ASSERT must stay live.
  local cxxflags=(-std=c++17 -g -O0 -fexceptions -fno-omit-frame-pointer
                  -I "$inc" -I "$inc/Hex" -I "$inc/Utilities" -I "$inc/Analytics"
                  -I "$lib/ext/flatbuffers/include")

  echo "==> compiling harness"
  if ! clang++ "${cxxflags[@]}" "$SRC_DIR/hex_oom_harness.cxx" \
       "${sources[@]}" "${attrs[@]}" -o "$OUT_DIR/hex_oom_harness" \
       > "$OUT_DIR/harness-build.log" 2>&1; then
    echo "error: harness failed to compile. See $OUT_DIR/harness-build.log" >&2
    grep -m5 "error:" "$OUT_DIR/harness-build.log" >&2
    HARNESS_RESULT="ERROR (compile)"
    return 1
  fi

  echo "==> compiling verify_reports"
  if ! clang++ -std=c++17 -O1 -I "$inc/Hex" -I "$lib/ext/flatbuffers/include" \
       "$SRC_DIR/verify_reports.cxx" -o "$OUT_DIR/verify_reports" \
       > "$OUT_DIR/verify-build.log" 2>&1; then
    echo "error: verify_reports failed to compile. See $OUT_DIR/verify-build.log" >&2
    grep -m5 "error:" "$OUT_DIR/verify-build.log" >&2
    VERIFY_RESULT="ERROR (compile)"
    return 1
  fi

  local store="$OUT_DIR/store"
  rm -rf "$store"; mkdir -p "$store"

  echo "==> running harness (1-in-${FAIL_ONE_IN}, ${HARNESS_ITERATIONS} calls)"
  "$OUT_DIR/hex_oom_harness" \
      --fail-one-in "$FAIL_ONE_IN" \
      --iterations "$HARNESS_ITERATIONS" \
      --store "$store" 2>&1 | tee "$OUT_DIR/harness.log"
  local rc=${PIPESTATUS[0]}
  case "$rc" in
    0)  HARNESS_RESULT="PASS" ;;
    70) HARNESS_RESULT="FAIL (uncaught C++ exception escaped the store path)" ;;
    71) HARNESS_RESULT="FAIL (assertion failure — builder left nested?)" ;;
    *)  HARNESS_RESULT="FAIL (exit $rc)" ;;
  esac

  echo
  echo "==> verifying stored reports"
  "$OUT_DIR/verify_reports" "$store" 2>&1 | tee "$OUT_DIR/verify.log"
  case "${PIPESTATUS[0]}" in
    0) VERIFY_RESULT="PASS" ;;
    3) VERIFY_RESULT="INCONCLUSIVE (no reports written)" ;;
    *) VERIFY_RESULT="FAIL (malformed report on disk)" ;;
  esac
}

# ---- app stage ---------------------------------------------------------------------
resolve_simulator() {
  # Prefer something already booted so repeat runs do not pay the boot cost.
  if [[ -z "$SIMULATOR" ]]; then
    SIMULATOR=$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
booted, avail = [], []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if not d.get("isAvailable"):
            continue
        if "iPhone" not in d.get("name", ""):
            continue
        (booted if d.get("state") == "Booted" else avail).append((runtime, d))
pick = sorted(booted, key=lambda i: i[0])[-1:] or sorted(avail, key=lambda i: i[0])[-1:]
if pick:
    print(pick[0][1]["udid"])
')
  fi
  if [[ -z "$SIMULATOR" ]]; then
    echo "error: no available iOS simulator found. Pass --simulator <name-or-udid>." >&2
    return 1
  fi
}

run_app() {
  resolve_simulator || { APP_RESULT="ERROR (no simulator)"; return 1; }

  local sdk; sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
  echo "==> building OOM injector dylib"
  if ! clang++ -std=c++17 -O1 -dynamiclib -fexceptions \
       -isysroot "$sdk" -target arm64-apple-ios17.0-simulator \
       "$SRC_DIR/oom_injector.cxx" -o "$OUT_DIR/liboominject.dylib" \
       > "$OUT_DIR/injector-build.log" 2>&1; then
    echo "error: injector failed to build. See $OUT_DIR/injector-build.log" >&2
    grep -m5 "error:" "$OUT_DIR/injector-build.log" >&2
    APP_RESULT="ERROR (injector compile)"
    return 1
  fi

  local dd="$OUT_DIR/DerivedData"
  if [[ "$NO_BUILD" -eq 0 ]]; then
    echo "==> building $SCHEME"
    if ! xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -sdk iphonesimulator \
         -destination "platform=iOS Simulator,id=${SIMULATOR}" -configuration Debug \
         -derivedDataPath "$dd" build > "$OUT_DIR/app-build.log" 2>&1; then
      echo "error: $SCHEME failed to build. See $OUT_DIR/app-build.log" >&2
      grep -m5 "error:" "$OUT_DIR/app-build.log" >&2
      APP_RESULT="ERROR (app build)"
      return 1
    fi
  fi

  local app="$dd/Build/Products/Debug-iphonesimulator/NRTestApp.app"
  if [[ ! -d "$app" ]]; then
    echo "error: built app not found at $app (try without --no-build)" >&2
    APP_RESULT="ERROR (app missing)"
    return 1
  fi

  echo "==> installing on $SIMULATOR"
  xcrun simctl bootstatus "$SIMULATOR" -b > /dev/null 2>&1
  xcrun simctl install "$SIMULATOR" "$app" || { APP_RESULT="ERROR (install)"; return 1; }
  xcrun simctl terminate "$SIMULATOR" "$BUNDLE_ID" > /dev/null 2>&1

  echo "==> running ${APP_ITERATIONS} recordError calls under 1-in-${FAIL_ONE_IN} allocation failure"
  echo "    (injector arms at T+${INJECT_DELAY}s, loop starts at T+${START_DELAY}s)"
  local log="$OUT_DIR/app.log"
  : > "$log"
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$PWD/$OUT_DIR/liboominject.dylib" \
  SIMCTL_CHILD_NR_OOM_ONE_IN="$FAIL_ONE_IN" \
  SIMCTL_CHILD_NR_OOM_DELAY="$INJECT_DELAY" \
  SIMCTL_CHILD_NR_OOM_THREAD="nr-oom-loop" \
  xcrun simctl launch --console "$SIMULATOR" "$BUNDLE_ID" \
      -RunHexOOMRepro \
      -HexOOMIterations "$APP_ITERATIONS" \
      -HexOOMStartDelay "$START_DELAY" > "$log" 2>&1 &
  local launch_pid=$!

  # NRTestApp is a UI app: on a PASSING run it stays alive, so `simctl launch
  # --console` would block forever. Wait for a verdict to appear in the log
  # instead, then shut the app down ourselves.
  local waited=0
  while (( waited < APP_TIMEOUT )); do
    if grep -qE "HexOOMRepro: DONE|libc\+\+abi|terminating due to|Assertion failed" \
         "$log" 2>/dev/null; then
      break
    fi
    sleep 2
    waited=$(( waited + 2 ))
  done
  sleep 1   # let the surrounding log lines flush
  xcrun simctl terminate "$SIMULATOR" "$BUNDLE_ID" > /dev/null 2>&1
  kill "$launch_pid" 2>/dev/null
  wait "$launch_pid" 2>/dev/null

  if (( waited >= APP_TIMEOUT )); then
    APP_RESULT="FAIL (no verdict within ${APP_TIMEOUT}s — see $log)"
    return 0
  fi

  local survived=0 crashed=0 drops=0
  grep -q "HexOOMRepro: DONE" "$log" && survived=1
  grep -qE "libc\+\+abi|terminating due to|Assertion failed" "$log" && crashed=1
  drops=$(grep -cE "Dropped handled (error|exception) report" "$log")

  echo
  echo "    injector armed : $(grep -c '\[NR_OOM\] ARMED' "$log")"
  echo "    reports dropped: $drops"
  echo "    reached DONE   : $survived"
  echo "    crash markers  : $crashed"
  echo "    full log       : $log"

  if [[ "$EXPECT_CRASH" -eq 1 ]]; then
    if [[ "$crashed" -eq 1 && "$survived" -eq 0 ]]; then
      APP_RESULT="PASS (crashed as expected with --expect-crash)"
    else
      APP_RESULT="FAIL (--expect-crash given but the app survived)"
    fi
    return 0
  fi

  if [[ "$crashed" -eq 1 ]]; then
    APP_RESULT="FAIL (the app was killed — see $log)"
  elif [[ "$survived" -eq 0 ]]; then
    APP_RESULT="FAIL (never reached DONE — app died silently or loop never started)"
  elif [[ "$drops" -eq 0 ]]; then
    # Treated as a failure on purpose: a run that provoked nothing proves nothing,
    # and reporting PASS here would hide a mis-armed injector.
    APP_RESULT="FAIL (INCONCLUSIVE: survived but nothing was dropped — injector never fired)"
  else
    APP_RESULT="PASS"
  fi
}

# ---- run ---------------------------------------------------------------------------
for stage in $STAGES; do
  echo
  echo "######## stage: $stage ########"
  case "$stage" in
    harness) run_harness ;;
    app)     run_app ;;
  esac
done

echo
echo "============== OOM resilience summary =============="
echo "native harness (store path survives):  $HARNESS_RESULT"
echo "stored reports well-formed:            $VERIFY_RESULT"
echo "app end-to-end (crash boundary holds): $APP_RESULT"

for result in "$HARNESS_RESULT" "$VERIFY_RESULT" "$APP_RESULT"; do
  case "$result" in
    FAIL*|ERROR*) echo "RESULT: FAIL"; exit 1 ;;
  esac
done
echo "RESULT: PASS"
