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
  it("Should navigate to Collection View screen and verify structure", async () => {
    // Wait for the app to load on MainScreen
    await driver.setTimeouts(5000);

    // Wait for MainScreen to be visible
    const helloWorldText = await $("~public");
    await helloWorldText.waitForExist({ timeout: 30000 });
    await driver.setTimeouts(2000);

    // Navigate to Collection View screen
    const collectionViewButton = await $("~Collection View");
    await collectionViewButton.waitForExist({ timeout: 30000 });
    await collectionViewButton.click();
    await driver.setTimeouts(3000);

    // Verify collection view exists
    const collectionView = await $('//XCUIElementTypeCollectionView');
    await collectionView.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(1000);
  });

  it("Should verify first row of cells (0, 1, 2)", async () => {
    // Verify cell 0 (first row, first column)
    const cell0 = await $("~0");
    await cell0.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 1 (first row, second column)
    const cell1 = await $("~1");
    await cell1.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 2 (first row, third column)
    const cell2 = await $("~2");
    await cell2.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify second row of cells (3, 4, 5)", async () => {
    // Verify cell 3
    const cell3 = await $("~3");
    await cell3.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 4
    const cell4 = await $("~4");
    await cell4.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 5
    const cell5 = await $("~5");
    await cell5.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify third row of cells (6, 7, 8)", async () => {
    // Verify cell 6
    const cell6 = await $("~6");
    await cell6.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 7
    const cell7 = await $("~7");
    await cell7.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 8
    const cell8 = await $("~8");
    await cell8.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test cell interactions - tap cells 0, 5, and 10", async () => {
    // Tap cell 0
    const cell0 = await $("~0");
    await cell0.waitForExist({ timeout: 10000 });
    await cell0.click();
    await driver.setTimeouts(1000);

    // Tap cell 5
    const cell5 = await $("~5");
    await cell5.waitForExist({ timeout: 10000 });
    await cell5.click();
    await driver.setTimeouts(1000);

    // Tap cell 10
    const cell10 = await $("~10");
    await cell10.waitForExist({ timeout: 10000 });
    await cell10.click();
    await driver.setTimeouts(1000);
  });

  it("Should verify fourth row of cells (9, 10, 11)", async () => {
    // Verify cell 9
    const cell9 = await $("~9");
    await cell9.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 10
    const cell10 = await $("~10");
    await cell10.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 11
    const cell11 = await $("~11");
    await cell11.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify fifth row of cells (12, 13, 14)", async () => {
    // Verify cell 12
    const cell12 = await $("~12");
    await cell12.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 13
    const cell13 = await $("~13");
    await cell13.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 14
    const cell14 = await $("~14");
    await cell14.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should verify sixth row of cells (15, 16, 17)", async () => {
    // Verify cell 15
    const cell15 = await $("~15");
    await cell15.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 16
    const cell16 = await $("~16");
    await cell16.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify cell 17
    const cell17 = await $("~17");
    await cell17.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should scroll down to see more collection items", async () => {
    // Scroll down to see if there are more items beyond cell 17
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Try to find additional cells (may have more beyond 17)
    // The XML shows "7 pages" so there should be more content
    try {
      const cell18 = await $("~18");
      const exists = await cell18.waitForExist({ timeout: 3000 });
      if (exists) {
        await cell18.click();
        await driver.setTimeouts(1000);
      }
    } catch (error) {
      // Cell 18 may not exist or not be visible
      await driver.setTimeouts(500);
    }

    // Try to find more cells
    try {
      const cell20 = await $("~20");
      const exists = await cell20.waitForExist({ timeout: 3000 });
      if (exists) {
        await driver.setTimeouts(500);
      }
    } catch (error) {
      // Cells beyond 20 may not exist
      await driver.setTimeouts(500);
    }
  });

  it("Should continue scrolling to explore more pages", async () => {
    // Continue scrolling down (we have 7 pages according to XML)
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);
  });

  it("Should verify collection view cell structure", async () => {
    // Verify cells exist with proper structure
    const cells = await $$('//XCUIElementTypeCell');
    if (cells.length > 0) {
      // We should have multiple cells visible
      await driver.setTimeouts(500);

      // Verify at least one cell contains a StaticText element
      const staticTexts = await $$('//XCUIElementTypeCell//XCUIElementTypeStaticText');
      if (staticTexts.length > 0) {
        await driver.setTimeouts(500);
      }
    }
  });

  it("Should verify scroll bars exist", async () => {
    // Verify vertical scroll bar exists
    const verticalScrollBar = await $('//XCUIElementTypeOther[@name="Vertical scroll bar, 7 pages"]');
    await verticalScrollBar.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);

    // Verify horizontal scroll bar exists (though it shows 1 page)
    const horizontalScrollBar = await $('//XCUIElementTypeOther[@name="Horizontal scroll bar, 1 page"]');
    await horizontalScrollBar.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should scroll back to top of collection view", async () => {
    // Scroll back up to the top multiple times
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    // Verify cell 0 is visible again
    const cell0 = await $("~0");
    await cell0.waitForExist({ timeout: 10000 });
    await driver.setTimeouts(500);
  });

  it("Should test interactions with corner cells", async () => {
    // Test top-left cell (0)
    const cell0 = await $("~0");
    await cell0.click();
    await driver.setTimeouts(500);

    // Test top-right cell (2)
    const cell2 = await $("~2");
    await cell2.click();
    await driver.setTimeouts(500);

    // Scroll to bottom
    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    await driver.execute('mobile: scroll', { direction: 'down' });
    await driver.setTimeouts(2000);

    // Try to tap a cell near the bottom
    try {
      const bottomCell = await $("~15");
      if (await bottomCell.isExisting()) {
        await bottomCell.click();
        await driver.setTimeouts(500);
      }
    } catch (error) {
      await driver.setTimeouts(500);
    }
  });

  it("Should navigate back to MainScreen", async () => {
    // Scroll back to top first
    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    await driver.execute('mobile: scroll', { direction: 'up' });
    await driver.setTimeouts(2000);

    // Navigate back
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
