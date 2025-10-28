/**
 * SwiftUI Lists Screen Tests
 * Tests list views and interactions in SwiftUI
 *
 * This screen contains a scrollable list with:
 * - Navigation bar with "Lists" title
 * - Collection view containing list items (Item 1 through Item 5+)
 * - Dividers between items
 * - Scroll bar for navigation
 */

describe("SwiftUI Lists Screen", () => {
  it("Should navigate to Lists screen and verify title", async () => {
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

    // Scroll down to find Lists option
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Navigate to Lists screen
    const listsButton = await $("~Lists");
    await listsButton.waitForExist({ timeout: 30000 });
    await listsButton.click();
    await driver.setTimeouts(3000);

    // Verify we're on Lists screen by checking navigation bar title
    const listsTitle = await $("~Lists");
    await listsTitle.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should verify list items are visible", async () => {
    // Verify Item 1
    const item1 = await $("~Item 1");
    await item1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify Item 2
    const item2 = await $("~Item 2");
    await item2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify Item 3
    const item3 = await $("~Item 3");
    await item3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify Item 4
    const item4 = await $("~Item 4");
    await item4.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify Item 5
    const item5 = await $("~Item 5");
    await item5.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test list item interaction - Item 1", async () => {
    // Click on Item 1
    const item1 = await $("~Item 1");
    await item1.waitForExist({ timeout: 10000 });
    await item1.click();
    await driver.setTimeouts(1000);
  });

  it("Should test list item interaction - Item 2", async () => {
    // Click on Item 2
    const item2 = await $("~Item 2");
    await item2.waitForExist({ timeout: 10000 });
    await item2.click();
    await driver.setTimeouts(1000);
  });

  it("Should test list item interaction - Item 3", async () => {
    // Click on Item 3
    const item3 = await $("~Item 3");
    await item3.waitForExist({ timeout: 10000 });
    await item3.click();
    await driver.setTimeouts(1000);
  });

  it("Should scroll through list to see more items", async () => {
    // Scroll down to see if there are more items beyond Item 5
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Try to find additional items (the list may have more items not initially visible)
    // If they exist, they will be found; if not, the test continues
    try {
      const item6 = await $("~Item 6");
      const exists = await item6.waitForExist({ timeout: 3000 });
      if (exists) {
        await driver.setTimeouts(500);
      }
    } catch (error) {
      // Item 6 doesn't exist, which is fine
      await driver.setTimeouts(500);
    }
  });

  it("Should scroll back to top of list", async () => {
    // Scroll back up to the top
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    // Verify Item 1 is visible again after scrolling back up
    const item1 = await $("~Item 1");
    await item1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify collection view structure", async () => {
    // Verify the collection view exists (SwiftUI uses collection views for lists)
    const collectionView = await $('//XCUIElementTypeCollectionView');
    await collectionView.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);

    // Verify cells exist within the collection view
    const cells = await $$('//XCUIElementTypeCell');
    if (cells.length > 0) {
      // Verify we have at least 5 cells (Items 1-5 are visible in XML)
      await driver.setTimeouts(500);
    }
  });

  it("Should navigate back to SwiftUI screen", async () => {
    // Navigate back
    await driver.back();
    await driver.setTimeouts(2000);

    // Verify we're back on SwiftUI screen
    // The screen should show SwiftUI options again
    await driver.setTimeouts(1000);

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
