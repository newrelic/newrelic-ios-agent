/**
 * Text Masking (UIKit) Screen Tests
 * Tests the UIKit-based text masking functionality
 *
 * This screen contains comprehensive masking scenarios:
 * - Search & Credentials Fields (search, username, password, credit card, CVV)
 * - Masked Fields (UILabel, UITextField, UITextView with nr-mask)
 * - Unmasked Fields (UILabel, UITextField, UITextView with nr-unmask)
 * - Custom Masked Fields (with 'private' accessibility ID)
 * - Custom Unmasked Fields (with 'public' accessibility ID)
 * - Parent-Child Relationship (masking propagation to child views)
 * - TableView Masking Test (masking in table view hierarchy)
 */

describe("Text Masking (UIKit) Screen", () => {
  it("Should navigate to Text Masking screen and verify title", async () => {
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to Text Masking screen
    const textMaskingButton = await $("~Text Masking");
    await textMaskingButton.waitForExist({ timeout: 30000 });
    await textMaskingButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Text Masking screen by checking navigation bar title
    const textMaskingTitle = await $("~Text Masking");
    await textMaskingTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should verify search and credentials fields section", async () => {
    // Verify section header
    const sectionHeader = await $("~Search & Credentials Fields");
    await sectionHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Test Search Field (masked)
    const searchField = await $('//XCUIElementTypeSearchField[@name="Search query (masked)"]');
    await searchField.waitForExist({ timeout: 10000 });
    await searchField.click();
    await driver.setTimeouts(500);
    // Dismiss keyboard
    await sectionHeader.click();
    await driver.setTimeouts(500);

    // Test Username Field (unmasked)
    const usernameField = await $('//XCUIElementTypeTextField[@value="Username (unmasked)"]');
    await usernameField.waitForExist({ timeout: 10000 });
    await usernameField.click();
    await driver.setTimeouts(500);
    await sectionHeader.click();
    await driver.setTimeouts(500);

    // Test Password Field (masked)
    const passwordField = await $('//XCUIElementTypeSecureTextField[@value="Password (masked)"]');
    await passwordField.waitForExist({ timeout: 10000 });
    await passwordField.click();
    await driver.setTimeouts(500);
    await sectionHeader.click();
    await driver.setTimeouts(500);

    // Test Credit Card Field (masked)
    const creditCardField = await $('//XCUIElementTypeTextField[@value="Credit Card Number (masked)"]');
    await creditCardField.waitForExist({ timeout: 10000 });
    await creditCardField.click();
    await driver.setTimeouts(500);
    await sectionHeader.click();
    await driver.setTimeouts(500);

    // Test CVV Field (masked)
    const cvvField = await $('//XCUIElementTypeSecureTextField[@value="CVV (masked)"]');
    await cvvField.waitForExist({ timeout: 10000 });
    await cvvField.click();
    await driver.setTimeouts(500);
    await sectionHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should verify masked fields section with labels", async () => {
    // Verify section header
    const maskedFieldsHeader = await $("~Masked Fields");
    await maskedFieldsHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify Masked UILabels (1-4)
    const maskedLabel1 = await $("~Masked Fields UILabel 1");
    await maskedLabel1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const maskedLabel2 = await $("~Masked Fields UILabel 2");
    await maskedLabel2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const maskedLabel3 = await $("~Masked Fields UILabel 3");
    await maskedLabel3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const maskedLabel4 = await $("~Masked Fields UILabel 4");
    await maskedLabel4.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify masked fields section with text fields", async () => {
    // Test Masked UITextFields (1-4)
    const maskedTextField1 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 1"]');
    await maskedTextField1.waitForExist({ timeout: 10000 });
    await maskedTextField1.click();
    await driver.setTimeouts(500);

    const maskedFieldsHeader = await $("~Masked Fields");
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);

    const maskedTextField2 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 2"]');
    await maskedTextField2.waitForExist({ timeout: 10000 });
    await maskedTextField2.click();
    await driver.setTimeouts(500);
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);

    const maskedTextField3 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 3"]');
    await maskedTextField3.waitForExist({ timeout: 10000 });
    await maskedTextField3.click();
    await driver.setTimeouts(500);
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);

    const maskedTextField4 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 4"]');
    await maskedTextField4.waitForExist({ timeout: 10000 });
    await maskedTextField4.click();
    await driver.setTimeouts(500);
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should verify masked fields section with text views", async () => {
    // Test Masked UITextViews (1-2 visible)
    const maskedTextView1 = await $('//XCUIElementTypeTextView[@value="Masked Fields UITextView 1"]');
    await maskedTextView1.waitForExist({ timeout: 10000 });
    await maskedTextView1.click();
    await driver.setTimeouts(500);

    const maskedFieldsHeader = await $("~Masked Fields");
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);

    const maskedTextView2 = await $('//XCUIElementTypeTextView[@value="Masked Fields UITextView 2"]');
    await maskedTextView2.waitForExist({ timeout: 10000 });
    await maskedTextView2.click();
    await driver.setTimeouts(500);
    await maskedFieldsHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should scroll down and verify unmasked fields section", async () => {
    // Scroll down to access unmasked fields
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify section header
    const unmaskedFieldsHeader = await $("~Unmasked Fields");
    await unmaskedFieldsHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify Unmasked UILabels (1-4)
    const unmaskedLabel1 = await $("~Unmasked Fields UILabel 1");
    await unmaskedLabel1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const unmaskedLabel2 = await $("~Unmasked Fields UILabel 2");
    await unmaskedLabel2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const unmaskedLabel3 = await $("~Unmasked Fields UILabel 3");
    await unmaskedLabel3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const unmaskedLabel4 = await $("~Unmasked Fields UILabel 4");
    await unmaskedLabel4.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify unmasked text fields", async () => {
    // Test Unmasked UITextFields
    const unmaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Unmasked Fields UITextField 1"]');
    await unmaskedTextField1.waitForExist({ timeout: 10000 });
    await unmaskedTextField1.click();
    await driver.setTimeouts(500);

    const unmaskedFieldsHeader = await $("~Unmasked Fields");
    await unmaskedFieldsHeader.click();
    await driver.setTimeouts(500);

    const unmaskedTextField2 = await $('//XCUIElementTypeTextField[@value="Unmasked Fields UITextField 2"]');
    await unmaskedTextField2.waitForExist({ timeout: 10000 });
    await unmaskedTextField2.click();
    await driver.setTimeouts(500);
    await unmaskedFieldsHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should scroll down and verify custom masked fields section", async () => {
    // Scroll down more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify section header
    const customMaskedHeader = await $("~Custom Masked Fields");
    await customMaskedHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify Custom Masked UILabels (with 'private' accessibility ID)
    const customMaskedLabel1 = await $("~Custom Masked Fields UILabel 1");
    await customMaskedLabel1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const customMaskedLabel2 = await $("~Custom Masked Fields UILabel 2");
    await customMaskedLabel2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Test Custom Masked TextField
    const customMaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Custom Masked Fields UITextField 1"]');
    await customMaskedTextField1.waitForExist({ timeout: 10000 });
    await customMaskedTextField1.click();
    await driver.setTimeouts(500);
    await customMaskedHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should scroll down and verify custom unmasked fields section", async () => {
    // Scroll down more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify section header
    const customUnmaskedHeader = await $("~Custom Unmasked Fields");
    await customUnmaskedHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify Custom Unmasked UILabels (with 'public' accessibility ID)
    const customUnmaskedLabel1 = await $("~Custom Unmasked Fields UILabel 1");
    await customUnmaskedLabel1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const customUnmaskedLabel2 = await $("~Custom Unmasked Fields UILabel 2");
    await customUnmaskedLabel2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Test Custom Unmasked TextField
    const customUnmaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Custom Unmasked Fields UITextField 1"]');
    await customUnmaskedTextField1.waitForExist({ timeout: 10000 });
    await customUnmaskedTextField1.click();
    await driver.setTimeouts(500);
    await customUnmaskedHeader.click();
    await driver.setTimeouts(500);
  });

  it("Should scroll down and verify parent-child relationship section", async () => {
    // Scroll down more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify section header
    const parentChildHeader = await $("~Parent-Child Relationship");
    await parentChildHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify description text
    const descriptionText = await $("~Testing masked accessibility identifier propagation to child views");
    await descriptionText.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify Masked Parent View
    const maskedParentView = await $("~Masked Parent View");
    await maskedParentView.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify child elements within masked parent
    const childLabel1 = await $("~child-label-1");
    await childLabel1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const childButton1 = await $("~child-button-1");
    await childButton1.waitForExist({ timeout: 10000 });
    await childButton1.click();
    await driver.setTimeouts(500);
  });

  it("Should verify unmasked parent view in parent-child section", async () => {
    // Scroll down a bit more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify Unmasked Parent View
    const unmaskedParentView = await $("~Unmasked Parent View");
    await unmaskedParentView.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify child elements within unmasked parent (same selectors, different context)
    const childLabel2 = await $("~child-label-2");
    await childLabel2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const childButton2 = await $("~child-button-2");
    await childButton2.waitForExist({ timeout: 10000 });
    await childButton2.click();
    await driver.setTimeouts(500);
  });

  it("Should scroll down and verify table view masking test", async () => {
    // Scroll down more
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Verify section header
    const tableViewHeader = await $("~TableView Masking Test");
    await tableViewHeader.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify description
    const tableViewDescription = await $("~Testing masking propagation in TableView hierarchy");
    await tableViewDescription.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify table cell elements
    const title1 = await $("~Title 1");
    await title1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    const subtitle1 = await $("~Subtitle 1");
    await subtitle1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Test Action button in first cell
    const actionButton = await $("~Action");
    await actionButton.waitForExist({ timeout: 10000 });
    await actionButton.click();
    await driver.setTimeouts(500);
  });

  it("Should navigate back to MainScreen", async () => {
    // Scroll back to top
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(1000);
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(1000);
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(1000);

    // // Navigate back using back button
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
