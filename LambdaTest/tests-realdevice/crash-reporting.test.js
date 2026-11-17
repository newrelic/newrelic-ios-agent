/**
 * Crash Reporting Test - REAL DEVICE ONLY
 *
 * Taps "Crash Now!" in the Utilities screen, relaunches the app, and verifies the
 * agent uploaded the pending crash report to the crash collector.
 *
 * WHY THIS LIVES OUTSIDE ./tests
 * ------------------------------
 * This spec deliberately kills the app under test, so it must run LAST. The
 * real-device config lists specs explicitly ("./tests/*.test.js" first, then this
 * file) and runs with maxInstances: 1, which guarantees the ordering. Keeping the
 * file out of ./tests also keeps the VIRTUAL config's ./tests/*.test.js glob from
 * picking it up.
 *
 * It also complements utilities.test.js, which asserts "Crash Now!" exists but
 * deliberately never clicks it.
 *
 * HOW THE VERIFICATION WORKS
 * --------------------------
 * The agent writes a .crash report at crash time and uploads it on the NEXT
 * launch (Agent/CrashHandler/NRMACrashDataUploader.m). That upload logs to the
 * console via NSLog, which lands in the device syslog:
 *
 *   "NEWRELIC CRASH UPLOADER - Perform crash upload"      (before the POST)
 *   "NEWRELIC CRASH UPLOADER - Crash Upload Response: ..." (with the HTTP response)
 *   "NEWRELIC CRASH UPLOADER - Crash Upload Response Error: ..." (failures only)
 *
 * Two agent-side preconditions make those lines visible, both verified against
 * the agent source. If either changes, this test's first assertion is what tells
 * you so -- see the note on it.
 *
 *   1. Log level. NRTestApp's AppDelegate calls
 *      NRLogger.setLogLevels(NRLogLevelDebug), and setLogLevels expands a single
 *      constant, so Debug includes Verbose. The upload lines are
 *      NRLOG_AGENT_VERBOSE, so they are emitted.
 *   2. Log target. When NRFeatureFlag_AutoCollectLogs is enabled AND the
 *      collector's connect config sets log_reporting_enabled, the harvester
 *      redirects stdout and calls setLogTargets(NRLogTargetFile) -- console
 *      logging stops and these lines DISAPPEAR from syslog. AutoCollectLogs is
 *      off by default and NRTestApp does not enable it, so the console target
 *      survives today.
 */

// Emitted before the POST; proves the uploader found a pending report and tried.
const UPLOAD_ATTEMPT = "NEWRELIC CRASH UPLOADER - Perform crash upload";
// Emitted in the completion handler with the NSHTTPURLResponse description.
const UPLOAD_RESPONSE = "NEWRELIC CRASH UPLOADER - Crash Upload Response:";
// Only logged on failure (NRLOG_AGENT_ERROR).
const UPLOAD_ERROR = "NEWRELIC CRASH UPLOADER - Crash Upload Response Error:";
// Any agent console line looks like "NewRelic(<version>,<thread>): ...".
const AGENT_LOG_PREFIX = "NewRelic(";

// How long to wait, after relaunch, for the upload to happen. The uploader runs
// during agent startup, but on real hardware over a shared network the POST and
// its response can lag.
const UPLOAD_TIMEOUT_MS = 90000;
const POLL_INTERVAL_MS = 3000;

// Appium queryAppState codes.
const APP_STATE_NOT_INSTALLED = 0;
const APP_STATE_NOT_RUNNING = 1;
const APP_STATE_FOREGROUND = 4;

// State shared across the ordered `it` blocks below.
const state = {
  bundleId: null,
  // getLogs drains the buffer, so every read is accumulated here rather than
  // re-read. A line seen during an early poll must still count later.
  syslog: [],
};

/**
 * All syslog access goes through this one function. If getLogs('syslog') turns
 * out to be unsupported on LambdaTest real devices, this is the only place that
 * needs to change (e.g. to their device-log REST API).
 *
 * Returns the newly-seen lines and appends them to state.syslog.
 */
