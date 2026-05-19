const dayjs = require("dayjs");
const fs = require("fs");
const path = require("path");

function generateDynamicBuildName() {
  const now = dayjs().format("YYYY-MM-DD_HH-mm");

  // Include PR number in build name if available
  const prNumber = process.env.GITHUB_PR_NUMBER;
  const baseName = prNumber ? `PR-${prNumber}_Build_NRTestApp` : `Build_NRTestApp`;

  return `${baseName} - iOS:${now}`;
}

// Store build name for later use by PR posting script
const buildName = generateDynamicBuildName();
console.log(`Build name: ${buildName}`);

// Save build name to file for PR posting script
const buildNameFile = path.join(__dirname, 'current-build-name');
fs.writeFileSync(buildNameFile, buildName);

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
        build: buildName,
        network: true,
        devicelog: true,
        visual: true,
        video: true, // Ensure video recording is enabled
        w3c: true,
        noReset: false,
        platformName: "ios",
        deviceName: "iPhone 15",
        appiumVersion: "1.22.3",
        platformVersion: "17.0",
        // Use environment variable for custom_id or fallback to static value
        app: process.env.LT_APP_ID || "com.newrelic.NRApp.bitcode",
        idleTimeout: 300,

        // Add tags for better organization
        tags: [
          "iOS",
          "NRTestApp",
          "SessionReplay",
          process.env.GITHUB_PR_NUMBER ? `PR-${process.env.GITHUB_PR_NUMBER}` : "manual-run"
        ].filter(Boolean),

        // Add project name
        project: "NewRelic iOS Agent Tests"
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
    timeout: 60000,
  },

  // Reporters for capturing test results
  reporters: [
    'spec',
    [
      'json',
      {
        outputDir: './test-results',
        outputFileFormat: function(opts) {
          return `results-${opts.cid}.json`;
        }
      }
    ]
  ],

  // Hooks for enhanced test reporting
  onPrepare: function (config, capabilities) {
    console.log('🚀 Starting test execution...');

    // Ensure results directory exists
    const resultsDir = path.join(__dirname, 'test-results');
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }

    // Save test metadata
    const metadata = {
      buildName: buildName,
      startTime: new Date().toISOString(),
      prNumber: process.env.GITHUB_PR_NUMBER,
      appId: process.env.LT_APP_ID,
      capabilities: capabilities[0]
    };

    fs.writeFileSync(
      path.join(resultsDir, 'test-metadata.json'),
      JSON.stringify(metadata, null, 2)
    );
  },

  onComplete: async function (exitCode, config, capabilities, results) {
    console.log('📊 Test execution completed');

    const resultsDir = path.join(__dirname, 'test-results');

    // Aggregate all test results
    const aggregatedResults = {
      buildName: buildName,
      endTime: new Date().toISOString(),
      exitCode: exitCode,
      totalTests: 0,
      totalPassed: 0,
      totalFailed: 0,
      totalSkipped: 0,
      suites: []
    };

    // Read all result files
    try {
      const resultFiles = fs.readdirSync(resultsDir).filter(file => file.startsWith('results-'));

      for (const file of resultFiles) {
        const filePath = path.join(resultsDir, file);
        const result = JSON.parse(fs.readFileSync(filePath, 'utf8'));

        if (result.stats) {
          aggregatedResults.totalTests += result.stats.tests || 0;
          aggregatedResults.totalPassed += result.stats.passes || 0;
          aggregatedResults.totalFailed += result.stats.failures || 0;
          aggregatedResults.totalSkipped += result.stats.pending || 0;
        }

        if (result.suites) {
          aggregatedResults.suites = aggregatedResults.suites.concat(result.suites);
        }
      }

      // Save aggregated results
      fs.writeFileSync(
        path.join(resultsDir, 'aggregated-results.json'),
        JSON.stringify(aggregatedResults, null, 2)
      );

      console.log(`✅ Test Summary: ${aggregatedResults.totalPassed} passed, ${aggregatedResults.totalFailed} failed, ${aggregatedResults.totalSkipped} skipped`);

    } catch (error) {
      console.error('Error aggregating test results:', error);
    }

    // Export build name for PR script
    if (process.env.GITHUB_PR_NUMBER) {
      process.env.BUILD_NAME = buildName;
      console.log(`📤 Build name exported for PR posting: ${buildName}`);
    }
  },

  afterTest: function (test, context, { error, result, duration, passed, retries }) {
    // Log individual test results
    const status = passed ? '✅' : '❌';
    console.log(`${status} ${test.fullTitle} (${Math.round(duration)}ms)`);

    if (error) {
      console.log(`   Error: ${error.message}`);
    }
  },

  beforeSession: function (config, capabilities, specs) {
    console.log(`🔄 Starting session for: ${specs.join(', ')}`);
  },

  afterSession: function (config, capabilities, specs) {
    console.log(`✅ Session completed for: ${specs.join(', ')}`);
  }
};