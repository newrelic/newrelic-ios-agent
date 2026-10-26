/**
 * The Profile tab and its three pushed screens: Notifications (every toggle, every frequency), Search
 * preferences, and Debug Info, the one screen with no MobileView modifier. Debug Info also says which mode
 * the agent started in; HS_EXPECT_MODE, which the LambdaTest configs set to "live", turns that into an
 * assertion that the CI build really did bake an app token into NRAPI-Info.plist.
 */

const h = require("./helpers");

const NOTIFICATION_TOGGLES = [
  "New listings in my search",
  "Price changes on saved homes",
  "Open houses nearby",
  "Messages from agents",
];

async function flip(label) {
  const row = await h.expectVisible($(`-ios predicate string:type == "XCUIElementTypeSwitch" AND label == "${label}"`));
  const before = await row.getAttribute("value");
  await h.tap(h.toggleControl(label));
  await expect(row).toHaveAttribute("value", before === "1" ? "0" : "1");
}

describe("HomeSearch: Profile", function () {
  this.timeout(180000);

  before(async () => {
    await h.waitForResults();
    await h.selectTab("Profile");
  });

  it("shows the account and its activity", async () => {
    await h.expectText("Jordan Alvarez");
    await h.expectLabel("profile.stat.saved", "Saved homes, 0");
    await h.expectLabel("profile.stat.recent", "Recently viewed, 0");
    await h.expectLabel("profile.stat.conversations", "Conversations, 4");
  });

  it("changes every notification setting", async () => {
    await h.tapId("profile.notifications");
    for (const label of NOTIFICATION_TOGGLES) {
      await flip(label);
    }
    for (const label of NOTIFICATION_TOGGLES) {
      await flip(label);
    }
    for (const frequency of ["Instantly", "Weekly digest", "Daily digest"]) {
      await h.tap(await h.scrollTo(h.button(frequency)));
      await expect(h.button(frequency)).toHaveAttribute("value", "1");
    }
    await h.goBack();
  });

  it("changes the search preferences", async () => {
    await h.tapId("profile.searchPreferences");
    await h.expectVisible(h.byLabel("Active filters, 0"));
    await h.tap(h.button("Rating 6+ / 10, Increment"));
    await h.expectVisible(h.stepper("Rating 7+ / 10"));
    await h.tap(h.button("Rating 7+ / 10, Decrement"));
    await h.expectVisible(h.stepper("Rating 6+ / 10"));
    await flip("Include pending sales");
    await h.goBack();
  });

  it("opens Debug Info and records a breadcrumb from it", async () => {
    await h.tapId("profile.debugInfo");
    const expectedMode = process.env.HS_EXPECT_MODE;
    if (expectedMode) {
      await h.expectVisible(h.byLabel(`Mode, ${expectedMode}`));
    } else {
      await h.expectText("Mode, ");
    }
    await h.expectVisible(h.byLabel(`Listings loaded, ${h.TOTAL_LISTINGS}`));

    await h.tap(await h.scrollTo(h.byId("debug.breadcrumb")));
    await h.expectVisible(await h.scrollTo(h.byId("debug.breadcrumb.recorded")));
    await h.goBack();
    await h.expectVisible(h.byId("profile.debugInfo"));
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
