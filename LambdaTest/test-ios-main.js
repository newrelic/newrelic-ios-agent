/**
 * Main Test Suite for NRTestApp iOS
 *
 * This file serves as the entry point for running modular tests.
 * Individual test files are organized in the ./tests directory.
 *
 * To run specific test suites, use the individual test files in ./tests/
 *
 * Test Organization:
 * - swiftui-masking.test.js: Comprehensive masking tests for SwiftUI
 * - utilities.test.js: Utilities screen tests
 * - text-masking-uikit.test.js: UIKit text masking tests
 * - swiftui-buttons.test.js: SwiftUI button component tests
 * - swiftui-textfields.test.js: SwiftUI text field tests
 * - swiftui-lists.test.js: SwiftUI list view tests
 * - swiftui-other-components.test.js: Other SwiftUI components (pickers, toggles, etc.)
 * - collection-view.test.js: Collection view tests
 * - other-mainscreen-views.test.js: Other main screen view tests
 */

// Import test files
require('./tests/swiftui-masking.test.js');
require('./tests/utilities.test.js');
require('./tests/text-masking-uikit.test.js');
require('./tests/swiftui-buttons.test.js');
require('./tests/swiftui-textfields.test.js');
require('./tests/swiftui-lists.test.js');
require('./tests/swiftui-other-components.test.js');
require('./tests/collection-view.test.js');
require('./tests/other-mainscreen-views.test.js');

describe("NRTestApp iOS - Main Test Suite", () => {
  it("Should verify app launches successfully", async () => {
    // Wait for the app to load
    await driver.setTimeouts(5000);

    // Verify MainScreen is visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });

    console.log("✓ App launched successfully");
    await driver.setTimeouts(1000);
  });
});