async function drainSyslog() {
  let entries;
  try {
    entries = await driver.getLogs("syslog");
  } catch (error) {
    throw new Error(
      `Could not read the device syslog via getLogs('syslog'): ${error.message}. ` +
        "If LambdaTest does not support this log type on real devices, swap " +
        "drainSyslog() for their device-log REST API -- it is the only reader."
    );
  }

  const lines = (entries || [])
    .map((entry) => (typeof entry === "string" ? entry : entry && entry.message))
    .filter((line) => typeof line === "string" && line.length > 0);

  state.syslog.push(...lines);
  return lines;
}

function syslogMatching(needle) {
  return state.syslog.filter((line) => line.includes(needle));
}

/**
 * LambdaTest resigns the uploaded IPA, which can rewrite the bundle identifier,
 * so read it off the live session rather than hardcoding it. LT_BUNDLE_ID is the
 * manual escape hatch.
 */
function resolveBundleId() {
  if (process.env.LT_BUNDLE_ID) {
    return process.env.LT_BUNDLE_ID;
  }

  const caps = driver.capabilities || {};
  const fromCaps =
    caps.bundleID ||
    caps.bundleId ||
    caps["appium:bundleId"] ||
    caps.CFBundleIdentifier;

  return fromCaps || "com.newrelic.NRApp.bitcode";
}

async function appState(bundleId) {
  try {
    return await driver.queryAppState(bundleId);
  } catch (error) {
    // A crashing app can make this call fail transiently; treat it as unknown
    // rather than as a verdict.
    return null;
  }
}

