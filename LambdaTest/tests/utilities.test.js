/**
 * Utilities Screen Tests
 * Tests the New Relic SDK utilities and testing functions
 *
 * This screen contains various utility functions for testing New Relic functionality:
 * - Breadcrumb management (valid/invalid)
 * - Attribute management (set/remove)
 * - Error handling (crash, record error, handled exceptions)
 * - User identification (set UserID)
 * - Event generation
 * - Interaction tracing
 * - Network request tracking
 * - Logging capabilities
 * - URLSession testing
 * - Agent shutdown
 */

describe("Utilities Screen", () => {
  it("Should navigate to Utilities screen and verify title", async () => {
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to Utilities screen
    const utilitiesButton = await $("~Utilities");
    await utilitiesButton.waitForExist({ timeout: 30000 });
    await utilitiesButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Utilities screen by checking navigation bar title
    const utilitiesTitle = await $("~Utilities");
    await utilitiesTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test breadcrumb management functions", async () => {
    // Test Add Valid Breadcrumb
    const addValidBreadcrumb = await $("~Add Valid Breadcrumb");
    await addValidBreadcrumb.waitForExist({ timeout: 10000 });
    await addValidBreadcrumb.click();
    await driver.setTimeouts(1000);

    // Test Add Invalid Breadcrumb
    const addInvalidBreadcrumb = await $("~Add Invalid Breadcrumb");
    await addInvalidBreadcrumb.waitForExist({ timeout: 10000 });
    await addInvalidBreadcrumb.click();
    await driver.setTimeouts(1000);
  });

  it("Should test attribute management functions", async () => {
    // Test Set Attributes
    const setAttributes = await $("~Set Attributes");
    await setAttributes.waitForExist({ timeout: 10000 });
    await setAttributes.click();
    await driver.setTimeouts(1000);

    // Test Remove Attributes
    const removeAttributes = await $("~Remove Attributes");
    await removeAttributes.waitForExist({ timeout: 10000 });
    await removeAttributes.click();
    await driver.setTimeouts(1000);
  });

  it("Should test error handling functions", async () => {
    // Note: Skip "Crash Now!" as it will crash the app
    // const crashNow = await $("~Crash Now!");
    // await crashNow.waitForExist({ timeout: 10000 });
    // Skipping click to avoid crashing the test

    // Test Record Error
    const recordError = await $("~Record Error");
    await recordError.waitForExist({ timeout: 10000 });
    await recordError.click();
    await driver.setTimeouts(1000);

    // Test Record Handled Exception
    const recordHandledException = await $("~Record Handled Exception");
    await recordHandledException.waitForExist({ timeout: 10000 });
    await recordHandledException.click();
    await driver.setTimeouts(1000);
  });

  it("Should test user identification functions", async () => {
    // Test Set UserID to testID
    const setUserIDToTestID = await $("~Set UserID to testID");
    await setUserIDToTestID.waitForExist({ timeout: 10000 });
    await setUserIDToTestID.click();
    await driver.setTimeouts(1000);

    // Test Set UserID to Bob
    const setUserIDToBob = await $("~Set UserID to Bob");
    await setUserIDToBob.waitForExist({ timeout: 10000 });
    await setUserIDToBob.click();
    await driver.setTimeouts(1000);

    // Test Set UserID to null
    const setUserIDToNull = await $("~Set UserID to null");
    await setUserIDToNull.waitForExist({ timeout: 10000 });
    await setUserIDToNull.click();
    await driver.setTimeouts(1000);
  });

  it("Should test event generation", async () => {
    // Test Make 100 events
    const make100Events = await $("~Make 100 events");
    await make100Events.waitForExist({ timeout: 10000 });
    await make100Events.click();
    await driver.setTimeouts(2000); // Give more time for 100 events
  });

  it("Should test interaction trace functions", async () => {
    // Test Start Interaction Trace
    const startInteractionTrace = await $("~Start Interaction Trace");
    await startInteractionTrace.waitForExist({ timeout: 10000 });
    await startInteractionTrace.click();
    await driver.setTimeouts(1000);

    // Test End Interaction Trace
    const endInteractionTrace = await $("~End Interaction Trace");
    await endInteractionTrace.waitForExist({ timeout: 10000 });
    await endInteractionTrace.click();
    await driver.setTimeouts(1000);
  });

  it("Should test network request tracking", async () => {
    // Test Notice Network Request
    const noticeNetworkRequest = await $("~Notice Network Request");
    await noticeNetworkRequest.waitForExist({ timeout: 10000 });
    await noticeNetworkRequest.click();
    await driver.setTimeouts(1000);

    // Test Notice Network Failure
    const noticeNetworkFailure = await $("~Notice Network Failure");
    await noticeNetworkFailure.waitForExist({ timeout: 10000 });
    await noticeNetworkFailure.click();
    await driver.setTimeouts(1000);
  });

  it("Should scroll down and test additional logging functions", async () => {
    // Scroll down to access remaining utilities
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Test System Logs
    const testSystemLogs = await $("~Test System Logs");
    await testSystemLogs.waitForExist({ timeout: 10000 });
    await testSystemLogs.click();
    await driver.setTimeouts(1000);

    // Test Notice Network Request w headers/params
    const noticeNetworkRequestWithParams = await $("~Notice Network Request w headers/params");
    await noticeNetworkRequestWithParams.waitForExist({ timeout: 10000 });
    await noticeNetworkRequestWithParams.click();
    await driver.setTimeouts(1000);

    // Test Log Dict
    const testLogDict = await $("~Test Log Dict");
    await testLogDict.waitForExist({ timeout: 10000 });
    await testLogDict.click();
    await driver.setTimeouts(1000);

    // Test Log Error
    const testLogError = await $("~Test Log Error");
    await testLogError.waitForExist({ timeout: 10000 });
    await testLogError.click();
    await driver.setTimeouts(1000);

    // Test Log Attributes
    const testLogAttributes = await $("~Test Log Attributes");
    await testLogAttributes.waitForExist({ timeout: 10000 });
    await testLogAttributes.click();
    await driver.setTimeouts(1000);
  });

  it("Should test bulk logging operations", async () => {
    // Test Make 100 Logs
    const make100Logs = await $("~Make 100 Logs");
    await make100Logs.waitForExist({ timeout: 10000 });
    await make100Logs.click();
    await driver.setTimeouts(2000); // Give more time for 100 logs

    // Test Make 100 Special Character Logs
    const make100SpecialCharLogs = await $("~Make 100 Special Character Logs");
    await make100SpecialCharLogs.waitForExist({ timeout: 10000 });
    await make100SpecialCharLogs.click();
    await driver.setTimeouts(2000); // Give more time for 100 logs
  });

  it("Should test URLSession functionality", async () => {
    // Test URLSession dataTask
    const urlSessionDataTask = await $("~URLSession dataTask");
    await urlSessionDataTask.waitForExist({ timeout: 10000 });
    await urlSessionDataTask.click();
    await driver.setTimeouts(2000); // Give time for network request
  });

  it("Should verify Crash Now button exists (but not click it)", async () => {
    // Scroll back up to find Crash Now button
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    // Verify Crash Now button exists but don't click it
    const crashNow = await $("~Crash Now!");
    await crashNow.waitForExist({ timeout: 10000 });
    // Not clicking - just verifying it exists
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back using back button
    // Navigate back
    await driver.back();

    await driver.setTimeouts(2000);

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.setTimeouts(5000);
  });
});
