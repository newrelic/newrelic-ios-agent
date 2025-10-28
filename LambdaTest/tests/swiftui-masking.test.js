/**
 * SwiftUI Masking Screen Tests
 * Tests the masking permutations in SwiftUI including:
 * - Direct masked/unmasked elements
 * - Parent-child inheritance
 * - Override behaviors
 * - Deep nesting scenarios
 */

describe("SwiftUI Masking Screen", () => {
  it("Should navigate to SwiftUI Masking screen", async () => {
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

    // Verify we're on SwiftUI screen
    const swiftUITitle = await $("~SwiftUI Elements");
    await swiftUITitle.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to Masking screen
    const maskingButton = await $("~Masking");
    await maskingButton.waitForExist({ timeout: 30000 });
    await maskingButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Masking screen
    const maskingTitle = await $("~Masking Permutations");
    await maskingTitle.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);
  });

  it("Should verify direct masked and unmasked elements", async () => {
    // Check for "Masked Text" element
    const maskedText = await $("~Masked Text");
    await maskedText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test parent masked children inherit behavior", async () => {
    // Check section header
    const parentMaskedHeader = await $("~Parent Masked → Children Inherit (no explicit child id)");
    await parentMaskedHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify child labels inherit masking
    const childLabelA = await $("~Child Label A");
    await childLabelA.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    const childLabelB = await $("~Child Label B");
    await childLabelB.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with text field
    const implicitMaskedField = await $('//XCUIElementTypeTextField[@value="Implicit masked inheritance?"]');
    await implicitMaskedField.waitForExist({ timeout: 10000 });
    await implicitMaskedField.click();
    await driver.setTimeouts(1000);

    // Dismiss keyboard
    const maskedText = await $("~Masked Text");
    await maskedText.click();
    await driver.setTimeouts(1000);
  });

  it("Should test parent masked with child override unmasked", async () => {
    // Check section header
    const parentMaskedChildOverride = await $("~Parent Masked → Child Override Unmasked");
    await parentMaskedChildOverride.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify inherited masked label
    const inheritedMaskedLabel = await $("~Inherited Masked Label");
    await inheritedMaskedLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify explicit unmasked override
    const explicitUnmaskedOverride = await $("~Explicit Unmasked Override");
    await explicitUnmaskedOverride.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with child unmasked override text field
    const childUnmaskedField = await $('//XCUIElementTypeTextField[@value="Child unmasked override"]');
    await childUnmaskedField.waitForExist({ timeout: 10000 });
    await childUnmaskedField.click();
    await driver.setTimeouts(1000);

    const maskedText = await $("~Masked Text");
    await maskedText.click();
    await driver.setTimeouts(1000);
  });

  it("Should test parent unmasked with child explicit masked (after scroll)", async () => {
    // Scroll down to see more sections
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Check section header
    const parentUnmaskedChildMasked = await $("~Parent Unmasked → Child Explicit Masked");
    await parentUnmaskedChildMasked.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify child masked explicit
    const childMaskedExplicit = await $("~Child Masked Explicit");
    await childMaskedExplicit.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with masked text field inside unmasked parent
    const maskedInsideUnmasked = await $('//XCUIElementTypeTextField[@value="Masked inside unmasked parent"]');
    await maskedInsideUnmasked.waitForExist({ timeout: 10000 });
    await maskedInsideUnmasked.click();
    await driver.setTimeouts(1000);
    await parentUnmaskedChildMasked.click();
    await driver.setTimeouts(1000);

    // Verify sibling unmasked
    const siblingUnmasked = await $("~Sibling Unmasked (inherits parent)");
    await siblingUnmasked.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should test deep nesting with mixed overrides", async () => {
    // Scroll down more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Check section header
    const deepNesting = await $("~Deep Nesting (Mixed Overrides)");
    await deepNesting.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify level 2 (no id)
    const level2 = await $("~Level 2 (no id)");
    await level2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify level 3 explicit masked
    const level3 = await $("~Level 3 Explicit Masked");
    await level3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Use back button
    const backButton = await $("~SwiftUI Elements");
    await backButton.waitForExist({ timeout: 10000 });
    await backButton.click();
    await driver.setTimeouts(2000);

    // Verify we're back on SwiftUI screen
    const swiftUITitle = await $("~SwiftUI Elements");
    await swiftUITitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should navigate back to MainScreen", async () => {

    await driver.back();

    await driver.setTimeouts(2000);

    await driver.back();

    await driver.setTimeouts(2000);

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // put app in background by tapping home button
    await driver.activateApp('com.apple.Preferences');
    await driver.setTimeouts(5000);

    });
});
