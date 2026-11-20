/**
 * Verifies, from the device syslog, that the agent uploaded the crash report a crash spec produced.
 *
 * The same check as tests-realdevice/crash-reporting.test.js does for NRTestApp, and for the same reasons:
 * the agent writes the .crash file at crash time and uploads it on the next launch, logging each step
 * through NSLog. ExpensesTracker meets both preconditions that spec documents — NewRelicConfig sets
 * NRLogLevelDebug, which includes the Verbose upload lines, and it does not enable AutoCollectLogs, which
 * would redirect the agent's console output away from syslog. (LogReporting, which it does enable, keeps
 * the console target.)
 *
 * Turned on by ET_VERIFY_CRASH_UPLOAD=1, which wdio-config-expensestracker-realdevice.js sets.
 */

const UPLOAD_ATTEMPT = "NEWRELIC CRASH UPLOADER - Perform crash upload";
const UPLOAD_RESPONSE = "NEWRELIC CRASH UPLOADER - Crash Upload Response:";
const UPLOAD_ERROR = "NEWRELIC CRASH UPLOADER - Crash Upload Response Error:";
const AGENT_LOG_PREFIX = "NewRelic(";

const UPLOAD_TIMEOUT_MS = 90000;
const POLL_INTERVAL_MS = 3000;

// getLogs drains the buffer, so every line read is kept here: one seen in an early poll must still count.
const syslog = [];

const enabled = () => process.env.ET_VERIFY_CRASH_UPLOAD === "1";

async function drainSyslog() {
  let entries;
  try {
    entries = await driver.getLogs("syslog");
  } catch (error) {
    throw new Error(
      `Could not read the device syslog via getLogs('syslog'): ${error.message}. ` +
        "If LambdaTest does not support it here, this function is the only reader to replace."
    );
  }
  const lines = (entries || [])
    .map((entry) => (typeof entry === "string" ? entry : entry && entry.message))
    .filter((line) => typeof line === "string" && line.length > 0);
  syslog.push(...lines);
  return lines;
}

const matching = (needle) => syslog.filter((line) => line.includes(needle));

/**
 * Run before crashing. Without it, silent agent logging would later read as "the uploader never ran".
 */
async function expectAgentLogsInSyslog(timeout = 30000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    await drainSyslog();
    if (matching(AGENT_LOG_PREFIX).length > 0) return;
    await driver.pause(POLL_INTERVAL_MS);
  }
  throw new Error(
    `No "${AGENT_LOG_PREFIX}" lines in the device syslog after ${timeout / 1000}s, so a missing crash ` +
      "upload could not be told apart from silent logging. Most likely AutoCollectLogs got enabled in " +
      `NewRelicConfig, or the log level no longer includes Verbose. Captured ${syslog.length} lines.`
  );
}

/** Run after the relaunch. Asserts the collector answered 200, as the NRTestApp spec does. */
async function expectCrashUploaded() {
  const deadline = Date.now() + UPLOAD_TIMEOUT_MS;
  while (Date.now() < deadline) {
    await drainSyslog();
    if (matching(UPLOAD_RESPONSE).length > 0) break;
    await driver.pause(POLL_INTERVAL_MS);
  }

  const attempts = matching(UPLOAD_ATTEMPT);
  const responses = matching(UPLOAD_RESPONSE);
  const errors = matching(UPLOAD_ERROR);
  console.log(
    `Crash uploader lines -- attempts: ${attempts.length}, responses: ${responses.length}, errors: ${errors.length}`
  );

  if (attempts.length === 0) {
    throw new Error(
      `The agent never logged "${UPLOAD_ATTEMPT}" within ${UPLOAD_TIMEOUT_MS / 1000}s of relaunch: it found ` +
        "no pending crash report. Either none was written at crash time, or the app was reinstalled first."
    );
  }
  if (errors.length > 0) {
    throw new Error(`The crash upload failed. Agent logged: ${errors.join(" | ")}`);
  }
  if (responses.length === 0) {
    throw new Error(
      `The agent logged "${UPLOAD_ATTEMPT}" but no response within ${UPLOAD_TIMEOUT_MS / 1000}s; the POST ` +
        "to the crash collector never completed."
    );
  }

  // The agent deletes the report on 500 as well as 200, so anything but 200 means the crash did not land.
  const statusCodes = responses
    .map((line) => /status code:\s*(\d{3})/i.exec(line))
    .filter(Boolean)
    .map((match) => Number(match[1]));
  if (statusCodes.length > 0 && !statusCodes.includes(200)) {
    throw new Error(`Crash upload was not accepted: the collector returned ${statusCodes.join(", ")}, not 200.`);
  }
  console.log(`Crash report uploaded${statusCodes.length ? ` (HTTP ${statusCodes.join(", ")})` : ""}`);
}

module.exports = { enabled, expectAgentLogsInSyslog, expectCrashUploaded };
