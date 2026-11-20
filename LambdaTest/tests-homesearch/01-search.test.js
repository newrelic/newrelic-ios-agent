/**
 * The Search tab: the results list loading from the stub server, the search field, every sort order, and
 * the filter sheet (Cancel, Apply, the badge on the Filters button, Reset). Filters is presented as a
 * sheet, so it is also the first modal view the agent sees.
 */

const h = require("./helpers");

// First row for each sort order, from the bundled fixture.
const FIRST_BY_SORT = {
  "Price ↑": "L-1005",
  "Price ↓": "L-1009",
  "Sq Ft": "L-1009",
  Newest: "L-1006",
};

async function sortBy(order) {
  await h.tapId("search.sort");
  await h.tap(h.button(order));
  await expect(h.firstResult()).toHaveAttribute("name", `search.listing.${FIRST_BY_SORT[order]}`);
}

async function openFilters() {
  await h.tapId("search.filters");
  await h.expectVisible(h.byId("filters.apply"));
}

describe("HomeSearch: Search", () => {
  before(async () => {
    await h.waitForResults();
  });

  it("narrows the results from the search field, and clears it", async () => {
    const field = await h.searchField();
    await field.click();
    await field.setValue("Fremont");
    await h.expectResultCount(1);
    await h.expectVisible(h.byId("search.listing.L-1001"));

    await field.clearValue();
    await h.expectResultCount(h.TOTAL_LISTINGS);
    const close = await h.button("Close");
    if (await close.isExisting()) await close.click();
    await h.dismissKeyboard();
  });

  it("sorts by every order", async () => {
    for (const order of Object.keys(FIRST_BY_SORT)) {
      await sortBy(order);
    }
  });

  it("leaves the results alone when the filter sheet is cancelled", async () => {
    await openFilters();
    await h.tap(h.toggleControl("filters.newOnly"));
    await h.tapId("filters.cancel");
    await h.expectGone(h.byId("filters.apply"));
    await h.expectResultCount(h.TOTAL_LISTINGS);
  });

  it("applies filters and badges the Filters button", async () => {
    await openFilters();
    await h.tap(h.toggleControl("filters.newOnly"));
    await h.tapId("filters.apply");
    await h.expectResultCount(3);
    await expect(h.byId("search.filters")).toHaveAttribute("value", "1 active");

    // Reopening shows the applied state; stack a bedroom minimum on top of it.
    await openFilters();
    await expect(h.byId("filters.newOnly")).toHaveAttribute("value", "1");
    for (let i = 0; i < 4; i++) {
      await h.tapId("filters.beds-Increment");
    }
    await expect(h.byId("filters.beds")).toHaveAttribute("label", "Beds: 4+");
    await h.tapId("filters.apply");
    await h.expectResultCount(1);
    await h.expectVisible(h.byId("search.listing.L-1006"));
    await expect(h.byId("search.filters")).toHaveAttribute("value", "2 active");
  });

  it("resets every filter", async () => {
    await openFilters();
    // The last row of the Form, below the fold on a real iPhone 17.
    await h.tap(await h.scrollTo(h.byId("filters.reset")));
    await expect(h.byId("filters.reset")).not.toBeEnabled();
    await h.tapId("filters.apply");
    await h.expectResultCount(h.TOTAL_LISTINGS);
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