describe("Crash Reporting (real device)", () => {
  it("Should confirm agent logs are visible in the device syslog", async () => {
    state.bundleId = resolveBundleId();
    console.log(`Bundle id under test: ${state.bundleId}`);

    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });

    // Deliberately a separate, earlier assertion than the crash check. If agent
    // console logging is off, the crash assertions would fail with "no upload
    // line found", which reads like a broken crash uploader. Failing here
    // instead names the real cause.
    let sawAgentLog = false;
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      await drainSyslog();
      if (syslogMatching(AGENT_LOG_PREFIX).length > 0) {
        sawAgentLog = true;
        break;
      }
      await driver.pause(POLL_INTERVAL_MS);
    }

    if (!sawAgentLog) {
      throw new Error(
        `No "${AGENT_LOG_PREFIX}" lines in the device syslog after 30s, so the ` +
          "crash-upload assertions below could not distinguish a failed upload " +
          "from silent logging. Most likely cause: agent console logging is " +
          "disabled -- either NRFeatureFlag_AutoCollectLogs got enabled in " +
          "NRTestApp (the harvester then redirects stdout and sets " +
          "NRLogTargetFile only), or the log level no longer includes Verbose. " +
          `Captured ${state.syslog.length} syslog lines total.`
      );
    }

    console.log(
      `✓ Agent console logging is reaching syslog ` +
        `(${syslogMatching(AGENT_LOG_PREFIX).length} agent lines so far)`
    );
  });

  it("Should tap Crash Now! and terminate the app", async () => {
    const utilitiesButton = await $("~Utilities");
    await utilitiesButton.waitForExist({ timeout: 10000 });
    await utilitiesButton.click();

    const crashNow = await $("~Crash Now!");
    await crashNow.waitForExist({ timeout: 10000 });

    // Capture whatever the agent has logged so far BEFORE crashing. After this
    // point no element queries are made -- XCUITest can silently relaunch a dead
    // app to service them, which would muddy the relaunch step below.
    await drainSyslog();
    const linesBeforeCrash = state.syslog.length;

    console.log("Tapping Crash Now! ...");
    try {
      await crashNow.click();
    } catch (error) {
      // The app dying mid-command legitimately fails the click. That is the
      // expected outcome here, not an error.
      console.log(`  click returned an error (expected on crash): ${error.message}`);
    }

    // Verify the app actually died. Without this, a no-op tap would leave the
    // next step asserting against a stale log and potentially passing.
    let died = false;
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const currentState = await appState(state.bundleId);
      if (currentState === APP_STATE_NOT_RUNNING || currentState === APP_STATE_NOT_INSTALLED) {
        died = true;
        break;
      }
      await driver.pause(1000);
    }

    if (!died) {
      throw new Error(
        "App was still running 30s after tapping Crash Now!, so no crash report " +
          "was produced. Check that NRFeatureFlag_CrashReporting is enabled (it " +
          "is on by default) and that no debugger is attached -- the agent " +
          "disables crash reporting under a debugger."
      );
    }

    console.log(
      `✓ App terminated by Crash Now! (${linesBeforeCrash} syslog lines captured pre-crash)`
    );
  });

  it("Should relaunch and upload the pending crash report", async () => {
    // terminateApp first so activateApp is a cold start rather than a resume of
    // a half-dead process. Never reinstall here: that would wipe the pending
    // .crash report off the device before the agent could upload it.
    try {
      await driver.terminateApp(state.bundleId);
    } catch (error) {
      console.log(`  terminateApp skipped: ${error.message}`);
    }

    console.log(`Relaunching ${state.bundleId} ...`);
    await driver.activateApp(state.bundleId);

    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 60000 });
    console.log("✓ App relaunched");

    const foregroundState = await appState(state.bundleId);
    if (foregroundState !== null && foregroundState !== APP_STATE_FOREGROUND) {
      console.log(`  note: app state after relaunch is ${foregroundState}, expected ${APP_STATE_FOREGROUND}`);
    }

    // Poll until the uploader logs its response, or we run out of patience.
    console.log(`Waiting up to ${UPLOAD_TIMEOUT_MS / 1000}s for the crash upload ...`);
    const deadline = Date.now() + UPLOAD_TIMEOUT_MS;
    while (Date.now() < deadline) {
      await drainSyslog();
      if (syslogMatching(UPLOAD_RESPONSE).length > 0) {
        break;
      }
      await driver.pause(POLL_INTERVAL_MS);
    }

    const attempts = syslogMatching(UPLOAD_ATTEMPT);
    const responses = syslogMatching(UPLOAD_RESPONSE);
    const errors = syslogMatching(UPLOAD_ERROR);

    console.log(
      `Crash uploader lines -- attempts: ${attempts.length}, ` +
        `responses: ${responses.length}, errors: ${errors.length}`
    );

    if (attempts.length === 0) {
      throw new Error(
        `The agent never logged "${UPLOAD_ATTEMPT}" within ` +
          `${UPLOAD_TIMEOUT_MS / 1000}s of relaunch, so it found no pending crash ` +
          "report to upload. Either the crash report was not written at crash " +
          "time, or it was removed before this launch (e.g. the app was " +
          `reinstalled). Captured ${state.syslog.length} syslog lines.`
      );
    }

    if (errors.length > 0) {
      throw new Error(
        `The crash upload failed. Agent logged: ${errors.join(" | ")}`
      );
    }

    if (responses.length === 0) {
      throw new Error(
        `The agent logged "${UPLOAD_ATTEMPT}" but no response within ` +
          `${UPLOAD_TIMEOUT_MS / 1000}s. The POST to the crash collector was ` +
          "sent but never completed -- likely a network or collector-address " +
          "problem rather than a crash-reporting one."
      );
    }

    // The logged line is an NSHTTPURLResponse description, which carries the
    // status code. Assert 200 explicitly: the agent also treats 500 as
    // "delete the report", so a 500 would otherwise pass silently as success.
    const statusCodes = responses
      .map((line) => /status code:\s*(\d{3})/i.exec(line))
      .filter(Boolean)
      .map((match) => Number(match[1]));

    if (statusCodes.length === 0) {
      console.log(
        "  note: could not parse a status code out of the response line; " +
          "accepting the upload on the strength of a response with no error. " +
          `Response line(s): ${responses.join(" | ")}`
      );
    } else if (!statusCodes.includes(200)) {
      throw new Error(
        `Crash upload was not accepted: the collector returned ` +
          `${statusCodes.join(", ")} rather than 200. Note the agent deletes the ` +
          "report on 500 as well as 200, and discards it outright on 400/403, so " +
          "a non-200 here means the crash did not land."
      );
    }

    console.log(
      `✓ Crash report uploaded and accepted` +
        (statusCodes.length ? ` (HTTP ${statusCodes.join(", ")})` : "")
    );
  });
});
