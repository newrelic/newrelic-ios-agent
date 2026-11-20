// WDIO config for the HomeSearch suite on a REAL LambdaTest device.
//
// Sibling of wdio-config-homesearch.js (virtual devices), and of wdio-config-expensestracker-realdevice.js,
// whose real-device choices it copies for the same reasons:
//
//   - isRealMobile: true, and the app is a SIGNED .ipa uploaded by uploadAppToLambdaTest-realDevice.mjs.
//     Its `app` capability is the `lt://APP...` URL that upload returns, not a custom_id: given an id it
//     cannot resolve, the real-device cloud hangs instead of erroring.
//   - maxInstances: 1, because real-device concurrency is scarce. Each spec is still its own session.
//   - longer timeouts, and appiumVersion left to LambdaTest's real-device default.
//
//   LT_APP_ID=lt://APP... npm run test:wdio-homesearch-realdevice
//   LT_DEVICE_NAME="iPhone 16" LT_PLATFORM_VERSION=18 ...   to retarget hardware

const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

const APP_ID_FILE = "last-app-id-homesearch-realdevice";

// The IPA always carries an app token (uploadApp-homesearch-realdevice.yml fails without one), so the agent
// must have started live; 05-profile asserts it. Set here so every worker inherits it.
process.env.HS_EXPECT_MODE = process.env.HS_EXPECT_MODE || "live";

function resolveRunLabel() {
  const label = (process.env.LT_RUN_LABEL || "").trim();
  return label.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 40);
}

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  const label = resolveRunLabel();
  return label
    ? `[${label}] Build_HomeSearch_RealDevice - iOS:${now}`
    : `Build_HomeSearch_RealDevice - iOS:${now}`;
}

// Its own app-id file, so no other app's upload can repoint this run at an app it cannot install.
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
    "No HomeSearch real-device app id. Set LT_APP_ID, or upload an IPA with " +
      "LT_APP_IPA=homesearch-ios.ipa LT_APP_ID_PREFIX=com.newrelic.HomeSearch " +
      `LT_APP_ID_FILE=${APP_ID_FILE} node LambdaTest/uploadAppToLambdaTest-realDevice.mjs`
  );
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  updateJob: true,
  specs: ["./tests-homesearch/*.test.js"],
  exclude: [],

  maxInstances: 1,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        name: "HomeSearch iOS suite - Real Device",
        tags: ["HomeSearch", "real-device", resolveRunLabel()].filter(Boolean),
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

  // iOS 26 exposes each toolbar button twice; take the first match, as wdio-config-ios.js does.
  strictSelectors: false,

  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    timeout: 300000,
  },

  onComplete: function (exitCode, config, capabilities, results) {
    fs.writeFileSync(
      path.join(__dirname, "test-results-homesearch-realdevice.json"),
      JSON.stringify({
        passed: results.passed || 0,
        failed: results.failed || 0,
        finished: results.finished || 0,
      })
    );
  },
};
