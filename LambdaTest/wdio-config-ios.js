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
  specs: ["./tests/*.test.js"],
  exclude: [],

  // Enable parallel execution with 10 instances
  maxInstances: 10,
  capabilities: [
    {
      "lt:options": {
        build: generateDynamicBuildName(),
        network: true,
        devicelog: true,
        visual: true,
        w3c: true,
        platformName: "ios",
        deviceName: "iPhone 15",
        appiumVersion: "1.22.3",
        platformVersion: "17.0",
        app: "com.newrelic.NRApp.bitcode", // custom_id was IOSAPP
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

  /**
   * Gets executed before test execution begins. At this point you can access to all global
   * variables like `browser`. It is the perfect place to uninstall and reinstall the app.
   */
  before: async function () {
    const bundleId = "com.newrelic.NRApp.bitcode";
    const appId = "com.newrelic.NRApp.bitcode"; // LambdaTest app ID

    try {
      console.log(`Attempting to uninstall app with bundle ID: ${bundleId}`);
      await driver.removeApp(bundleId);
      console.log(`✓ Successfully uninstalled app: ${bundleId}`);
    } catch (error) {
      console.log(`Note: App may not have been installed previously: ${error.message}`);
    }

    // Small pause to ensure cleanup is complete
    await driver.pause(1000);
  },
};
  