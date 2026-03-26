# Session Replay Performance Testing

This document explains how to measure the performance overhead of Session Replay feature in the New Relic iOS agent.

## Quick Start

```bash
# Set environment variables
export LT_USERNAME="your-username"
export LT_ACCESSKEY="your-access-key"
export LT_APP_ID="your-app-id"

# Run all three tests
NO_AGENT=1 npx wdio LambdaTest/wdio-config-ios-no-agent.js     # No agent test
BASELINE=1 npx wdio LambdaTest/wdio-config-ios-baseline.js     # Agent only test
npx wdio LambdaTest/wdio-config-ios-session-replay.js          # Agent + Session Replay test

# Compare results (two-way)
node LambdaTest/scripts/compare-session-replay-overhead.js \
  LambdaTest/baseline_results.json \
  LambdaTest/session_replay_results.json

# Or compare all three (three-way)
node LambdaTest/scripts/compare-three-way-overhead.js \
  LambdaTest/no_agent_results.json \
  LambdaTest/baseline_results.json \
  LambdaTest/session_replay_results.json

# View reports
cat LambdaTest/comparison-report.txt          # Two-way comparison
cat LambdaTest/three-way-comparison-report.txt # Three-way comparison
```

Results are automatically saved to JSON files. No manual copying required!

## Overview

Session Replay performance testing compares three test configurations:
1. **No Agent**: App running WITHOUT New Relic agent (pure baseline)
2. **Agent Only (Baseline)**: App running WITH agent, WITHOUT Session Replay enabled
3. **Agent + Session Replay**: App running WITH both agent AND Session Replay enabled

This allows us to measure:
- **Agent overhead**: Impact of the New Relic agent itself (vs no agent)
- **Session Replay overhead**: Incremental impact of Session Replay (on top of agent)
- **Total overhead**: Combined impact of agent + Session Replay (vs no agent)

We measure and compare:
- **Memory usage** (average and peak)
- **Memory overhead** (absolute MB and percentage)
- **CPU load** (average and peak)
- **CPU overhead** (percentage increase)

## Prerequisites

1. Build the NRTestApp with performance testing enabled
2. Upload the app to LambdaTest and get the app ID (see instructions below)
3. Set environment variables:
   ```bash
   export LT_USERNAME="your-username"
   export LT_ACCESSKEY="your-access-key"
   export LT_APP_ID="your-app-id"
   ```

## Building and Uploading the App

### Step 1: Build the NRTestApp

Build the app for testing on real devices:

```bash
# Navigate to NRTestApp directory
cd "Test Harness/NRTestApp"

# Build and archive the app
xcodebuild -workspace ../../Agent.xcworkspace \
  -scheme NRTestApp \
  -configuration Release \
  -sdk iphoneos \
  -archivePath ./NRTestApp.xcarchive \
  clean archive

# Create an exportOptions.plist for ad-hoc distribution
cat > exportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

# Export the .ipa
xcodebuild -exportArchive \
  -archivePath ./NRTestApp.xcarchive \
  -exportPath . \
  -exportOptionsPlist exportOptions.plist
```

This will create `NRTestApp.ipa` in the current directory.

### Step 2: Upload to LambdaTest

Upload the .ipa to LambdaTest Real Device Cloud:

```bash
# Upload the app
curl -u "$LT_USERNAME:$LT_ACCESSKEY" \
  -X POST "https://manual-api.lambdatest.com/app/upload/realDevice" \
  -F "appFile=@NRTestApp.ipa" \
  -F "name=NRTestApp"
```

The response will include the `app_id`. Save this ID and set it as an environment variable:

```bash
export LT_APP_ID="lt://APP1234567890123456789"
```

Alternatively, you can upload via the LambdaTest web interface:
1. Go to https://appautomation.lambdatest.com/build
2. Click "Upload" and select your .ipa file
3. Copy the app URL (starts with `lt://`)

## Running the Tests

### Step 1: Run No Agent Test (Pure Baseline)

This test runs the app WITHOUT the New Relic agent to establish a pure baseline.

**Important:** Set `NO_AGENT=1` environment variable so the test saves results correctly.

```bash
cd LambdaTest
NO_AGENT=1 npx wdio wdio-config-ios-no-agent.js
```

The test will:
- Perform intensive UI operations (5 navigation cycles, scrolling, image loading, 3 SwiftUI interactions)
- Collect memory and CPU metrics every 2 seconds
- **Automatically save results** to `no_agent_results.json`

### Step 2: Run Baseline Test (Agent Only, Session Replay OFF)

This test runs the app WITH the agent but WITHOUT Session Replay to measure agent overhead.

