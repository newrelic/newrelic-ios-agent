/**
 * The rest of the UIKit home screen's destinations: Diff Test View, Infinite Images View, Infinite Scroll View,
 * WebView and SwiftUIViewRepresentable. Each is opened, checked by what it shows, and closed again, so each
 * is a MobileView visit with an interaction or scroll in it.
 */

const h = require("./helpers");

describe("Other home screen views", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("Diff Test View: types into its field and shows its alert", async () => {
    await h.openFromHome("Diff Test View");
    await h.expectVisible(h.sel.text("Diff Test"));
    await h.typeInto(h.sel.field("Enter text"), "diff test input");
    await h.scrollAndTap(h.sel.button("Show Alert"));
    await h.expectVisible(h.sel.text("Button tapped!"));
    await h.tap(h.sel.button("OK"));
    await h.expectGone(h.sel.text("Button tapped!"));
    await h.goBack();
  });

  it("Infinite Images View: scrolls the image grid", async () => {
    await h.openFromHome("Infinite Images View");
    await h.expectVisible(h.sel.text("Infinite Images"));
    await h.drag("down");
    await h.drag("down");
    await h.drag("up");
    await h.goBack();
  });

  it("Infinite Scroll View: scrolls to the end of the first page and loads the next", async () => {
    await h.openFromHome("Infinite Scroll View");
    await h.expectVisible(h.sel.text("Infinite Scroll"));
    await h.expectVisible(h.sel.text("Row 1"));
    // Pages are 25 rows; reaching the last one starts loading the next, which arrives 1.5s later. Drags down
    // until a row of that page is on screen, and taps it. Not scrollTo: the list has no end to search toward,
    // and each page reloads the table, replacing cells under a lookup, which is why a stale element is just
    // another try.
    await driver.waitUntil(
      async () => {
        try {
          const [row] = await $$(h.sel.text("Row 30"));
          if (row && (await row.isDisplayed())) {
            await row.click();
            return true;
          }
          await h.drag("down");
        } catch (err) {
          if (!h.isStale(err)) throw err;
        }
        return false;
      },
      { timeout: 60000, interval: 500, timeoutMsg: "The second page of rows never loaded" }
    );
    await h.goBack();
  });

  it("WebView: loads the page", async () => {
    await h.openFromHome("WebView");
    await h.expectVisible(h.sel.text("Web View"));
    await (await $("-ios class chain:**/XCUIElementTypeWebView")).waitForExist({ timeout: 10000 });
    await h.goBack();
  });

  it("SwiftUIViewRepresentable: scrolls its hosted SwiftUI content", async () => {
    await h.openFromHome("SwiftUIViewRepresentable");
    await h.expectVisible(h.sel.text("Item 0"));
    await h.scrollTo(h.sel.text("Item 3"));
    await h.goBack();
    await h.waitForHome(5000);
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
