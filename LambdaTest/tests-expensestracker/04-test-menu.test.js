/**
 * The New Relic test menu (Income tab's ladybug button) and the Expense tab's one-tap reporter.
 *
 * Every one of the thirteen options is opened here. The eleven that leave the app running are run to
 * completion and checked by the toast each one shows; the two crashes and two hangs are opened and their
 * confirmation declined, because accepting them ends or freezes the session — 05-hangs, 06-crash and
 * 07-unique-crash accept them, each in a session of its own.
 */

const h = require("./helpers");

async function runOption(title, toast, timeout) {
  await h.openTestMenu();
  await h.tapSheetOption(title);
  if (toast) await h.expectToast(toast, timeout);
}

async function declineConfirmation(title) {
  await h.openTestMenu();
  await h.tapSheetOption(title);
  await h.expectText("Warning");
  await h.tapAlertButton("Cancel");
}

describe("ExpensesTracker: New Relic test menu", function () {
  this.timeout(180000);

  before(async () => {
    await h.signIn();
  });

  it("opens and cancels the menu", async () => {
    await h.openTestMenu();
    await h.dismissSheet();
    await h.expectVisible(h.byId("income.testmenu"));
  });

  it("sends a handled exception", async () => {
    await runOption("Send Handled Exception", "Sent handled exception to New Relic");
  });

  it("sends a custom error event", async () => {
    await runOption("Send Custom Error Event", "Sent custom error event to New Relic");
  });

  it("sends a performance event", async () => {
    await runOption("Send Performance Event", "Sent performance event to New Relic");
  });

  it("sends a unique handled exception", async () => {
    await runOption("Send Unique Handled Exception", "Unique handled exception to New Relic");
  });

  it("simulates a unique network failure", async () => {
    await runOption(
      "Simulate Unique Request Error – Network Failure",
      "Simulated unique request error – network failure"
    );
  });

  it("simulates a unique HTTP error", async () => {
    await runOption("Simulate Unique Request Error – HTTP Error", "Simulated unique request error – HTTP 404");
  });

  it("simulates a repeating network failure", async () => {
    await runOption("Simulate Multiple Request Error – Network Failure", "Simulated request error – network failure");
  });

  it("simulates a repeating HTTP error", async () => {
    await runOption("Simulate Multiple Request Error – HTTP Error", "Simulated request error – HTTP 500");
  });

  it("cancels the slow-network prompt", async () => {
    await runOption("Simulate Slow Network");
    await h.expectText("This will issue a slow request");
    await h.tapAlertButton("Cancel");
  });

  for (const seconds of [5, 10]) {
    it(`issues a ${seconds}-second slow request`, async () => {
      await runOption("Simulate Slow Network");
      await h.tapAlertButton(`${seconds} seconds`);
      await h.expectText(`Simulating a ${seconds * 1000}ms request`);
      await h.expectToast("Slow request finished after", seconds * 1000 + 20000);
    });
  }

  it("declines both crash confirmations", async () => {
    await declineConfirmation("Trigger Crash (Unhandled Exception)");
    await declineConfirmation("Send Unique Crash");
  });

  it("declines both hang confirmations", async () => {
    await declineConfirmation("Simulate Main-Thread Hang");
    await declineConfirmation("Simulate Unique Main-Thread Hang");
  });

  it("sends a handled exception and custom event from the Expense tab", async () => {
    await h.selectTab("Expense");
    await h.tapId("expense.testmenu");
    await h.expectToast("Handled exception sent to New Relic");
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
