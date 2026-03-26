const dayjs = require("dayjs");

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");
  return `Build_NRTestApp_SessionReplay - iOS:${now}`;
}

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  // Custom flag for test to detect which config is running
  sessionReplayEnabled: true,

  updateJob: true,
  specs: ["./tests/session-replay-performance.test.js"],
  exclude: [],

  maxInstances: 1, // Run sequentially for Session Replay test
  capabilities: [
    {
      "lt:options": {
        w3c: true,
        platformName: "ios",
        deviceName: "iPhone 15",
        platformVersion: "18",
        app: process.env.LT_APP_ID || "lt://APP10160242221774476886370139",
        isRealMobile: true,
        build: generateDynamicBuildName(),
        name: "Session Replay Performance - WITH SESSION REPLAY (Session Replay ON) - Real Device",
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
  waitforTimeout: 5000,
  connectionRetryTimeout: 60000,
  connectionRetryCount: 2,
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
