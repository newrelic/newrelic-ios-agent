/**
 * The Home shell: all three tabs from the tab bar, the side menu opened and dismissed each way it can be
 * (menu button, dimmed overlay, choosing a destination), and every side-menu destination.
 */

const h = require("./helpers");

describe("ExpensesTracker: Home navigation", () => {
  before(async () => {
    await h.signIn();
  });

  it("switches between every tab from the tab bar", async () => {
    await h.selectTab("Income");
    await h.expectVisible(h.byId("income.total"));

    await h.selectTab("Expense");
    await h.expectVisible(h.byId("expense.total"));

    await h.selectTab("Dashboard");
    await h.expectVisible(h.byId("dashboard.balance"));
    await h.expectVisible(h.byId("dashboard.total.income"));
    await h.expectVisible(h.byId("dashboard.total.expense"));
  });

  it("closes the side menu from the menu button", async () => {
    await h.openSideMenu();
    await h.tapId("home.menu");
    await h.byId("sidemenu.dashboard").waitForDisplayed({ timeout: 5000, reverse: true });
  });

  it("closes the side menu by tapping the dimmed overlay", async () => {
    await h.openSideMenu();
    // The drawer is 280pt wide; anywhere to its right is the overlay.
    const { width, height } = await driver.getWindowSize();
    await driver.execute("mobile: tap", { x: width - 30, y: Math.round(height / 2) });
    await h.byId("sidemenu.dashboard").waitForDisplayed({ timeout: 5000, reverse: true });
  });

  it("reaches every tab from the side menu", async () => {
    await h.openSideMenu();
    await h.tapId("sidemenu.income");
    await h.expectVisible(h.byId("income.total"));

    await h.openSideMenu();
    await h.tapId("sidemenu.expense");
    await h.expectVisible(h.byId("expense.total"));

    await h.openSideMenu();
    await h.tapId("sidemenu.dashboard");
    await h.expectVisible(h.byId("dashboard.balance"));
  });

  it("declines Logout from the side menu", async () => {
    await h.openSideMenu();
    await h.tapId("sidemenu.logout");
    await h.tapAlertButton("No");
    await h.waitForHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
