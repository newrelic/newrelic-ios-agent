/**
 * Listing Detail and the three modals it presents: the photo gallery (full-screen cover), the mortgage
 * calculator (popover) and the tour request (item-driven sheet). Ends with the app's whole funnel,
 * Search → Listing Detail → Contact Agent → Tour Requested, and back to the results.
 */

const h = require("./helpers");

const LISTING = "L-1001";
const ADDRESS = "1428 Fremont Ave N";
const PHOTO_COUNT = 6;

describe("HomeSearch: Listing Detail", function () {
  this.timeout(180000);

  before(async () => {
    await h.waitForResults();
  });

  it("opens a listing from the results", async () => {
    await h.openListing(LISTING);
    await h.expectText("$875,000");
    await h.expectVisible(h.byLabel("Facts"));
  });

  it("saves and unsaves the home", async () => {
    await expect(h.byId("detail.save")).toHaveAttribute("label", "Save home");
    await h.tapId("detail.save");
    await expect(h.byId("detail.save")).toHaveAttribute("label", "Remove from saved");
    await h.tapId("detail.save");
    await expect(h.byId("detail.save")).toHaveAttribute("label", "Save home");
  });

  it("pages through the photo gallery and closes it", async () => {
    await h.tapId("detail.photos");
    await h.expectLabel("gallery.counter", `1 of ${PHOTO_COUNT} · ${ADDRESS}`);
    await driver.execute("mobile: swipe", { direction: "left" });
    await h.expectLabel("gallery.counter", `2 of ${PHOTO_COUNT} · ${ADDRESS}`);
    await driver.execute("mobile: swipe", { direction: "left" });
    await h.expectLabel("gallery.counter", `3 of ${PHOTO_COUNT} · ${ADDRESS}`);
    await h.tapId("gallery.close");
    await h.expectVisible(h.byId("detail.save"));
  });

  it("recalculates the mortgage estimate for every term", async () => {
    await h.tapId("detail.mortgage");
    const payment = await h.byId("mortgage.payment");
    await payment.waitForExist({ timeout: 10000 });
    const thirtyYear = await payment.getAttribute("label");

    await h.tap(h.button("15 yr"));
    await expect(payment).not.toHaveAttribute("label", thirtyYear);
    await h.tap(h.button("20 yr"));
    await h.tap(h.button("30 yr"));
    await expect(payment).toHaveAttribute("label", thirtyYear);

    await h.dismissPopover();
    await h.expectVisible(h.byId("detail.save"));
  });

  it("keeps Send disabled until name and email are filled, and cancels", async () => {
    await h.tap(await h.scrollTo(h.byId("detail.requestTour")));
    const submit = await h.byId("contact.submit");
    await submit.waitForExist({ timeout: 10000 });
    await expect(submit).not.toBeEnabled();

    await h.typeInto("contact.name", "LambdaTest User");
    await expect(submit).not.toBeEnabled();

    await h.tapId("contact.cancel");
    await h.expectGone(h.byId("contact.submit"));
    await h.expectVisible(h.byId("detail.requestTour"));
  });

  it("requests a tour, and returns to the results", async () => {
    await h.tapId("detail.requestTour");
    await h.typeInto("contact.name", "LambdaTest User");
    // The phone pad has no Return key, so the email field (which has one) goes after it.
    await h.typeInto("contact.phone", "2065550100", { keepKeyboard: true });
    await h.typeInto("contact.email", "lambdatest@example.com");
    await h.chooseFromMenuPicker("Preferred day", "Sunday");
    await h.typeInto("contact.message", "Added by the LambdaTest suite", { keepKeyboard: true });

    const submit = await h.byId("contact.submit");
    await expect(submit).toBeEnabled();
    await submit.click();

    await h.expectText("Tour requested");
    await h.expectText(ADDRESS);
    await h.tapId("tour.done");
    await h.waitForResults();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
