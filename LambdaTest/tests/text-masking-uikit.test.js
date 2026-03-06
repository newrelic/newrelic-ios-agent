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
  it("Should navigate to Text Masking screen and test all fields with text input", async () => {
    // Navigate to Text Masking screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 10000 });

    const textMaskingButton = await $("~Text Masking");
    await textMaskingButton.waitForExist({ timeout: 3000 });
    await textMaskingButton.click();

    // Verify we're on Text Masking screen
    const textMaskingTitle = await $("~Text Masking");
    await textMaskingTitle.waitForExist({ timeout: 3000 });


    // Test Search & Credentials Fields section with text input
    const sectionHeader = await $("~Search & Credentials Fields");
    await sectionHeader.waitForExist({ timeout: 3000 });

    // Enter text in Search Field (masked)
    const searchField = await $('//XCUIElementTypeSearchField[@name="Search query (masked)"]');
    await searchField.waitForExist({ timeout: 3000 });
    await searchField.click();
    await searchField.setValue("confidential search query");
    await sectionHeader.click();

    // Enter text in Username Field (unmasked)
    const usernameField = await $('//XCUIElementTypeTextField[@value="Username (unmasked)"]');
    await usernameField.waitForExist({ timeout: 3000 });
    await usernameField.click();
    await usernameField.setValue("john.doe@example.com");
    await sectionHeader.click();

    // Enter text in Password Field (masked)
    const passwordField = await $('//XCUIElementTypeSecureTextField[@value="Password (masked)"]');
    await passwordField.waitForExist({ timeout: 3000 });
    await passwordField.click();
    await passwordField.setValue("SecureP@ssw0rd123");
    await sectionHeader.click();

    // Enter text in Credit Card Field (masked)
    const creditCardField = await $('//XCUIElementTypeTextField[@value="Credit Card Number (masked)"]');
    await creditCardField.waitForExist({ timeout: 3000 });
    await creditCardField.click();
    await creditCardField.setValue("4532-1234-5678-9012");
    await sectionHeader.click();

    // Enter text in CVV Field (masked)
    const cvvField = await $('//XCUIElementTypeSecureTextField[@value="CVV (masked)"]');
    await cvvField.waitForExist({ timeout: 3000 });
    await cvvField.click();
    await cvvField.setValue("987");
    await sectionHeader.click();


    // Test Masked Fields section with text input
    const maskedFieldsHeader = await $("~Masked Fields");
    await maskedFieldsHeader.waitForExist({ timeout: 3000 });

    // Verify Masked UILabels exist (1-4)
    await $("~Masked Fields UILabel 1").waitForExist({ timeout: 3000 });
    await $("~Masked Fields UILabel 2").waitForExist({ timeout: 3000 });
    await $("~Masked Fields UILabel 3").waitForExist({ timeout: 3000 });
    await $("~Masked Fields UILabel 4").waitForExist({ timeout: 3000 });

    // Enter text in all Masked UITextFields (1-4)
    const maskedTextField1 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 1"]');
    await maskedTextField1.waitForExist({ timeout: 3000 });
    await maskedTextField1.click();
    await maskedTextField1.setValue("Private data field 1");
    await maskedFieldsHeader.click();

    const maskedTextField2 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 2"]');
    await maskedTextField2.waitForExist({ timeout: 3000 });
    await maskedTextField2.click();
    await maskedTextField2.setValue("SSN: 123-45-6789");
    await maskedFieldsHeader.click();

    const maskedTextField3 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 3"]');
    await maskedTextField3.waitForExist({ timeout: 3000 });
    await maskedTextField3.click();
    await maskedTextField3.setValue("API Key: sk_live_abc123xyz");
    await maskedFieldsHeader.click();

    const maskedTextField4 = await $('//XCUIElementTypeTextField[@value="Masked Fields UITextField 4"]');
    await maskedTextField4.waitForExist({ timeout: 3000 });
    await maskedTextField4.click();
    await maskedTextField4.setValue("Bank Account: 987654321");
    await maskedFieldsHeader.click();

    // Enter text in Masked UITextViews (1-2)
    const maskedTextView1 = await $('//XCUIElementTypeTextView[@value="Masked Fields UITextView 1"]');
    await maskedTextView1.waitForExist({ timeout: 3000 });
    await maskedTextView1.click();
    await maskedTextView1.setValue("Confidential multiline text with sensitive information line 1\nLine 2 contains secret data");
    await maskedFieldsHeader.click();

    const maskedTextView2 = await $('//XCUIElementTypeTextView[@value="Masked Fields UITextView 2"]');
    await maskedTextView2.waitForExist({ timeout: 3000 });
    await maskedTextView2.click();
    await maskedTextView2.setValue("Private notes:\nMeeting at 3pm\nDiscuss Q4 financials");
    await maskedFieldsHeader.click();


    // Scroll down to test Unmasked Fields section
    await driver.execute('mobile: scroll', { direction: 'down' });

    const unmaskedFieldsHeader = await $("~Unmasked Fields");
    await unmaskedFieldsHeader.waitForExist({ timeout: 3000 });

    // Verify Unmasked UILabels exist (1-4)
    await $("~Unmasked Fields UILabel 1").waitForExist({ timeout: 3000 });
    await $("~Unmasked Fields UILabel 2").waitForExist({ timeout: 3000 });
    await $("~Unmasked Fields UILabel 3").waitForExist({ timeout: 3000 });
    await $("~Unmasked Fields UILabel 4").waitForExist({ timeout: 3000 });

    // Enter text in Unmasked UITextFields
    const unmaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Unmasked Fields UITextField 1"]');
    await unmaskedTextField1.waitForExist({ timeout: 3000 });
    await unmaskedTextField1.click();
    await unmaskedTextField1.setValue("Public information field 1");
    await unmaskedFieldsHeader.click();

    const unmaskedTextField2 = await $('//XCUIElementTypeTextField[@value="Unmasked Fields UITextField 2"]');
    await unmaskedTextField2.waitForExist({ timeout: 3000 });
    await unmaskedTextField2.click();
    await unmaskedTextField2.setValue("Company: Acme Corp");
    await unmaskedFieldsHeader.click();


    // Scroll down to test Custom Masked Fields section
    await driver.execute('mobile: scroll', { direction: 'down' });

    const customMaskedHeader = await $("~Custom Masked Fields");
    await customMaskedHeader.waitForExist({ timeout: 3000 });

    // Verify Custom Masked UILabels (with 'private' accessibility ID)
    await $("~Custom Masked Fields UILabel 1").waitForExist({ timeout: 3000 });
    await $("~Custom Masked Fields UILabel 2").waitForExist({ timeout: 3000 });

    // Enter text in Custom Masked TextField
    const customMaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Custom Masked Fields UITextField 1"]');
    await customMaskedTextField1.waitForExist({ timeout: 3000 });
    await customMaskedTextField1.click();
    await customMaskedTextField1.setValue("Custom private ID: xyz-789");
    await customMaskedHeader.click();

    // Scroll down to test Custom Unmasked Fields section
    await driver.execute('mobile: scroll', { direction: 'down' });

    const customUnmaskedHeader = await $("~Custom Unmasked Fields");
    await customUnmaskedHeader.waitForExist({ timeout: 3000 });

    // Verify Custom Unmasked UILabels (with 'public' accessibility ID)
    await $("~Custom Unmasked Fields UILabel 1").waitForExist({ timeout: 3000 });
    await $("~Custom Unmasked Fields UILabel 2").waitForExist({ timeout: 3000 });

    // Enter text in Custom Unmasked TextField
    const customUnmaskedTextField1 = await $('//XCUIElementTypeTextField[@value="Custom Unmasked Fields UITextField 1"]');
    await customUnmaskedTextField1.waitForExist({ timeout: 3000 });
    await customUnmaskedTextField1.click();
    await customUnmaskedTextField1.setValue("Custom public reference: REF-456");
    await customUnmaskedHeader.click();


    // Scroll down to test Parent-Child Relationship section
    await driver.execute('mobile: scroll', { direction: 'down' });

    const parentChildHeader = await $("~Parent-Child Relationship");
    await parentChildHeader.waitForExist({ timeout: 3000 });

    await $("~Testing masked accessibility identifier propagation to child views").waitForExist({ timeout: 3000 });

    // Test Masked Parent View
    const maskedParentView = await $("~Masked Parent View");
    await maskedParentView.waitForExist({ timeout: 3000 });

    await $("~child-label-1").waitForExist({ timeout: 3000 });

    const childButton1 = await $("~child-button-1");
    await childButton1.waitForExist({ timeout: 3000 });
    await childButton1.click();

    // Scroll down to test Unmasked Parent View
    await driver.execute('mobile: scroll', { direction: 'down' });

    const unmaskedParentView = await $("~Unmasked Parent View");
    await unmaskedParentView.waitForExist({ timeout: 3000 });

    await $("~child-label-2").waitForExist({ timeout: 3000 });

    const childButton2 = await $("~child-button-2");
    await childButton2.waitForExist({ timeout: 3000 });
    await childButton2.click();

    // Scroll down to test TableView Masking
    await driver.execute('mobile: scroll', { direction: 'down' });

    const tableViewHeader = await $("~TableView Masking Test");
    await tableViewHeader.waitForExist({ timeout: 3000 });

    await $("~Testing masking propagation in TableView hierarchy").waitForExist({ timeout: 3000 });

    // Verify and interact with table cell elements
    await $("~Title 1").waitForExist({ timeout: 3000 });
    await $("~Subtitle 1").waitForExist({ timeout: 3000 });

    const actionButton = await $("~Action");
    await actionButton.waitForExist({ timeout: 3000 });
    await actionButton.click();
  });

  it("Should navigate back to MainScreen", async () => {
    // Scroll back to top quickly
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.execute('mobile: scroll', { direction: 'up' });

    // Navigate back
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 3000 });

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(1000);
  });
});
