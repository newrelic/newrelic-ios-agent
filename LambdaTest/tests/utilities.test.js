/**
 * Utilities Screen Tests
 * Tests the Utilities screen functionality
 */

describe("Utilities Screen", () => {
  it("Should navigate to Utilities screen", async () => {
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

    // Verify we're on Utilities screen (add appropriate verification)
    // TODO: Add specific element verification for Utilities screen
    await driver.setTimeouts(2000);
  });

  it("Should interact with Utilities screen elements", async () => {
    // TODO: Add specific interactions based on Utilities screen XML layout
    // This is a placeholder - needs to be filled with actual utility functions
    await driver.setTimeouts(2000);
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    await driver.activateApp('com.apple.Preferences');

            await driver.setTimeouts(5000);

  });
});