**Important:** Set `BASELINE=1` environment variable so the test saves results correctly.

```bash
cd LambdaTest
BASELINE=1 npx wdio wdio-config-ios-baseline.js
```

The test will:
- Perform the same intensive UI operations
- Collect memory and CPU metrics every 2 seconds
- **Automatically save results** to `baseline_results.json`

### Step 3: Run Session Replay Test (Agent + Session Replay ON)

This test runs the app WITH both agent AND Session Replay enabled to measure total overhead.

```bash
cd LambdaTest
npx wdio wdio-config-ios-session-replay.js
```

The test performs the same intensive UI operations and collects the same metrics.
- **Automatically saves results** to `session_replay_results.json`

### Step 4: Compare Results

#### Option A: Two-Way Comparison (Agent vs Agent+SR)

Compare agent-only vs agent+session-replay to measure Session Replay's incremental overhead:

```bash
node scripts/compare-session-replay-overhead.js baseline_results.json session_replay_results.json
```

The script will:
- Display detailed comparison to console
- **Automatically save report** to `comparison-report.txt`
- Output memory usage comparison (average, peak, range)
- Output CPU usage comparison (average, peak)
- Output performance metrics comparison (startup time, TTI)
- Output health check results (hangs, leaks)
- Provide overhead summary with verdict (PASS/FAIL)

#### Option B: Three-Way Comparison (No Agent vs Agent vs Agent+SR)

Compare all three configurations to see both agent and Session Replay overhead:

```bash
node scripts/compare-three-way-overhead.js no_agent_results.json baseline_results.json session_replay_results.json
```

The script will:
- Display detailed three-way comparison to console
- **Automatically save report** to `three-way-comparison-report.txt`
- Show agent overhead (vs no agent)
- Show Session Replay overhead (on top of agent)
- Show total overhead (vs no agent)
- Provide comprehensive overhead analysis

## Acceptable Overhead Thresholds

The comparison script uses these thresholds:
- **Memory overhead**: ≤ 50 MB absolute OR ≤ 25% increase
- **CPU overhead**: ≤ 15% increase

If overhead exceeds these thresholds, the test will FAIL.

## How It Works

### 1. App Configuration

**Agent-Level Override** (`Agent/General/NewRelicAgentInternal.m:1387`)

The agent's `isSessionReplayEnabled` method was modified to check for the `ENABLE_SESSION_REPLAY` environment variable BEFORE checking server configuration:

```objc
- (BOOL) isSessionReplayEnabled {
    // Check for local override first (for performance testing)
    NSString *localOverride = [[NSProcessInfo processInfo] environment][@"ENABLE_SESSION_REPLAY"];
    if (localOverride != nil) {
        BOOL enabled = [localOverride isEqualToString:@"1"] || ...;
        NRLOG_AGENT_VERBOSE(@"🎥 Session Replay using LOCAL OVERRIDE: %@", enabled ? @"ENABLED" : @"DISABLED");
        return enabled;
    }

    // Fall back to server configuration
    // ...
}
```

This allows local control of Session Replay for testing, overriding the server-side configuration.

**App Configuration** (`AppDelegate.swift`)

The app logs whether the environment variable is set, helping verify configuration during tests.

### 2. Metrics Collection

`MetricsConsumer.swift` collects metrics using:
- **PerformanceSuite**: Startup time, TTI, rendering metrics, hangs, leaks
- **Timer-based monitoring**: Memory and CPU sampled every 2 seconds
- **mach APIs**: Low-level system metrics
  - `mach_task_basic_info` for memory (resident_size)
  - `thread_basic_info` for CPU (cpu_usage)

### 3. Metrics Retrieval

All metrics are saved to a hidden UILabel with accessibility ID `performance_metrics_json`. The test reads this label using Appium/WebDriverIO.

### 4. Automatic Results Storage

The test automatically detects which configuration is running:
- **No Agent test**: Checks for `NO_AGENT=1` environment variable
- **Baseline test**: Checks for `BASELINE=1` environment variable
- **Session Replay test**: No environment variable set

Based on detection, results are automatically saved:
- No Agent → `no_agent_results.json` with `agentEnabled: false, sessionReplayEnabled: false`
- Baseline → `baseline_results.json` with `agentEnabled: true, sessionReplayEnabled: false`
- Session Replay → `session_replay_results.json` with `agentEnabled: true, sessionReplayEnabled: true`

The comparison scripts read the JSON files and save detailed reports:
- Two-way comparison → `comparison-report.txt`
- Three-way comparison → `three-way-comparison-report.txt`

### 5. Test Scenarios

