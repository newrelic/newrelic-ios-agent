#!/bin/bash

# Session Replay Performance Comparison Test Runner
# This script runs both baseline and Session Replay tests, then compares results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAMBDATEST_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$LAMBDATEST_DIR/performance-results"

echo "=================================================="
echo "Session Replay Performance Comparison Test"
echo "=================================================="
echo ""

# Check required environment variables
if [ -z "$LT_USERNAME" ] || [ -z "$LT_ACCESSKEY" ]; then
    echo "❌ Error: LT_USERNAME and LT_ACCESSKEY environment variables must be set"
    echo ""
    echo "Export them with:"
    echo "  export LT_USERNAME='your-username'"
    echo "  export LT_ACCESSKEY='your-access-key'"
    exit 1
fi

if [ -z "$LT_APP_ID" ]; then
    echo "⚠️  Warning: LT_APP_ID not set. Make sure it's configured in wdio config files."
fi

# Create results directory
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Step 1: Run baseline test
echo "==================================================
STEP 1: Running BASELINE test (Session Replay OFF)
=================================================="
echo ""

cd "$LAMBDATEST_DIR"

echo "Starting baseline test..."
npx wdio wdio-config-ios-baseline.js | tee "$RESULTS_DIR/baseline-$TIMESTAMP.log"

# Extract JSON from log
echo ""
echo "Extracting baseline metrics..."
if grep -q "=== TEST SUMMARY ===" "$RESULTS_DIR/baseline-$TIMESTAMP.log"; then
    # Extract the JSON between TEST SUMMARY and the next line of ===
    sed -n '/=== TEST SUMMARY ===/,/^✓/{ /=== TEST SUMMARY ===/d; /^✓/d; p; }' \
        "$RESULTS_DIR/baseline-$TIMESTAMP.log" | \
        grep -v "^$" > "$RESULTS_DIR/baseline-metrics-$TIMESTAMP.json"

    if [ -s "$RESULTS_DIR/baseline-metrics-$TIMESTAMP.json" ]; then
        echo "✅ Baseline metrics saved to: baseline-metrics-$TIMESTAMP.json"
    else
        echo "❌ Failed to extract baseline metrics from log"
        exit 1
    fi
else
    echo "❌ Baseline test did not complete successfully"
    exit 1
fi

echo ""
echo "Waiting 30 seconds before next test..."
sleep 30

# Step 2: Run Session Replay test
echo ""
echo "==================================================
STEP 2: Running Session Replay test (Session Replay ON)
=================================================="
echo ""

echo "Starting Session Replay test..."
npx wdio wdio-config-ios-session-replay.js | tee "$RESULTS_DIR/session-replay-$TIMESTAMP.log"

# Extract JSON from log
echo ""
echo "Extracting Session Replay metrics..."
if grep -q "=== TEST SUMMARY ===" "$RESULTS_DIR/session-replay-$TIMESTAMP.log"; then
    sed -n '/=== TEST SUMMARY ===/,/^✓/{ /=== TEST SUMMARY ===/d; /^✓/d; p; }' \
        "$RESULTS_DIR/session-replay-$TIMESTAMP.log" | \
        grep -v "^$" > "$RESULTS_DIR/session-replay-metrics-$TIMESTAMP.json"

    if [ -s "$RESULTS_DIR/session-replay-metrics-$TIMESTAMP.json" ]; then
        echo "✅ Session Replay metrics saved to: session-replay-metrics-$TIMESTAMP.json"
    else
        echo "❌ Failed to extract Session Replay metrics from log"
        exit 1
    fi
else
    echo "❌ Session Replay test did not complete successfully"
    exit 1
fi

# Step 3: Compare results
echo ""
echo "==================================================
STEP 3: Comparing results and calculating overhead
=================================================="
echo ""

node "$SCRIPT_DIR/compare-session-replay-overhead.js" \
    "$RESULTS_DIR/baseline-metrics-$TIMESTAMP.json" \
    "$RESULTS_DIR/session-replay-metrics-$TIMESTAMP.json" | \
    tee "$RESULTS_DIR/comparison-$TIMESTAMP.txt"

COMPARISON_EXIT_CODE=$?

echo ""
echo "==================================================
TEST COMPLETE
=================================================="
echo ""
echo "Results saved to:"
echo "  Baseline log:        $RESULTS_DIR/baseline-$TIMESTAMP.log"
echo "  Baseline metrics:    $RESULTS_DIR/baseline-metrics-$TIMESTAMP.json"
echo "  Session Replay log:  $RESULTS_DIR/session-replay-$TIMESTAMP.log"
echo "  Session Replay metrics: $RESULTS_DIR/session-replay-metrics-$TIMESTAMP.json"
echo "  Comparison report:   $RESULTS_DIR/comparison-$TIMESTAMP.txt"
echo ""

if [ $COMPARISON_EXIT_CODE -eq 0 ]; then
    echo "✅ Session Replay overhead is ACCEPTABLE"
    exit 0
else
    echo "❌ Session Replay overhead EXCEEDS acceptable limits"
    exit 1
fi
