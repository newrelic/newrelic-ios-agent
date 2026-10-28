/**
 * Collection View (UIKit): ScrollableCollectionViewController, a 100-cell grid numbered 0-99. Taps cells at the
 * top, scrolls to the end of the grid and back, which is what exercises the agent's interaction and scroll
 * capture on a UICollectionView.
 */

const h = require("./helpers");

describe("Collection View Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens the grid and taps the first cells", async () => {
    await h.openFromHome("Collection View");
    for (const n of ["0", "1", "2", "3", "4", "5"]) {
      await h.expectVisible(h.sel.text(n));
    }
    await h.scrollAndTap(h.sel.text("0"));
    await h.scrollAndTap(h.sel.text("5"));
  });

  it("scrolls to the last cell", async () => {
    await h.scrollAndTap(h.sel.text("50"));
    await h.scrollAndTap(h.sel.text("99"));
  });

  it("scrolls back to the first cell", async () => {
    await h.scrollAndTap(h.sel.text("0"));
  });

  it("returns to the home screen", async () => {
    await h.goBack();
    await h.waitForHome(5000);
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
