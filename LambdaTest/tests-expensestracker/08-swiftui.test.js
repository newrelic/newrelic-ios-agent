/**
 * The SwiftUI half of the app, reached from Home's "SwiftUI" bar button: the expense list (with its
 * embedded UIKit label), the detail screen for every sample expense, and the Add Expense sheet's disabled
 * Save, Cancel, category picker, and save. These screens report through the .NRMobile* SwiftUI modifiers
 * rather than the UIKit path, so this spec is what exercises the agent's SwiftUI view tracking.
 */

const h = require("./helpers");

const SAMPLES = ["Groceries", "Gas", "Streaming", "Dinner", "Electric Bill"];
const NEW_EXPENSE = "LT Lunch";

const expenseCard = (name) => h.byId(`swiftui.expense.${name}`);

async function scrollIntoView(element) {
  const el = await element;
  await el.waitForExist({ timeout: 10000 });
  if (!(await el.isDisplayed())) {
    await driver.execute("mobile: scroll", { elementId: el.elementId, toVisible: true });
  }
  return el;
}

// Day 1 of whatever month the calendar shows ("Thursday, October 1", or "Today, ..." on the 1st), so the
// step does not depend on the runner's clock agreeing with the device's.
const FIRST_OF_MONTH = "-ios predicate string:type == 'XCUIElementTypeButton' AND label MATCHES '.*, [A-Za-z]+ 1$'";
const FIRST_OF_MONTH_DETAIL = "-ios predicate string:label MATCHES '^[A-Z][a-z]{2} 1, [0-9]{4}$'";

async function pickFirstOfMonth() {
  await h.tap($("-ios class chain:**/XCUIElementTypeDatePicker/**/XCUIElementTypeButton"));
  await h.tap($(FIRST_OF_MONTH));
  await h.tap(h.byId("PopoverDismissRegion"));
  await $(FIRST_OF_MONTH).waitForExist({ timeout: 5000, reverse: true });
}

async function openDetailAndReturn(name, amount, date) {
  await (await scrollIntoView(expenseCard(name))).click();
  const amountLabel = await h.expectVisible(h.byId("swiftui.detail.amount"));
  if (amount) {
    await expect(amountLabel).toHaveAttribute("label", amount);
  }
  if (date) {
    await h.expectVisible($(date));
  }
  await h.expectVisible(h.byLabel("Expense Details"));
  await driver.back();
  await h.expectVisible(h.byId("swiftui.total"));
}

describe("ExpensesTracker: SwiftUI section", function () {
  this.timeout(180000);

  before(async () => {
    await h.signIn();
  });

  it("opens the SwiftUI expense list", async () => {
    await h.tapId("home.swiftui");
    await h.expectText("Welcome to SwiftUI!");
    await h.expectVisible(h.byId("swiftui.total"));
    await h.expectVisible(h.byId("swiftui.nativelabel"));
  });

  it("opens the detail screen for every sample expense", async () => {
    for (const name of SAMPLES) {
      await openDetailAndReturn(name);
    }
  });

  it("keeps Save disabled until name and amount are filled, and cancels", async () => {
    await h.tapId("swiftui.add");
    const save = await h.expectVisible(h.byId("swiftui.add.save"));
    await expect(save).not.toBeEnabled();

    await h.typeInto("swiftui.add.name", NEW_EXPENSE);
    await expect(save).not.toBeEnabled();

    await h.tap(h.byLabel("Cancel"));
    await h.expectVisible(h.byId("swiftui.total"));
    await expenseCard(NEW_EXPENSE).waitForExist({ timeout: 3000, reverse: true });
  });

  it("adds an expense with a category, date and description", async () => {
    await h.tapId("swiftui.add");
    await h.typeInto("swiftui.add.name", NEW_EXPENSE);
    await h.typeInto("swiftui.add.amount", "18.25");

    await h.tapId("swiftui.add.category");
    await h.tap(h.byLabel("Shopping"));

    await pickFirstOfMonth();

    await h.typeInto("swiftui.add.description", "Added by the LambdaTest suite");

    const save = await h.byId("swiftui.add.save");
    await expect(save).toBeEnabled();
    await save.click();

    await h.expectVisible(expenseCard(NEW_EXPENSE));
    await expect(h.byId("swiftui.nativelabel")).toHaveAttribute("label", expect.stringContaining("showing 6 expenses"));
  });

  it("opens the new expense's detail screen", async () => {
    await openDetailAndReturn(NEW_EXPENSE, "18.25", FIRST_OF_MONTH_DETAIL);
  });

  it("closes the SwiftUI section back to Home", async () => {
    await h.tapId("swiftui.close");
    await h.waitForHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
