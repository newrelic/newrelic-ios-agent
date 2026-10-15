// WDIO config for the ExpensesTracker suite on a REAL LambdaTest device.
//
// Sibling of wdio-config-expensestracker.js (virtual devices), and of wdio-config-ios-realdevice.js, whose
// real-device choices it copies for the same reasons:
//
//   - isRealMobile: true, and the app is a SIGNED .ipa uploaded by uploadAppToLambdaTest-realDevice.mjs.
//     Its `app` capability is the `lt://APP...` URL that upload returns, not a custom_id: given an id it
//     cannot resolve, the real-device cloud hangs instead of erroring.
//   - maxInstances: 1, because real-device concurrency is scarce. The specs are separate sessions either
//     way, so the crash and hang specs still cannot take the others down.
//   - longer timeouts, and appiumVersion left to LambdaTest's real-device default.
//
// What it adds over the virtual run: ET_VERIFY_CRASH_UPLOAD=1, which makes 06-crash and 07-unique-crash
// assert from the device syslog that the agent uploaded each crash report and the collector answered 200
// (tests-expensestracker/crash-upload.js).
//
//   LT_APP_ID=lt://APP... npm run test:wdio-expensestracker-realdevice
//   LT_DEVICE_NAME="iPhone 16" LT_PLATFORM_VERSION=18 ...   to retarget hardware

const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

// Set here so every worker inherits it; the crash specs read it.
process.env.ET_VERIFY_CRASH_UPLOAD = "1";

const APP_ID_FILE = "last-app-id-expensestracker-realdevice";

function resolveRunLabel() {
  const label = (process.env.LT_RUN_LABEL || "").trim();
  return label.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 40);
}

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  const label = resolveRunLabel();
  return label
    ? `[${label}] Build_ExpensesTracker_RealDevice - iOS:${now}`
    : `Build_ExpensesTracker_RealDevice - iOS:${now}`;
}

// Its own app-id file, so neither NRTestApp's real-device upload nor the virtual ExpensesTracker upload can
// repoint this run at an app it cannot install.
function resolveAppId() {
  if (process.env.LT_APP_ID) {
    return process.env.LT_APP_ID;
  }
  try {
    return fs.readFileSync(path.join(__dirname, APP_ID_FILE), "utf8").trim();
  } catch (err) {
    return "";
  }
}

const appId = resolveAppId();
if (!appId) {
  throw new Error(
    "No ExpensesTracker real-device app id. Set LT_APP_ID, or upload an IPA with " +
      "LT_APP_IPA=expensestracker-ios.ipa LT_APP_ID_PREFIX=com.newrelic.ExpensesTracker " +
      `LT_APP_ID_FILE=${APP_ID_FILE} node LambdaTest/uploadAppToLambdaTest-realDevice.mjs`
  );
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  updateJob: true,
  specs: ["./tests-expensestracker/*.test.js"],
  exclude: [],

  maxInstances: 1,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        name: "ExpensesTracker iOS suite - Real Device",
        tags: ["ExpensesTracker", "real-device", resolveRunLabel()].filter(Boolean),
        network: true,
        devicelog: true,
        visual: true,
        w3c: true,
        noReset: false,
        platformName: "ios",
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
  waitforTimeout: 15000,
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

  onComplete: function (exitCode, config, capabilities, results) {
    fs.writeFileSync(
      path.join(__dirname, "test-results-expensestracker-realdevice.json"),
      JSON.stringify({
        passed: results.passed || 0,
        failed: results.failed || 0,
        finished: results.finished || 0,
      })
    );
  },
};
