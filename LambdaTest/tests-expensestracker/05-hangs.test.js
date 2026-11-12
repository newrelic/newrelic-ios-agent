/**
 * Both main-thread hangs, accepted. Each blocks the main thread for ten seconds and then recovers, which is
 * what the agent's hang detection should report. Kept out of 04-test-menu so a slow hang cannot eat that
 * spec's time budget.
 */

const h = require("./helpers");

async function runHang(title) {
  await h.openTestMenu();
  await h.tapSheetOption(title);
  await h.tapAlertButton("Yes");
  // The app is unresponsive for ten seconds; the toast after it is the proof it came back.
  await h.expectText("Main thread released", 40000);
}

describe("ExpensesTracker: main-thread hangs", function () {
  this.timeout(180000);

  before(async () => {
    await h.signIn();
  });

  it("recovers from a main-thread hang", async () => {
    await runHang("Simulate Main-Thread Hang");
  });

  it("recovers from a unique main-thread hang", async () => {
    await runHang("Simulate Unique Main-Thread Hang");
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
