/**
 * The Saved tab, whose two modes are one SwiftUI view: the app declares each with
 * NewRelic.setCurrentView, so switching modes here is what exercises the manual MobileViews API. Covers
 * both empty states, a saved home and a viewed one showing up in the right modes, opening a listing from
 * Saved rather than Search, and the Profile counters that track the same state.
 */

const h = require("./helpers");

const SAVED = "L-1003";
const VIEWED = "L-1002";

async function showMode(mode) {
  await h.tap(h.button(mode));
  await expect(h.button(mode)).toHaveAttribute("value", "1");
}

describe("HomeSearch: Saved homes", function () {
  this.timeout(180000);

  before(async () => {
    await h.waitForResults();
  });

  it("starts empty in both modes", async () => {
    await h.selectTab("Saved");
    await h.expectVisible(h.byId("saved.mode"));
    await h.expectText("No saved homes");
    await showMode("Recently Viewed");
    await h.expectText("Nothing viewed yet");
    await showMode("Favorites");
  });

  it("saves one home and views another from Search", async () => {
    await h.selectTab("Search");
    await h.openListing(SAVED);
    await h.tapId("detail.save");
    await expect(h.byId("detail.save")).toHaveAttribute("label", "Remove from saved");
    await h.goBack();

    await h.openListing(VIEWED);
    await h.goBack();
    await h.waitForResults();
  });

  it("lists the saved home under Favorites and both under Recently Viewed", async () => {
    await h.selectTab("Saved");
    await showMode("Favorites");
    await h.expectVisible(h.byId(`saved.listing.${SAVED}`));
    await h.expectGone(h.byId(`saved.listing.${VIEWED}`), 2000);

    await showMode("Recently Viewed");
    await h.expectVisible(h.byId(`saved.listing.${VIEWED}`));
    await h.expectVisible(h.byId(`saved.listing.${SAVED}`));
    // Most recent first.
    await expect($('-ios predicate string:name BEGINSWITH "saved.listing."')).toHaveAttribute(
      "name",
      `saved.listing.${VIEWED}`
    );
  });

  it("counts both on the Profile tab", async () => {
    await h.selectTab("Profile");
    await h.expectLabel("profile.stat.saved", "Saved homes, 1");
    await h.expectLabel("profile.stat.recent", "Recently viewed, 2");
  });

  it("opens a listing from Saved and unsaves it there", async () => {
    await h.selectTab("Saved");
    await showMode("Favorites");
    await h.tapId(`saved.listing.${SAVED}`);
    await h.tapId("detail.save");
    await expect(h.byId("detail.save")).toHaveAttribute("label", "Save home");
    await h.goBack();
    await h.expectText("No saved homes");
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
