const dayjs = require("dayjs");

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");

  return `Build_NRTestApp - iOS:${now}`;
}

generateDynamicBuildName(); // Call the function to ensure it runs and logs the output

exports.config = {
  user: process.env.LT_USERNAME || "YOUR_USERNAME",
  key: process.env.LT_ACCESSKEY || "YOUR_ACCESS_KEY",

  updateJob: false,
  specs: ["./test-ios.js"],
  exclude: [],

  maxInstances: 10,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        network: false,
        devicelog: true,
        visual: true,
        w3c: true,
        platformName: "ios",
        deviceName: "iPhone 15",
        appiumVersion: "1.22.3",
        platformVersion: "17.0",
        app: "NRTESTAPP", // custom_id was IOSAPP
      },
    },
  ],

  logLevel: "info",
  coloredLogs: true,
  screenshotPath: "./errorShots/",
  baseUrl: "",
  waitforTimeout: 10000,
  connectionRetryTimeout: 90000,
  connectionRetryCount: 3,
  path: "/wd/hub",
  hostname: "mobile-hub.lambdatest.com",
  port: 443,
  protocol: "https",

  framework: "mocha",
  mochaOpts: {
    ui: "bdd",
    timeout: 100000,
  },
};
  