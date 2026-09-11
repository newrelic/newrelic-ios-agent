#!/usr/bin/env bash
#
# Run the agent's unit tests with memory-safety diagnostics enabled, so that
# use-after-free bugs fail loudly instead of silently reading recycled memory.
#
# Two modes:
#   zombies (default)  NSZombieEnabled + MallocScribble + friends. Cheap. A stale pointer
#                      traps with "message sent to deallocated instance", naming the type
#                      of the object that was already freed.
#   asan               AddressSanitizer. Slower and needs its own instrumented build, but
#                      reports the allocating *and* freeing stacks - what you want once you
#                      know a UAF exists and need to find who released the object.
#
# The diagnostics are injected as environment variables into the .xctestrun produced by
# build-for-testing. That file is the complete launch spec consumed by
# test-without-building, which makes this explicit and verifiable -- unlike a scheme's
# Diagnostics checkboxes, which are not reliably baked into the .xctestrun.
#
# See Tests/MEMORY-SAFETY.md.

set -uo pipefail

WORKSPACE="Agent.xcworkspace"
SCHEME="Agent-iOS"
TEST_TARGET="Agent_Tests"
DERIVED_DATA="build/memory-safety"

# The memory-safety suite: the classes that exercise object lifetime across
# autorelease-pool and harvest-cycle boundaries, which is where the agent has historically
# shipped use-after-free bugs. Keep in sync with Tests/MEMORY-SAFETY.md.
#
# Deliberately excluded: NRMAHarvesterConnectionTests. Its -testSendData issues a real,
# unmocked request to mobile-collector.newrelic.com and asserts a 403, so it fails with
# statusCode 0 whenever the network is unavailable. This suite is meant to be a
# deterministic gate on memory safety; it must not go red because of a live HTTP call.
# Run it with --only when you specifically want it.
SUITE=(
  "NRMAHarvesterConfigurationLifetimeTests"
  "NRMAHarvesterTest"
  "NRMAHarvestControllerTest"
  "NRMAHarvesterStateTest"
  "NRMAConnectionTest"
  "SessionReplayTest"
)

# Zombie-mode diagnostics.
#   NSZombieEnabled                     deallocated objects become trapping zombies
#   NSDeallocateZombies                 keep the zombies around rather than freeing them
#   MallocScribble                      fill freed memory with 0x55
#   MallocPreScribble                   fill freshly allocated memory with 0xAA
#   MallocGuardEdges                    guard pages around large allocations
#   NSAutoreleaseFreedObjectCheckEnabled  catch autoreleasing an already-freed object
DIAGNOSTICS=(
  "NSZombieEnabled=YES"
  "NSDeallocateZombies=NO"
  "MallocScribble=1"
  "MallocPreScribble=1"
  "MallocGuardEdges=1"
  "NSAutoreleaseFreedObjectCheckEnabled=1"
)

MODE="zombies"
SIMULATOR=""
RUN_ALL=0
NO_BUILD=0
STACKS=0
ONLY=()

usage() {
  cat <<USAGE
usage: scripts/run_memory_safety_tests.sh [options]

  --asan                Run under AddressSanitizer instead of zombies/scribble.
  --all                 Run the whole ${TEST_TARGET} target, not just the curated suite.
  --only <Class[/test]> Run one class or one test. Repeatable. Overrides the suite.
  --stacks              Also set MallocStackLogging, so malloc_history can resolve a
                        zombie address to its allocation stack. Slow; for debugging.
  --simulator <id>      Simulator name or UDID. Default: a booted iPhone, else the newest
                        available iPhone.
  --derived-data <path> Default: ${DERIVED_DATA}
  --no-build            Reuse an existing build (skip build-for-testing).
  --list                Print the suite and exit.
  -h, --help            This message.

examples:
  scripts/run_memory_safety_tests.sh
  scripts/run_memory_safety_tests.sh --only NRMAHarvesterConfigurationLifetimeTests
  scripts/run_memory_safety_tests.sh --asan --all
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --asan)          MODE="asan"; shift ;;
    --all)           RUN_ALL=1; shift ;;
    --only)          ONLY+=("$2"); shift 2 ;;
    --stacks)        STACKS=1; shift ;;
    --simulator)     SIMULATOR="$2"; shift 2 ;;
    --derived-data)  DERIVED_DATA="$2"; shift 2 ;;
    --no-build)      NO_BUILD=1; shift ;;
    --list)          printf '%s\n' "${SUITE[@]}"; exit 0 ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")/.." || exit 1
[[ -d "$WORKSPACE" ]] || { echo "error: $WORKSPACE not found" >&2; exit 1; }

if [[ $STACKS -eq 1 ]]; then
  DIAGNOSTICS+=("MallocStackLogging=1" "MallocStackLoggingNoCompact=1")
fi

# ---- simulator: prefer one already booted so repeat runs skip the boot cost -----------
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
        if d.get("isAvailable") and "iPhone" in d.get("name", ""):
            (booted if d.get("state") == "Booted" else avail).append((runtime, d))
pick = sorted(booted, key=lambda i: i[0])[-1:] or sorted(avail, key=lambda i: i[0])[-1:]
if pick:
    print(pick[0][1]["udid"])
')
fi
[[ -n "$SIMULATOR" ]] || { echo "error: no iOS simulator found; pass --simulator" >&2; exit 1; }

if [[ "$SIMULATOR" =~ ^[0-9A-Fa-f-]{36}$ ]]; then
  DESTINATION="platform=iOS Simulator,id=${SIMULATOR}"
else
  DESTINATION="platform=iOS Simulator,name=${SIMULATOR}"
fi

