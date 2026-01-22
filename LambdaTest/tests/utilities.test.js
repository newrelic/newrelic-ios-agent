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
  it("Should navigate to Utilities and test all functionality", async () => {
    // Navigate to Utilities screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    const utilitiesButton = await $("~Utilities");
    await utilitiesButton.waitForExist({ timeout: 5000 });
    await utilitiesButton.click();

    // Verify we're on Utilities screen
    const utilitiesTitle = await $("~Utilities");
    await utilitiesTitle.waitForExist({ timeout: 5000 });

    // Test breadcrumb management functions
    const addValidBreadcrumb = await $("~Add Valid Breadcrumb");
    await addValidBreadcrumb.waitForExist({ timeout: 5000 });
    await addValidBreadcrumb.click();

    const addInvalidBreadcrumb = await $("~Add Invalid Breadcrumb");
    await addInvalidBreadcrumb.waitForExist({ timeout: 5000 });
    await addInvalidBreadcrumb.click();

    // Test attribute management functions
    const setAttributes = await $("~Set Attributes");
    await setAttributes.waitForExist({ timeout: 5000 });
    await setAttributes.click();

    const removeAttributes = await $("~Remove Attributes");
    await removeAttributes.waitForExist({ timeout: 5000 });
    await removeAttributes.click();

    // Test error handling functions (skip Crash Now!)
    const recordError = await $("~Record Error");
    await recordError.waitForExist({ timeout: 5000 });
    await recordError.click();

    const recordHandledException = await $("~Record Handled Exception");
    await recordHandledException.waitForExist({ timeout: 5000 });
    await recordHandledException.click();

    // Test user identification functions
    const setUserIDToTestID = await $("~Set UserID to testID");
    await setUserIDToTestID.waitForExist({ timeout: 5000 });
    await setUserIDToTestID.click();

    const setUserIDToBob = await $("~Set UserID to Bob");
    await setUserIDToBob.waitForExist({ timeout: 5000 });
    await setUserIDToBob.click();

    const setUserIDToNull = await $("~Set UserID to null");
    await setUserIDToNull.waitForExist({ timeout: 5000 });
    await setUserIDToNull.click();

    // Test event generation (may take longer)
    const make100Events = await $("~Make 100 events");
    await make100Events.waitForExist({ timeout: 5000 });
    await make100Events.click();
    await driver.pause(1000);

    // Test interaction trace functions
    const startInteractionTrace = await $("~Start Interaction Trace");
    await startInteractionTrace.waitForExist({ timeout: 5000 });
    await startInteractionTrace.click();

    const endInteractionTrace = await $("~End Interaction Trace");
    await endInteractionTrace.waitForExist({ timeout: 5000 });
    await endInteractionTrace.click();

    // Test network request tracking
    const noticeNetworkRequest = await $("~Notice Network Request");
    await noticeNetworkRequest.waitForExist({ timeout: 5000 });
    await noticeNetworkRequest.click();

    const noticeNetworkFailure = await $("~Notice Network Failure");
    await noticeNetworkFailure.waitForExist({ timeout: 5000 });
    await noticeNetworkFailure.click();

    // Scroll down to access additional utilities
    await driver.execute('mobile: scroll', { direction: 'down' });

    // Test additional logging functions
    const testSystemLogs = await $("~Test System Logs");
    await testSystemLogs.waitForExist({ timeout: 5000 });
    await testSystemLogs.click();

    const noticeNetworkRequestWithParams = await $("~Notice Network Request w headers/params");
    await noticeNetworkRequestWithParams.waitForExist({ timeout: 5000 });
    await noticeNetworkRequestWithParams.click();

    const testLogDict = await $("~Test Log Dict");
    await testLogDict.waitForExist({ timeout: 5000 });
    await testLogDict.click();

    const testLogError = await $("~Test Log Error");
    await testLogError.waitForExist({ timeout: 5000 });
    await testLogError.click();

    const testLogAttributes = await $("~Test Log Attributes");
    await testLogAttributes.waitForExist({ timeout: 5000 });
    await testLogAttributes.click();

    // Test bulk logging operations
    const make100Logs = await $("~Make 100 Logs");
    await make100Logs.waitForExist({ timeout: 5000 });
    await make100Logs.click();
    await driver.pause(1000);

    const make100SpecialCharLogs = await $("~Make 100 Special Character Logs");
    await make100SpecialCharLogs.waitForExist({ timeout: 5000 });
    await make100SpecialCharLogs.click();
    await driver.pause(1000);

    // Test URLSession functionality
    const urlSessionDataTask = await $("~URLSession dataTask");
    await urlSessionDataTask.waitForExist({ timeout: 5000 });
    await urlSessionDataTask.click();
    await driver.pause(1000);

    // Scroll back up and verify Crash Now button exists (don't click)
    await driver.execute('mobile: scroll', { direction: 'up' });
    const crashNow = await $("~Crash Now!");
    await crashNow.waitForExist({ timeout: 5000 });
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 5000 });

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(2000);
  });
});
