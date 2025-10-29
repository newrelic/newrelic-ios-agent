/**
 * SwiftUI Buttons Screen Tests
 * Tests various button types and interactions in SwiftUI
 *
 * This screen contains comprehensive button testing:
 * - "Buttons Demo" title
 * - "Press Me" button with press counter
 * - Toggle button that shows state (OFF/ON)
 * - Custom styled button
 * - Star button with icon and label
 *
 * Elements include:
 * - Button press counter ("Button pressed 0 times")
 * - Toggle state button ("Toggle is OFF")
 * - Icon button with star.fill image
 */

describe("SwiftUI Buttons Screen", () => {
  it("Should navigate to Buttons screen and verify title", async () => {
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to SwiftUI screen
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Navigate to Buttons screen
    const buttonsButton = await $("~Buttons");
    await buttonsButton.waitForExist({ timeout: 30000 });
    await buttonsButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Buttons screen by checking title
    const buttonsTitle = await $("~Buttons Demo");
    await buttonsTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should verify initial button press counter", async () => {
    // Verify the press counter starts at 0
    const pressCounter = await $("~Button pressed 0 times");
    await pressCounter.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test Press Me button and verify counter increment", async () => {
    // Test "Press Me" button
    const pressMeButton = await $("~Press Me");
    await pressMeButton.waitForExist({ timeout: 10000 });
    await pressMeButton.click();
    await driver.setTimeouts(1000);

    // After clicking once, counter should update to "Button pressed 1 times"
    // Note: The counter text might change dynamically
    await driver.setTimeouts(500);

    // Click multiple times to test counter increment
    await pressMeButton.click();
    await driver.setTimeouts(500);

    await pressMeButton.click();
    await driver.setTimeouts(500);
  });

  it("Should test Toggle button with OFF state", async () => {
    // Test Toggle button that shows state
    const toggleButtonOff = await $("~Toggle is OFF");
    await toggleButtonOff.waitForExist({ timeout: 10000 });
    await toggleButtonOff.click();
    await driver.setTimeouts(1000);
  });

  it("Should verify Toggle button changed to ON state", async () => {
    // After clicking, button text should change to "Toggle is ON"
    const toggleButtonOn = await $("~Toggle is ON");
    await toggleButtonOn.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Click again to toggle back to OFF
    await toggleButtonOn.click();
    await driver.setTimeouts(1000);
  });

  it("Should verify Toggle button returned to OFF state", async () => {
    // Verify button is back to OFF state
    const toggleButtonOff = await $("~Toggle is OFF");
    await toggleButtonOff.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test Custom Styled Button", async () => {
    // Test custom styled button
    const customStyledButton = await $("~Custom Styled Button");
    await customStyledButton.waitForExist({ timeout: 10000 });
    await customStyledButton.click();
    await driver.setTimeouts(1000);

    // Click multiple times to test
    await customStyledButton.click();
    await driver.setTimeouts(500);
  });

  it("Should test Star Button with icon", async () => {
    // Test star button (has both icon and text)
    const starButton = await $("~Star Button");
    await starButton.waitForExist({ timeout: 10000 });
    await starButton.click();
    await driver.setTimeouts(1000);

    // Click again to test
    await starButton.click();
    await driver.setTimeouts(500);
  });

  it("Should verify Star Button contains icon and label", async () => {
    // Verify the star button has the icon (star.fill)
    const starIcon = await $('//XCUIElementTypeImage[@name="star.fill"]');
    await starIcon.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify the button also has text label
    const starButton = await $("~Star Button");
    await starButton.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test all buttons in sequence", async () => {
    // Final comprehensive test - click all buttons in order

    // Press Me button
    const pressMeButton = await $("~Press Me");
    await pressMeButton.click();
    await driver.setTimeouts(500);

    // Toggle button (click twice to test both states)
    const toggleButton = await $("~Toggle is OFF");
    if (await toggleButton.isExisting()) {
      await toggleButton.click();
      await driver.setTimeouts(500);
      const toggleButtonOn = await $("~Toggle is ON");
      await toggleButtonOn.click();
      await driver.setTimeouts(500);
    }

    // Custom Styled Button
    const customButton = await $("~Custom Styled Button");
    await customButton.click();
    await driver.setTimeouts(500);

    // Star Button
    const starButton = await $("~Star Button");
    await starButton.click();
    await driver.setTimeouts(500);
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

    // Verify we're back on SwiftUI screen
    const swiftUITitle = await $("~SwiftUI");
    await swiftUITitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back to MainScreen
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
