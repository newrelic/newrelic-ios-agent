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
  it("Should navigate to Buttons screen and verify all button functionality", async () => {
    // Navigate to SwiftUI screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 5000 });
    await swiftUIButton.click();

    // Navigate to Buttons screen
    const buttonsButton = await $("~Buttons");
    await buttonsButton.waitForExist({ timeout: 5000 });
    await buttonsButton.click();

    // Verify we're on Buttons screen
    const buttonsTitle = await $("~Buttons Demo");
    await buttonsTitle.waitForExist({ timeout: 5000 });

    // Verify initial button press counter
    const pressCounter = await $("~Button pressed 0 times");
    await pressCounter.waitForExist({ timeout: 5000 });

    // Test "Press Me" button - click 3 times
    const pressMeButton = await $("~Press Me");
    await pressMeButton.waitForExist({ timeout: 5000 });
    await pressMeButton.click();
    await pressMeButton.click();
    await pressMeButton.click();

    // Test Toggle button - verify both states
    const toggleButtonOff = await $("~Toggle is OFF");
    await toggleButtonOff.waitForExist({ timeout: 5000 });
    await toggleButtonOff.click();

    const toggleButtonOn = await $("~Toggle is ON");
    await toggleButtonOn.waitForExist({ timeout: 5000 });
    await toggleButtonOn.click();

    const toggleButtonOffAgain = await $("~Toggle is OFF");
    await toggleButtonOffAgain.waitForExist({ timeout: 5000 });

    // Test Custom Styled Button
    const customStyledButton = await $("~Custom Styled Button");
    await customStyledButton.waitForExist({ timeout: 5000 });
    await customStyledButton.click();
    await customStyledButton.click();

    // Test Star Button with icon
    const starButton = await $("~Star Button");
    await starButton.waitForExist({ timeout: 5000 });
    await starButton.click();
    await starButton.click();

    // Verify Star Button has icon
    const starIcon = await $('//XCUIElementTypeImage[@name="star.fill"]');
    await starIcon.waitForExist({ timeout: 5000 });
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back twice
    await driver.back();
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 5000 });

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(2000);
  });
});
