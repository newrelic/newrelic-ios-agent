/**
 * "Send Unique Crash": a failed forced cast, a different Swift trap from 06-crash so the two produce
 * distinct crash fingerprints. Its own session for the same reason as 06-crash.
 */

const h = require("./helpers");

describe("ExpensesTracker: unique crash", function () {
  this.timeout(360000);

  before(async () => {
    await h.signIn();
  });

  it("crashes on a failed forced cast and reports it on relaunch", async () => {
    await h.crashAndRelaunch("Send Unique Crash");
  });
});
