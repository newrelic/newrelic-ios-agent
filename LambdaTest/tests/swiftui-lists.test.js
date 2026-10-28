/**
 * SwiftUI Lists: ListsView, a List of five rows inside its own NavigationView, so the screen has three
 * navigation bars (UIKit's, the SwiftUI Elements list's and its own).
 */

const h = require("./helpers");

const ITEMS = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"];

describe("SwiftUI Lists Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Lists, which is below the fold of the SwiftUI list", async () => {
    await h.openSwiftUIScreen("Lists");
    await h.expectVisible(h.sel.text("Lists"));
    for (const item of ITEMS) {
      await h.expectVisible(h.sel.text(item));
    }
  });

  it("taps the first three rows", async () => {
    for (const item of ITEMS.slice(0, 3)) {
      await h.tap(h.sel.text(item));
    }
  });

  it("returns to the home screen", async () => {
    await h.goHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