The enhanced test performs intensive UI operations to stress test Session Replay:
- **Navigation stress test**: 5 iterations of screen navigation
- **Infinite scroll test**: 4 scrolls down + 2 scrolls up to test scroll capture
- **Image collection scrolling**: 4 scrolls through image collections
- **SwiftUI interactions**: 3 examples with up to 3 button taps each + scrolling within SwiftUI views

Total test duration: ~5 minutes with continuous monitoring (~145-150 metric samples).

## Interpreting Results

### Example Output

```
SESSION REPLAY PERFORMANCE OVERHEAD ANALYSIS
======================================================================

--- MEMORY USAGE COMPARISON ---

Average Memory:
  Baseline:        145.32 MB
  Session Replay:  168.45 MB
  Overhead:        +23.13 MB (+15.92%)

Peak Memory:
  Baseline:        187.21 MB
  Session Replay:  215.67 MB
  Overhead:        +28.46 MB (+15.20%)

--- CPU USAGE COMPARISON ---

Average CPU:
  Baseline:        8.45%
  Session Replay:  9.87%
  Overhead:        +1.42% (+16.80%)

--- VERDICT ---
✅ PASS: Average memory overhead (23.13 MB) is within acceptable limits
✅ PASS: Memory overhead percentage (15.92%) is within acceptable limits
❌ FAIL: CPU overhead (16.80%) exceeds threshold (15%)

❌ SESSION REPLAY OVERHEAD EXCEEDS ACCEPTABLE LIMITS
```

### What to Look For

- **Memory overhead**: How much additional RAM does Session Replay consume?
- **CPU overhead**: How much additional CPU does Session Replay use?
- **Startup impact**: Does Session Replay slow down app startup?
- **Stability**: Are there any hangs or memory leaks?

### Troubleshooting

**Metrics not collected:**
- Check that the app was built with PerformanceSuite enabled
- Verify the hidden label is being created (check device logs for "Metrics label created")
- Ensure sufficient wait time for metrics collection (test pauses 5 seconds)

**Session Replay not enabling:**
- Check LambdaTest device logs for "🎥 Session Replay ENABLED" message
- Verify `ENABLE_SESSION_REPLAY` environment variable is set in config
- Confirm NewRelic agent has Session Replay feature available

**High variance between runs:**
- Run multiple iterations and average the results
- Use the same device/OS version for both tests
- Ensure LambdaTest device is not throttled or under load

## Automation with CI/CD

To integrate with GitHub Actions or other CI/CD:

1. Run all three tests sequentially (results auto-save to JSON files)
2. Run comparison scripts (auto-save reports to txt files)
3. Upload results as artifacts or post to PRs

Example:
```bash
# Set credentials
export LT_USERNAME="your-username"
export LT_ACCESSKEY="your-access-key"
export LT_APP_ID="your-app-id"

# Run all three tests (automatically save to JSON files)
NO_AGENT=1 npx wdio wdio-config-ios-no-agent.js           # → no_agent_results.json
BASELINE=1 npx wdio wdio-config-ios-baseline.js           # → baseline_results.json
npx wdio wdio-config-ios-session-replay.js                # → session_replay_results.json

# Compare (automatically saves to report files)
node scripts/compare-session-replay-overhead.js baseline_results.json session_replay_results.json  # → comparison-report.txt
node scripts/compare-three-way-overhead.js no_agent_results.json baseline_results.json session_replay_results.json  # → three-way-comparison-report.txt

# Upload artifacts
# - no_agent_results.json
# - baseline_results.json
# - session_replay_results.json
# - comparison-report.txt
# - three-way-comparison-report.txt
```

## Files

- `wdio-config-ios-no-agent.js`: WebDriverIO config for no agent test
- `wdio-config-ios-baseline.js`: WebDriverIO config for agent-only baseline test
- `wdio-config-ios-session-replay.js`: WebDriverIO config for Session Replay test
- `tests/session-replay-performance.test.js`: Test suite with intensive UI operations
- `scripts/compare-session-replay-overhead.js`: Two-way comparison script (baseline vs session replay)
- `scripts/compare-three-way-overhead.js`: Three-way comparison script (no agent vs agent vs session replay)
- `Test Harness/NRTestApp/NRTestApp/MetricsConsumer.swift`: Metrics collection implementation
- `Test Harness/NRTestApp/NRTestApp/AppDelegate.swift`: Session Replay toggle logic

## Notes

- Session Replay overhead is expected to be higher during intensive UI operations
- Memory usage will be higher due to screenshot buffering and encoding
- CPU usage will be higher due to screen capture and processing
- The goal is to ensure overhead remains within acceptable limits for production use
