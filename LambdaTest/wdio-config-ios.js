const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

// Optional label identifying which branch/variant this run came from. CI sets it
// (e.g. LT_RUN_LABEL=mobile-views-2) so the run is obvious in the LambdaTest
// automation dashboard. Unset => build names stay exactly as they were.
function resolveRunLabel() {
  const label = (process.env.LT_RUN_LABEL || "").trim();
  // Keep it dashboard-safe: no brackets/pipes that would fight the build-name format.
  return label.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 40);
}

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  const label = resolveRunLabel();

  return label
    ? `[${label}] Build_NRTestApp - iOS:${now}`
    : `Build_NRTestApp - iOS:${now}`;
}

// Tags show up as filterable chips on each automation row in LambdaTest.
function generateTags() {
  const label = resolveRunLabel();
  return label ? [label] : [];
}

function resolveAppId() {
  if (process.env.LT_APP_ID) {
    return process.env.LT_APP_ID;
  }

  // Fall back to the custom_id written by uploadAppToLambdaTest.mjs so a
  // forgotten `export LT_APP_ID=...` doesn't silently run against a stale app_id.
  try {
    return fs.readFileSync(path.join(__dirname, "last-app-id"), "utf8").trim();
  } catch (err) {
    return "com.newrelic.NRApp.bitcode";
  }
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  updateJob: true,
  specs: ["./tests/*.test.js"],
  exclude: [],

  // Enable parallel execution with 10 instances
  maxInstances: 10,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        tags: generateTags(),
        network: true,
        devicelog: true,
        visual: true,
        w3c: true,
        noReset: false,
        platformName: "ios",
        deviceName: "iPhone 17",
        isRealMobile: false,
        appiumVersion: "2.16.2",
        platformVersion: "26.0",
        // Use environment variable for custom_id, falling back to the last uploaded app_id
        app: resolveAppId(),
        idleTimeout: 300, // Reduced idle timeout
      },
    },
  ],

  logLevel: "info", // Reduced logging for performance
  coloredLogs: true,
  screenshotPath: "./errorShots/",
  baseUrl: "",
  waitforTimeout: 5000, // Reduced from 10000ms to 5000ms
  connectionRetryTimeout: 60000, // Reduced from 90000ms
  connectionRetryCount: 2, // Reduced from 3
  path: "/wd/hub",
  hostname: "mobile-hub.lambdatest.com",
  port: 443,
  protocol: "https",

  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    timeout: 60000, // Reduced from 100000ms to 60000ms
  },

  // Writes a pass/fail summary so the CI workflow can report it to Slack
  onComplete: function (exitCode, config, capabilities, results) {
    fs.writeFileSync(
      path.join(__dirname, "test-results.json"),
      JSON.stringify({
        passed: results.passed || 0,
        failed: results.failed || 0,
        finished: results.finished || 0,
      })
    );
  },
};
  