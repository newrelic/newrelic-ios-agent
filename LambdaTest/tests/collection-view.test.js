/**
 * Collection View Screen Tests
 * Tests UIKit collection view functionality
 *
 * This screen contains a scrollable collection view with:
 * - Navigation bar "NRTestApp.ScrollableCollectionView"
 * - Grid layout with 3 columns
 * - 18+ numbered cells (0 through 17 visible initially)
 * - Each cell is 134x134 pixels
 * - Vertical and horizontal scroll bars
 * - 7 pages of scrollable content vertically
 *
 * Grid Structure (3 columns):
 * Row 1: 0, 1, 2
 * Row 2: 3, 4, 5
 * Row 3: 6, 7, 8
 * Row 4: 9, 10, 11
 * Row 5: 12, 13, 14
 * Row 6: 15, 16, 17
 * (More rows below...)
 */

describe("Collection View Screen", () => {
  it("Should navigate to Collection View and verify all cells and interactions", async () => {
    // Navigate to Collection View screen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 15000 });

    const collectionViewButton = await $("~Collection View");
    await collectionViewButton.waitForExist({ timeout: 5000 });
    await collectionViewButton.click();

    // Verify collection view exists
    const collectionView = await $('//XCUIElementTypeCollectionView');
    await collectionView.waitForExist({ timeout: 5000 });

    // Verify first 6 rows of cells (0-17) in batches
    const cell0 = await $("~0");
    await cell0.waitForExist({ timeout: 5000 });
    const cell1 = await $("~1");
    await cell1.waitForExist({ timeout: 3000 });
    const cell2 = await $("~2");
    await cell2.waitForExist({ timeout: 3000 });

    const cell3 = await $("~3");
    await cell3.waitForExist({ timeout: 3000 });
    const cell4 = await $("~4");
    await cell4.waitForExist({ timeout: 3000 });
    const cell5 = await $("~5");
    await cell5.waitForExist({ timeout: 3000 });

    const cell6 = await $("~6");
    await cell6.waitForExist({ timeout: 3000 });
    const cell7 = await $("~7");
    await cell7.waitForExist({ timeout: 3000 });
    const cell8 = await $("~8");
    await cell8.waitForExist({ timeout: 3000 });

    // Test cell interactions
    await cell0.click();
    await cell5.click();

    const cell10 = await $("~10");
    await cell10.waitForExist({ timeout: 3000 });
    await cell10.click();

    // Verify remaining visible cells
    await $("~9").waitForExist({ timeout: 3000 });
    await $("~11").waitForExist({ timeout: 3000 });
    await $("~12").waitForExist({ timeout: 3000 });
    await $("~13").waitForExist({ timeout: 3000 });
    await $("~14").waitForExist({ timeout: 3000 });
    await $("~15").waitForExist({ timeout: 3000 });
    await $("~16").waitForExist({ timeout: 3000 });
    await $("~17").waitForExist({ timeout: 3000 });

    // Scroll down to see more items
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.execute('mobile: scroll', { direction: 'down' });

    // Check for additional cells
    try {
      const cell18 = await $("~18");
      await cell18.waitForExist({ timeout: 2000 });
      await cell18.click();
    } catch (error) {
      // Cell may not exist
    }

    // Verify cell structure
    const cells = await $$('//XCUIElementTypeCell');
    if (cells.length === 0) {
      throw new Error('No cells found in collection view');
    }

    // Verify scroll bars
    const verticalScrollBar = await $('//XCUIElementTypeOther[@name="Vertical scroll bar, 7 pages"]');
    await verticalScrollBar.waitForExist({ timeout: 5000 });
    const horizontalScrollBar = await $('//XCUIElementTypeOther[@name="Horizontal scroll bar, 1 page"]');
    await horizontalScrollBar.waitForExist({ timeout: 5000 });

    // Scroll back to top
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.execute('mobile: scroll', { direction: 'up' });

    // Verify back at top
    await cell0.waitForExist({ timeout: 5000 });

    // Test corner cell interactions
    await cell0.click();
    await cell2.click();
  });

  it("Should navigate back to MainScreen", async () => {
    // Navigate back
    await driver.back();

    // Verify we're back on MainScreen
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 5000 });

    // Put app in background to trigger any pending events
    await driver.activateApp('com.apple.Preferences');
    await driver.pause(2000);
  });
});
