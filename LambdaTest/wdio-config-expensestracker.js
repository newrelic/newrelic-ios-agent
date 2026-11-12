// WDIO config for the ExpensesTracker suite (tests-expensestracker/). Shares wdio-config-ios.js's
// LambdaTest connection settings and result reporting; differs in the specs, the app, and the build name.
//
// On LambdaTest (what CI runs):
//   LT_APP_ID=com.newrelic.ExpensesTracker.<timestamp> npm run test:wdio-expensestracker
//
// Against a local simulator, through a local Appium server with the xcuitest driver installed:
//   npx appium &
//   ET_LOCAL_APP="/path/to/Release-iphonesimulator/ExpensesTracker.app" npm run test:wdio-expensestracker
// ET_LOCAL_UDID picks the simulator; without it Appium chooses one matching ET_LOCAL_DEVICE/ET_LOCAL_OS.

const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

const base = require("./wdio-config-ios").config;

const APP_ID_PREFIX = "com.newrelic.ExpensesTracker";

function resolveRunLabel() {
  const label = (process.env.LT_RUN_LABEL || "").trim();
  return label.replace(/[^A-Za-z0-9._-]/g, "-").slice(0, 40);
}

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  const label = resolveRunLabel();
  return label
    ? `[${label}] Build_ExpensesTracker - iOS:${now}`
    : `Build_ExpensesTracker - iOS:${now}`;
}

// Unlike wdio-config-ios.js there is no hard-coded fallback: LambdaTest/last-app-id is shared with the
// NRTestApp upload, so it is only trusted when it names an ExpensesTracker upload.
function resolveAppId() {
  if (process.env.LT_APP_ID) {
    return process.env.LT_APP_ID;
  }
  try {
    const lastAppId = fs.readFileSync(path.join(__dirname, "last-app-id"), "utf8").trim();
    if (lastAppId.startsWith(`${APP_ID_PREFIX}.`)) {
      return lastAppId;
    }
  } catch (err) {
    // fall through
  }
  throw new Error(
    "No ExpensesTracker app to test: set LT_APP_ID to the custom_id from uploadApp-expensestracker.yml"
  );
}

const shared = {
  ...base,
  specs: ["./tests-expensestracker/*.test.js"],
  exclude: [],
  // The test menu's slow requests and the hangs make for long specs; each sets its own timeout where it
  // needs more than this.
  mochaOpts: { ...base.mochaOpts, timeout: 120000 },
  waitforTimeout: 10000,
};

const lambdaTest = {
  ...shared,
  capabilities: [
    {
      "lt:options": {
        ...base.capabilities[0]["lt:options"],
        build: generateDynamicBuildName(),
        tags: ["ExpensesTracker", resolveRunLabel()].filter(Boolean),
        app: process.env.ET_LOCAL_APP ? undefined : resolveAppId(),
      },
    },
  ],
};

const local = {
  ...shared,
  user: undefined,
  key: undefined,
  hostname: "127.0.0.1",
  port: Number(process.env.APPIUM_PORT || 4723),
  path: "/",
  protocol: "http",
  // One simulator, so one session at a time.
  maxInstances: 1,
  // The first local session builds WebDriverAgent, which takes minutes.
  connectionRetryTimeout: 600000,
  connectionRetryCount: 1,
  capabilities: [
    {
      platformName: "iOS",
      "appium:automationName": "XCUITest",
      "appium:app": process.env.ET_LOCAL_APP,
      "appium:udid": process.env.ET_LOCAL_UDID,
      "appium:deviceName": process.env.ET_LOCAL_DEVICE || "iPhone 17",
      "appium:platformVersion": process.env.ET_LOCAL_OS,
      "appium:noReset": false,
      "appium:fullReset": false,
      "appium:newCommandTimeout": 300,
      "appium:wdaLaunchTimeout": 300000,
      // Point at a WebDriverAgent already built with `xcodebuild build-for-testing` to skip rebuilding it.
      ...(process.env.ET_LOCAL_WDA_DERIVED_DATA && {
        "appium:derivedDataPath": process.env.ET_LOCAL_WDA_DERIVED_DATA,
        "appium:usePrebuiltWDA": true,
      }),
    },
  ],
};

exports.config = process.env.ET_LOCAL_APP ? local : lambdaTest;
