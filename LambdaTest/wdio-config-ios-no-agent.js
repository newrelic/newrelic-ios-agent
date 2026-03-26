const dayjs = require("dayjs");

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  return `Build_NRTestApp_NoAgent - iOS:${now}`;
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  // Custom flag for test to detect which config is running
  sessionReplayEnabled: false,
  noAgent: true, // Flag to identify this as no-agent test

  updateJob: true,
  specs: ["./tests/session-replay-performance.test.js"],
  exclude: [],

  maxInstances: 1, // Run sequentially for no-agent baseline
  capabilities: [
    {
      "lt:options": {
        w3c: true,
        platformName: "ios",
        deviceName: "iPhone 15",
        platformVersion: "18",
        // Use separate app ID for no-agent build
        app: process.env.LT_APP_ID_NO_AGENT || process.env.LT_APP_ID || "lt://APP1016024601774553921859953",
        isRealMobile: true,
        build: generateDynamicBuildName(),
        name: "Session Replay Performance - NO AGENT (Pure Baseline) - Real Device",
        network: true,
        devicelog: true,
        visual: true,
      },
    },
  ],

  logLevel: "info",
  coloredLogs: true,
  screenshotPath: "./errorShots/",
  baseUrl: "",
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
    timeout: 600000, // 10 minutes for enhanced test with all phases
  },
};
