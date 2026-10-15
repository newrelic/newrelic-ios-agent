/**
 * "Trigger Crash (Unhandled Exception)": an out-of-bounds array subscript, a real Swift trap. Runs in its
 * own session because it ends the process; the relaunch afterwards is what uploads the crash report.
 */

const h = require("./helpers");

describe("ExpensesTracker: crash", function () {
  this.timeout(360000);

  before(async () => {
    await h.signIn();
  });

  it("crashes on an out-of-bounds subscript and reports it on relaunch", async () => {
    await h.crashAndRelaunch("Trigger Crash (Unhandled Exception)");
  });
});
