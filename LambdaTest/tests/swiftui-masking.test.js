/**
 * SwiftUI Masking Screen Tests
 * Tests the masking permutations in SwiftUI including:
 * - Direct masked/unmasked elements
 * - Parent-child inheritance
 * - Override behaviors
 * - Deep nesting scenarios
 */

describe("SwiftUI Masking Screen", () => {
  it("Should navigate to SwiftUI Masking and test all masking scenarios", async () => {
    // Navigate to SwiftUI screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 5000 });
    await swiftUIButton.click();

    // Verify SwiftUI screen
    const swiftUITitle = await $("~SwiftUI Elements");
    await swiftUITitle.waitForExist({ timeout: 5000 });

    // Navigate to Masking screen
    const maskingButton = await $("~Masking");
    await maskingButton.waitForExist({ timeout: 5000 });
    await maskingButton.click();

    // Verify we're on Masking screen
    const maskingTitle = await $("~Masking Permutations");
    await maskingTitle.waitForExist({ timeout: 5000 });

    // Verify direct masked and unmasked elements
    const maskedText = await $("~Masked Text");
    await maskedText.waitForExist({ timeout: 5000 });

    // Test parent masked children inherit behavior
    const parentMaskedHeader = await $("~Parent Masked → Children Inherit (no explicit child id)");
    await parentMaskedHeader.waitForExist({ timeout: 5000 });

    const childLabelA = await $("~Child Label A");
    await childLabelA.waitForExist({ timeout: 5000 });

    const childLabelB = await $("~Child Label B");
    await childLabelB.waitForExist({ timeout: 5000 });

    // Interact with text field
    const implicitMaskedField = await $('//XCUIElementTypeTextField[@value="Implicit masked inheritance?"]');
    await implicitMaskedField.waitForExist({ timeout: 5000 });
    await implicitMaskedField.click();

    // Dismiss keyboard
    await maskedText.click();

    // Test parent masked with child override unmasked
    const parentMaskedChildOverride = await $("~Parent Masked → Child Override Unmasked");
    await parentMaskedChildOverride.waitForExist({ timeout: 5000 });

    const inheritedMaskedLabel = await $("~Inherited Masked Label");
    await inheritedMaskedLabel.waitForExist({ timeout: 5000 });

    const explicitUnmaskedOverride = await $("~Explicit Unmasked Override");
    await explicitUnmaskedOverride.waitForExist({ timeout: 5000 });

    const childUnmaskedField = await $('//XCUIElementTypeTextField[@value="Child unmasked override"]');
    await childUnmaskedField.waitForExist({ timeout: 5000 });
    await childUnmaskedField.click();
    await maskedText.click();

    // Scroll down to see more sections
    await driver.execute('mobile: scroll', { direction: 'down' });

    // Test parent unmasked with child explicit masked
    const parentUnmaskedChildMasked = await $("~Parent Unmasked → Child Explicit Masked");
    await parentUnmaskedChildMasked.waitForExist({ timeout: 5000 });

    const childMaskedExplicit = await $("~Child Masked Explicit");
    await childMaskedExplicit.waitForExist({ timeout: 5000 });

    const maskedInsideUnmasked = await $('//XCUIElementTypeTextField[@value="Masked inside unmasked parent"]');
    await maskedInsideUnmasked.waitForExist({ timeout: 5000 });
    await maskedInsideUnmasked.click();
    await parentUnmaskedChildMasked.click();

    const siblingUnmasked = await $("~Sibling Unmasked (inherits parent)");
    await siblingUnmasked.waitForExist({ timeout: 5000 });

    // Scroll down to test deep nesting
    await driver.execute('mobile: scroll', { direction: 'down' });

    const deepNesting = await $("~Deep Nesting (Mixed Overrides)");
    await deepNesting.waitForExist({ timeout: 5000 });

    const level2 = await $("~Level 2 (no id)");
    await level2.waitForExist({ timeout: 5000 });

    const level3 = await $("~Level 3 Explicit Masked");
    await level3.waitForExist({ timeout: 5000 });

    // Navigate back using back button
    const backButton = await $("~SwiftUI Elements");
    await backButton.waitForExist({ timeout: 5000 });
    await backButton.click();

    // Verify we're back on SwiftUI screen
    await swiftUITitle.waitForExist({ timeout: 5000 });
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back twice
    await driver.back();
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 5000 });

    // Put app in background
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(2000);
  });
});
