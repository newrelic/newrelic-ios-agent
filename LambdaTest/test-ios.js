describe("Run NRTestApp - ios", () => {
  it("Navigates MainScreen -> SwiftUI -> Masking and interacts with elements", async () => {
    // ==== MAIN SCREEN ====
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for "Hello, World" public text to be seen (MainScreen)
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Verify we're on MainScreen by checking for the private "Secret Hello, World!" text
    const secretText = await $("~private");
    await secretText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // ==== NAVIGATE TO SWIFTUI SCREEN ====
    // Navigate to SwiftUI screen by clicking the "SwiftUI" cell
    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 30000 });
    await swiftUIButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on SwiftUI screen by checking the navigation bar title
    const swiftUITitle = await $("~SwiftUI Elements");
    await swiftUITitle.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // ==== NAVIGATE TO MASKING SCREEN ====
    // Navigate to Masking screen by clicking the "Masking" button
    const maskingButton = await $("~Masking");
    await maskingButton.waitForExist({ timeout: 30000 });
    await maskingButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Masking screen by checking the navigation bar title
    const maskingTitle = await $("~Masking Permutations");
    await maskingTitle.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // ==== INTERACT WITH MASKING SCREEN ELEMENTS ====
    // Section 1: Direct Elements (Single Controls)
    // Check for "Masked Text" element (visible in the initial view)
    const maskedText = await $("~Masked Text");
    await maskedText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Section 2: Parent Masked → Children Inherit
    const parentMaskedHeader = await $("~Parent Masked → Children Inherit (no explicit child id)");
    await parentMaskedHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for Child Label A
    const childLabelA = await $("~Child Label A");
    await childLabelA.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for Child Label B
    const childLabelB = await $("~Child Label B");
    await childLabelB.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with the text field "Implicit masked inheritance?"
    const implicitMaskedField = await $('//XCUIElementTypeTextField[@value="Implicit masked inheritance?"]');
    await implicitMaskedField.waitForExist({ timeout: 10000 });
    await implicitMaskedField.click();
    await driver.setTimeouts(1000);
    // Tap on another element to dismiss keyboard
    await maskedText.click();
    await driver.setTimeouts(1000);

    // Section 3: Parent Masked → Child Override Unmasked
    const parentMaskedChildOverride = await $("~Parent Masked → Child Override Unmasked");
    await parentMaskedChildOverride.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for "Inherited Masked Label"
    const inheritedMaskedLabel = await $("~Inherited Masked Label");
    await inheritedMaskedLabel.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for "Explicit Unmasked Override"
    const explicitUnmaskedOverride = await $("~Explicit Unmasked Override");
    await explicitUnmaskedOverride.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with "Child unmasked override" text field
    const childUnmaskedField = await $('//XCUIElementTypeTextField[@value="Child unmasked override"]');
    await childUnmaskedField.waitForExist({ timeout: 10000 });
    await childUnmaskedField.click();
    await driver.setTimeouts(1000);
    await maskedText.click();
    await driver.setTimeouts(1000);

    // ==== SCROLL DOWN TO SEE MORE SECTIONS ====
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Section 4: Parent Unmasked → Child Explicit Masked
    const parentUnmaskedChildMasked = await $("~Parent Unmasked → Child Explicit Masked");
    await parentUnmaskedChildMasked.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for "Child Masked Explicit"
    const childMaskedExplicit = await $("~Child Masked Explicit");
    await childMaskedExplicit.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Interact with "Masked inside unmasked parent" text field
    const maskedInsideUnmasked = await $('//XCUIElementTypeTextField[@value="Masked inside unmasked parent"]');
    await maskedInsideUnmasked.waitForExist({ timeout: 10000 });
    await maskedInsideUnmasked.click();
    await driver.setTimeouts(1000);
    await parentUnmaskedChildMasked.click();
    await driver.setTimeouts(1000);

    // Check for "Sibling Unmasked (inherits parent)"
    const siblingUnmasked = await $("~Sibling Unmasked (inherits parent)");
    await siblingUnmasked.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // ==== SCROLL DOWN MORE TO SEE DEEP NESTING ====
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Section 5: Deep Nesting (Mixed Overrides)
    const deepNesting = await $("~Deep Nesting (Mixed Overrides)");
    await deepNesting.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for "Level 2 (no id)"
    const level2 = await $("~Level 2 (no id)");
    await level2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Check for "Level 3 Explicit Masked"
    const level3 = await $("~Level 3 Explicit Masked");
    await level3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // ==== NAVIGATE BACK TO SWIFTUI SCREEN ====
    // Use the back button on the navigation bar
    const backButton = await $("~SwiftUI Elements");
    await backButton.waitForExist({ timeout: 10000 });
    await backButton.click();
    await driver.setTimeouts(2000);

    // Verify we're back on SwiftUI screen
    await swiftUITitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // ==== NAVIGATE BACK TO MAIN SCREEN ====
    // Use the back button to return to MainScreen
    const backToMain = await $("~BackButton");
    await backToMain.waitForExist({ timeout: 10000 });
    await backToMain.click();
    await driver.setTimeouts(2000);

    // Verify we're back on MainScreen by checking for "Hello, World" text
    await helloWorldText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Opens app and navigates through all views", async () => {
    // wait for the app to load
    await driver.setTimeouts(5000);

    // wait for "Hello, World" text to be seen
    const helloWorldText = await $("Hello, World");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(5000);
  });
});
