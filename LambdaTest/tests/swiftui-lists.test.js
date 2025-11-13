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
  it("Should navigate to Lists screen and test all interactions", async () => {
    // Navigate to SwiftUI screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    const swiftUIButton = await $("~SwiftUI");
    await swiftUIButton.waitForExist({ timeout: 5000 });
    await swiftUIButton.click();

    // Scroll down to find Lists option
    await driver.execute('mobile: scroll', { direction: 'down' });

    // Navigate to Lists screen
    const listsButton = await $("~Lists");
    await listsButton.waitForExist({ timeout: 5000 });
    await listsButton.click();

    // Verify we're on Lists screen
    const listsTitle = await $("~Lists");
    await listsTitle.waitForExist({ timeout: 5000 });

    // Verify all list items are visible (1-5)
    const item1 = await $("~Item 1");
    await item1.waitForExist({ timeout: 5000 });
    const item2 = await $("~Item 2");
    await item2.waitForExist({ timeout: 5000 });
    const item3 = await $("~Item 3");
    await item3.waitForExist({ timeout: 5000 });
    const item4 = await $("~Item 4");
    await item4.waitForExist({ timeout: 5000 });
    const item5 = await $("~Item 5");
    await item5.waitForExist({ timeout: 5000 });

    // Test interactions with first 3 items
    await item1.click();
    await item2.click();
    await item3.click();

    // Scroll down and check for more items
    await driver.execute('mobile: scroll', { direction: 'down' });
    try {
      const item6 = await $("~Item 6");
      await item6.waitForExist({ timeout: 2000 });
    } catch (error) {
      // Item 6 may not exist
    }

    // Scroll back to top
    await driver.execute('mobile: scroll', { direction: 'up' });
    await item1.waitForExist({ timeout: 5000 });

    // Verify collection view structure
    const collectionView = await $('//XCUIElementTypeCollectionView');
    await collectionView.waitForExist({ timeout: 5000 });
    const cells = await $$('//XCUIElementTypeCell');
    // Ensure at least 5 cells exist
    if (cells.length < 5) {
      throw new Error(`Expected at least 5 cells, found ${cells.length}`);
    }
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
