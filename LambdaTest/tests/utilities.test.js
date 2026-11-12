/**
 * Utilities (UIKit): UtilitiesViewController's table of agent API calls (breadcrumbs, attributes, errors, user
 * ids, custom events, interaction traces, network requests, logs). None of them changes the screen; what they
 * produce is agent data, which the harvest at the end sends.
 *
 * Not tapped: "Crash Now!", "Shut down New Relic Agent" (either ends the data this run can send), and the
 * random user-id cycling, which keeps changing the user id after the spec is done.
 */

const h = require("./helpers");

const GROUPS = {
  "breadcrumbs and attributes": ["Add Valid Breadcrumb", "Add Invalid Breadcrumb", "Set Attributes", "Remove Attributes"],
  errors: ["Record Error", "Record Handled Exception", "Record JavaScript Error"],
  "user ids": ["Set UserID to testID", "Set UserID to Bob", "Set UserID to null"],
  "events and interaction traces": ["Make 100 events", "Start Interaction Trace", "End Interaction Trace"],
  "network requests": [
    "Notice Network Request",
    "Notice Network Failure",
    "Notice Flutter-style DT Request (200)",
    "Notice Flutter-style DT Request (403)",
    "Notice Network Request w headers/params",
    "URLSession dataTask",
  ],
  "session and event attributes": ["Try Collection Session Attributes", "Try Collection Event Attributes"],
  logs: ["Test System Logs", "Test Log Dict", "Test Log Error", "Test Log Attributes", "Make 100 Logs", "Make 100 Special Character Logs"],
};

describe("Utilities Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Utilities", async () => {
    await h.openFromHome("Utilities");
    await h.expectVisible(h.sel.text("Add Valid Breadcrumb"));
  });

  for (const [group, rows] of Object.entries(GROUPS)) {
    it(`calls the ${group} APIs`, async () => {
      for (const row of rows) {
        await h.scrollAndTap(h.sel.text(row));
      }
    });
  }

  it("returns to the home screen", async () => {
    await h.scrollTo(h.sel.text("Crash Now!"));
    await h.goBack();
    await h.waitForHome(5000);
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
