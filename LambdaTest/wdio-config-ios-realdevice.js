// WDIO config for running the NRTestApp iOS suite on a REAL LambdaTest device.
//
// Sibling of wdio-config-ios.js (which runs the same specs on a VIRTUAL device).
// This config runs those specs plus one real-device-only spec (crash reporting),
// and differs in target and timing characteristics:
//
//   - isRealMobile: true, and the app must be a SIGNED .ipa uploaded via
//     LambdaTest/uploadAppToLambdaTest-realDevice.mjs. A simulator .app zip will
//     not install on hardware.
//   - maxInstances: 1. Real-device concurrency is far scarcer than virtual, so
//     the virtual config's 10 parallel sessions would queue or fail here.
//   - Longer timeouts throughout. Real hardware boots slower, and specs like
//     swiftui-other-components.test.js run a long chain of interactions.
//   - The `app` capability is an `lt://APP...` URL, NOT the custom_id the virtual
//     pipeline uses. Real-device sessions identify builds by that URL; given a
//     custom_id they cannot resolve, LambdaTest hangs rather than erroring and the
//     client aborts with UND_ERR_HEADERS_TIMEOUT after connectionRetryTimeout.
//   - appiumVersion is deliberately NOT pinned, so LambdaTest picks its
//     real-device default instead of inheriting the virtual run's 2.16.2.
//   - one extra spec, tests-realdevice/crash-reporting.test.js, runs last: it taps
//     "Crash Now!", relaunches, and verifies the crash report was uploaded. It is
//     real-device-only because it needs a genuine crash + relaunch cycle.

const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

// Optional label identifying which branch/variant this run came from. CI sets it
// (e.g. LT_RUN_LABEL=mobile-views-2-realdevice) so the run is obvious in the
// LambdaTest automation dashboard.
function resolveRunLabel() {
  const label = (process.env.LT_RUN_LABEL || "").trim();
  // Keep it dashboard-safe: no brackets/pipes that would fight the build-name format.
  return label.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 40);
}

// Unlike the virtual config, the base name always says RealDevice. That way runs
// stay distinguishable in the dashboard even when LT_RUN_LABEL is unset.
function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  const label = resolveRunLabel();

  return label
    ? `[${label}] Build_NRTestApp_RealDevice - iOS:${now}`
    : `Build_NRTestApp_RealDevice - iOS:${now}`;
}

// Tags show up as filterable chips on each automation row in LambdaTest.
function generateTags() {
  const label = resolveRunLabel();
  return label ? [label, "real-device"] : ["real-device"];
}

function resolveAppId() {
  if (process.env.LT_APP_ID) {
    return process.env.LT_APP_ID;
  }

  // Fall back to the custom_id written by uploadAppToLambdaTest-realDevice.mjs.
  // Note this is last-app-id-REALDEVICE, not last-app-id: the latter holds a
  // simulator .app upload that cannot install on hardware.
  try {
    return fs
      .readFileSync(path.join(__dirname, "last-app-id-realdevice"), "utf8")
      .trim();
  } catch (err) {
    return "";
  }
}

const appId = resolveAppId();
if (!appId) {
  // Better to say this now than to let LambdaTest reject an empty `app` with a
  // generic session-creation error.
  throw new Error(
    "No real-device app id. Set LT_APP_ID, or run " +
      "LambdaTest/uploadAppToLambdaTest-realDevice.mjs to create " +
      "LambdaTest/last-app-id-realdevice."
  );
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  updateJob: true,
  // Ordered, NOT a single glob. tests-realdevice/crash-reporting.test.js kills the
  // app under test, so it has to run last; listing it after the glob plus
  // maxInstances: 1 below is what guarantees that. Keeping it outside ./tests also
  // keeps the virtual config's ./tests/*.test.js glob from picking it up.
  specs: ["./tests/*.test.js", "./tests-realdevice/crash-reporting.test.js"],
  exclude: [],

  // Real-device concurrency is limited; run the suite sequentially.
  maxInstances: 1,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        name: "NRTestApp iOS suite - Real Device",
        tags: generateTags(),
        network: true,
        devicelog: true,
        visual: true,
        w3c: true,
        noReset: false,
        platformName: "ios",
        // Overridable so a dispatch can retarget hardware without editing this file.
        deviceName: process.env.LT_DEVICE_NAME || "iPhone 17",
        platformVersion: process.env.LT_PLATFORM_VERSION || "26.0",
        isRealMobile: true,
        app: appId,
        idleTimeout: 300,
      },
    },
  ],

  logLevel: "info",
  coloredLogs: true,
  screenshotPath: "./errorShots/",
  baseUrl: "",
  // Roughly double the virtual config's waits: real hardware is slower to
  // settle, and a marginal wait shows up as a flaky spec rather than a clean fail.
  waitforTimeout: 10000,
  connectionRetryTimeout: 180000,
  connectionRetryCount: 3,
  path: "/wd/hub",
  hostname: "mobile-hub.lambdatest.com",
  port: 443,
  protocol: "https",

  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    timeout: 300000,
  },

  // Writes a pass/fail summary so the CI workflow can report it to Slack. Kept
  // under a distinct filename so it can never clobber the virtual run's results.
  onComplete: function (exitCode, config, capabilities, results) {
    fs.writeFileSync(
      path.join(__dirname, "test-results-realdevice.json"),
      JSON.stringify({
        passed: results.passed || 0,
        failed: results.failed || 0,
        finished: results.finished || 0,
      })
    );
  },
};
