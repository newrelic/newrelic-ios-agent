/**
 * SwiftUI Masking Screen Tests
 * Tests the masking permutations in SwiftUI including:
 * - Direct masked/unmasked elements
 * - Parent-child inheritance
 * - Override behaviors
 * - Deep nesting scenarios
 */

describe("SwiftUI Masking Screen", () => {
  it("Should navigate to SwiftUI Masking and test all masking scenarios with text input", async () => {
    // Navigate to SwiftUI screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 10000 });

    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 3000 });
    await swiftUIButton.click();

    // Navigate to Masking screen
    const maskingButton = await $("~Masking");
    await maskingButton.waitForExist({ timeout: 3000 });
    await maskingButton.click();

    // Verify we're on Masking screen
    const maskingTitle = await $("~Masking Permutations");
    await maskingTitle.waitForExist({ timeout: 3000 });

    // Verify direct masked elements
    const maskedText = await $("~Masked Text");
    await maskedText.waitForExist({ timeout: 3000 });

    // Test parent masked children inherit behavior with text input
    const parentMaskedHeader = await $("~Parent Masked → Children Inherit (no explicit child id)");
    await parentMaskedHeader.waitForExist({ timeout: 3000 });

    await $("~Child Label A").waitForExist({ timeout: 3000 });
    await $("~Child Label B").waitForExist({ timeout: 3000 });

    // Enter text in implicit masked field
    const implicitMaskedField = await $('//XCUIElementTypeTextField[@value="Implicit masked inheritance?"]');
    await implicitMaskedField.waitForExist({ timeout: 3000 });
    await implicitMaskedField.click();
    await implicitMaskedField.setValue("Sensitive inherited data 123");
    await maskedText.click(); // Dismiss keyboard

    // Test parent masked with child override unmasked
    const parentMaskedChildOverride = await $("~Parent Masked → Child Override Unmasked");
    await parentMaskedChildOverride.waitForExist({ timeout: 3000 });

    await $("~Inherited Masked Label").waitForExist({ timeout: 3000 });
    await $("~Explicit Unmasked Override").waitForExist({ timeout: 3000 });

    // Enter text in child unmasked override field
    const childUnmaskedField = await $('//XCUIElementTypeTextField[@value="Child unmasked override"]');
    await childUnmaskedField.waitForExist({ timeout: 3000 });
    await childUnmaskedField.click();
    await childUnmaskedField.setValue("Public override text 456");
    await maskedText.click(); // Dismiss keyboard

    // Scroll down to test parent unmasked with child explicit masked
    await driver.execute('mobile: scroll', { direction: 'down' });

    const parentUnmaskedChildMasked = await $("~Parent Unmasked → Child Explicit Masked");
    await parentUnmaskedChildMasked.waitForExist({ timeout: 3000 });

    await $("~Child Masked Explicit").waitForExist({ timeout: 3000 });

    // Enter text in masked field inside unmasked parent
    const maskedInsideUnmasked = await $('//XCUIElementTypeTextField[@value="Masked inside unmasked parent"]');
    await maskedInsideUnmasked.waitForExist({ timeout: 3000 });
    await maskedInsideUnmasked.click();
    await maskedInsideUnmasked.setValue("Secret in public 789");
    await parentUnmaskedChildMasked.click(); // Dismiss keyboard

    await $("~Sibling Unmasked (inherits parent)").waitForExist({ timeout: 3000 });

    // Scroll down to test deep nesting
    await driver.execute('mobile: scroll', { direction: 'down' });

    const deepNesting = await $("~Deep Nesting (Mixed Overrides)");
    await deepNesting.waitForExist({ timeout: 3000 });

    await $("~Level 2 (no id)").waitForExist({ timeout: 3000 });
    await $("~Level 3 Explicit Masked").waitForExist({ timeout: 3000 });
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back twice
    await driver.back();
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 3000 });

    // Put app in background
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(1000);
  });
});
