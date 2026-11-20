/**
 * The Inbox: every message thread opened and closed (each reports under a dynamic name, "Message Thread —
 * <correspondent>"), and the composer's disabled Send, enabled Send and cleared draft.
 */

const h = require("./helpers");

const THREADS = {
  "T-1": "Dana Whitfield",
  "T-2": "Marcus Oyelaran",
  "T-3": "Priya Raghunathan",
  "T-4": "Terrence Okafor",
};

describe("HomeSearch: Inbox", () => {
  before(async () => {
    await h.waitForResults();
    await h.selectTab("Inbox");
  });

  it("lists every thread", async () => {
    for (const id of Object.keys(THREADS)) {
      await h.expectVisible(h.byId(`inbox.thread.${id}`));
    }
  });

  it("opens every thread and returns to the Inbox", async () => {
    for (const [id, correspondent] of Object.entries(THREADS)) {
      await h.tapId(`inbox.thread.${id}`);
      await h.expectVisible($(`-ios class chain:**/XCUIElementTypeNavigationBar[\`name == "${correspondent}"\`]`));
      await h.goBack();
      await h.expectVisible(h.byId(`inbox.thread.${id}`));
    }
  });

  it("sends a message only once there is something to send", async () => {
    await h.tapId("inbox.thread.T-1");
    const send = await h.expectVisible(h.byId("thread.send"));
    await expect(send).not.toBeEnabled();

    await h.typeInto("thread.draft", "Saturday at 11 works", { keepKeyboard: true });
    await expect(send).toBeEnabled();
    await send.click();

    // Sending is local only: the draft clears and Send disables again.
    await expect(send).not.toBeEnabled();
    await expect(h.byId("thread.draft")).toHaveAttribute("value", "Message Dana Whitfield");
    await h.goBack();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