# ---- scope ---------------------------------------------------------------------------
TEST_ARGS=()
if [[ ${#ONLY[@]} -gt 0 ]]; then
  for t in "${ONLY[@]}"; do
    [[ "$t" == *"/"* && "$t" != "${TEST_TARGET}/"* ]] && t="${TEST_TARGET}/${t}"
    [[ "$t" != *"/"* ]] && t="${TEST_TARGET}/${t}"
    TEST_ARGS+=("-only-testing:$t")
  done
elif [[ $RUN_ALL -eq 0 ]]; then
  for t in "${SUITE[@]}"; do TEST_ARGS+=("-only-testing:${TEST_TARGET}/${t}"); done
fi

SANITIZER_ARGS=()
[[ "$MODE" == "asan" ]] && SANITIZER_ARGS+=("-enableAddressSanitizer" "YES")

mkdir -p "$DERIVED_DATA"
LOG="${DERIVED_DATA}/memory-safety-$(date +%Y%m%d-%H%M%S).log"

echo "mode:        $MODE"
echo "destination: $DESTINATION"
if [[ ${#TEST_ARGS[@]} -eq 0 ]]; then
  echo "scope:       entire ${TEST_TARGET} target"
else
  echo "scope:       ${#TEST_ARGS[@]} selection(s)"
fi
echo "log:         $LOG"
echo

# ---- build ---------------------------------------------------------------------------
if [[ $NO_BUILD -eq 0 ]]; then
  echo "==> building for testing"
  xcodebuild build-for-testing \
    -workspace "$WORKSPACE" -scheme "$SCHEME" \
    -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" \
    ${SANITIZER_ARGS[@]+"${SANITIZER_ARGS[@]}"} 2>&1 | tee -a "$LOG" \
    | grep -E "error:|\*\* .* (SUCCEEDED|FAILED)"
  BUILD_RC=${PIPESTATUS[0]}
  if [[ $BUILD_RC -ne 0 ]]; then
    echo "FAILED: build-for-testing exited $BUILD_RC (see $LOG)" >&2
    exit $BUILD_RC
  fi
fi

XCTESTRUN=$(ls -t "${DERIVED_DATA}/Build/Products/"*.xctestrun 2>/dev/null | head -1)
if [[ -z "$XCTESTRUN" ]]; then
  echo "FAILED: no .xctestrun in ${DERIVED_DATA}/Build/Products (build first)" >&2
  exit 1
fi

# ---- inject diagnostics --------------------------------------------------------------
# ASan is a build-time instrumentation, so it needs no env injection.
if [[ "$MODE" == "zombies" ]]; then
  echo "==> enabling diagnostics in $(basename "$XCTESTRUN")"
  python3 scripts/lib_patch_xctestrun.py "$XCTESTRUN" \
    ${DIAGNOSTICS[@]+"${DIAGNOSTICS[@]}"} | tee -a "$LOG"
  PATCH_RC=${PIPESTATUS[0]}
  if [[ $PATCH_RC -ne 0 ]]; then
    echo "FAILED: could not patch $XCTESTRUN" >&2
    exit 1
  fi
fi

# ---- run -----------------------------------------------------------------------------
echo
echo "==> running tests"
xcodebuild test-without-building -xctestrun "$XCTESTRUN" \
  -destination "$DESTINATION" \
  ${SANITIZER_ARGS[@]+"${SANITIZER_ARGS[@]}"} \
  ${TEST_ARGS[@]+"${TEST_ARGS[@]}"} 2>&1 | tee -a "$LOG" \
  | grep -E "Test Case .*(passed|failed)|error:|message sent to deallocated instance|AddressSanitizer|Executed [0-9]+ test|\*\* TEST"
TEST_RC=${PIPESTATUS[0]}

# ---- verdict -------------------------------------------------------------------------
# A zombie trap kills the test process, so xcodebuild can report "Executed 0 tests, with 0
# failures" for the very run that found the bug. Never trust the summary line alone.
count() { local n; n=$(grep -c "$1" "$LOG" 2>/dev/null | tr -d ' '); echo "${n:-0}"; }
ZOMBIES=$(count "message sent to deallocated instance")
ASAN=$(count "ERROR: AddressSanitizer")
CRASHES=$(count "Restarting after unexpected exit")

echo
echo "================ memory safety summary ================"
printf 'mode:                             %s\n' "$MODE"
printf 'zombie messages (use-after-free): %s\n' "$ZOMBIES"
printf 'AddressSanitizer reports:         %s\n' "$ASAN"
printf 'unexpected process exits:         %s\n' "$CRASHES"
printf 'xcodebuild exit code:             %s\n' "$TEST_RC"

if [[ "$ZOMBIES" -gt 0 ]]; then
  echo
  echo "--- use-after-free detected ---"
  grep "message sent to deallocated instance" "$LOG" | sed 's/^/  /' | sort -u
  echo
  echo "The class named above is the type of the object that was already freed. Look for a"
  echo "property declared 'assign'/'unsafe_unretained' of that type, or a raw pointer kept"
  echo "past the lifetime of whatever owned it."
fi

if [[ "$ASAN" -gt 0 ]]; then
  echo
  echo "--- AddressSanitizer ---"
  grep -A 25 "ERROR: AddressSanitizer" "$LOG" | sed 's/^/  /' | head -60
fi

if [[ "$CRASHES" -gt 0 && "$ZOMBIES" -eq 0 && "$ASAN" -eq 0 ]]; then
  echo
  echo "NOTE: the test process died with no zombie or ASan report. That is still a real"
  echo "failure - it usually means memory was corrupted rather than merely stale. Re-run"
  echo "with --asan for allocation and free stacks."
fi

echo "full log: $LOG"
echo "======================================================="

if [[ $TEST_RC -ne 0 || "$ZOMBIES" -gt 0 || "$ASAN" -gt 0 || "$CRASHES" -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
