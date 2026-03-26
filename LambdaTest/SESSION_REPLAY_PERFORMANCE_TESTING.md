# Session Replay Performance Testing

This document explains how to measure the performance overhead of Session Replay feature in the New Relic iOS agent.

## Quick Start

```bash
# Set environment variables
export LT_USERNAME="your-username"
export LT_ACCESSKEY="your-access-key"
export LT_APP_ID="your-app-id"

# Run baseline test
BASELINE=1 npx wdio LambdaTest/wdio-config-ios-baseline.js

# Run Session Replay test
npx wdio LambdaTest/wdio-config-ios-session-replay.js

# Compare results
node LambdaTest/scripts/compare-session-replay-overhead.js \
  LambdaTest/baseline_results.json \
  LambdaTest/session_replay_results.json

# View report
cat LambdaTest/comparison-report.txt
```

Results are automatically saved to JSON files. No manual copying required!

## Overview

Session Replay performance testing compares two test runs:
1. **Baseline**: App running WITHOUT Session Replay enabled
2. **Session Replay**: App running WITH Session Replay enabled

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

### Step 1: Run Baseline Test (Session Replay OFF)

This test runs the app WITHOUT Session Replay to establish baseline metrics.

**Important:** Set `BASELINE=1` environment variable so the test saves results correctly.

```bash
cd LambdaTest
BASELINE=1 npx wdio wdio-config-ios-baseline.js
```

The test will:
- Perform intensive UI operations (5 navigation cycles, scrolling, image loading, SwiftUI interactions)
- Collect memory and CPU metrics every 2 seconds
- **Automatically save results** to `baseline_results.json`

### Step 2: Run Session Replay Test (Session Replay ON)

This test runs the app WITH Session Replay enabled to measure overhead.

```bash
cd LambdaTest
npx wdio wdio-config-ios-session-replay.js
```

The test performs the same intensive UI operations and collects the same metrics.
- **Automatically saves results** to `session_replay_results.json`

### Step 3: Compare Results

Use the comparison script to analyze the overhead:

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
- **Baseline test**: Checks for `BASELINE=1` environment variable
- **Session Replay test**: No environment variable set

Based on detection, results are automatically saved:
- Baseline → `baseline_results.json` with `sessionReplayEnabled: false`
- Session Replay → `session_replay_results.json` with `sessionReplayEnabled: true`

The comparison script reads both JSON files and saves a detailed report to `comparison-report.txt`.

### 5. Test Scenarios

The enhanced test performs intensive UI operations to stress test Session Replay:
- **Navigation stress test**: 5 iterations of screen navigation
- **Infinite scroll test**: 4 scrolls down + 2 scrolls up to test scroll capture
- **Image collection scrolling**: 4 scrolls through image collections
- **SwiftUI interactions**: 2 examples with up to 3 button taps each + scrolling within SwiftUI views

Total test duration: ~5 minutes with continuous monitoring (~147-148 metric samples).

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

1. Run both tests sequentially (results auto-save to JSON files)
2. Run comparison script (auto-saves report to txt file)
3. Upload results as artifacts or post to PRs

Example:
```bash
# Set credentials
export LT_USERNAME="your-username"
export LT_ACCESSKEY="your-access-key"
export LT_APP_ID="your-app-id"

# Run baseline (automatically saves to baseline_results.json)
BASELINE=1 npx wdio wdio-config-ios-baseline.js

# Run Session Replay test (automatically saves to session_replay_results.json)
npx wdio wdio-config-ios-session-replay.js

# Compare (automatically saves to comparison-report.txt)
node scripts/compare-session-replay-overhead.js baseline_results.json session_replay_results.json

# Upload artifacts
# - baseline_results.json
# - session_replay_results.json
# - comparison-report.txt
```

## Files

- `wdio-config-ios-baseline.js`: WebDriverIO config for baseline test
- `wdio-config-ios-session-replay.js`: WebDriverIO config for Session Replay test
- `tests/session-replay-performance.test.js`: Test suite with intensive UI operations
- `scripts/compare-session-replay-overhead.js`: Comparison and analysis script
- `Test Harness/NRTestApp/NRTestApp/MetricsConsumer.swift`: Metrics collection implementation
- `Test Harness/NRTestApp/NRTestApp/AppDelegate.swift`: Session Replay toggle logic

## Notes

- Session Replay overhead is expected to be higher during intensive UI operations
- Memory usage will be higher due to screenshot buffering and encoding
- CPU usage will be higher due to screen capture and processing
- The goal is to ensure overhead remains within acceptable limits for production use
