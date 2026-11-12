/**
 * The ledger: adding income and expense from the Dashboard's add menu, every editor validation message,
 * Cancel, editing from both the Income/Expense lists and the Dashboard strips, and delete with its
 * confirmation declined and accepted. Each write is a real request to the in-app stub server, so this spec
 * is also what produces the app's POST/PUT/DELETE MobileRequest events.
 */

const h = require("./helpers");

// Unique per run: the ledger lives on disk, so a session that keeps app data (local runs do) still
// has the previous run's records.
const RUN = Date.now().toString(36).slice(-5);
const INCOME = `LT Bonus ${RUN}`;
const EXPENSE = `LT Coffee ${RUN}`;

const recordCell = (kind, purpose) => h.byId(`record.${kind}.${purpose}`);

const firstTile = (kind) =>
  $(
    `-ios class chain:**/XCUIElementTypeCollectionView[\`name == "dashboard.strip.${kind}"\`]` +
      `/XCUIElementTypeCell[1]`
  );

async function openAddEditor(menuTitle, title) {
  await h.selectTab("Dashboard");
  await h.tapId("dashboard.add");
  await h.tap(h.byLabel(menuTitle));
  await h.expectVisible(h.byLabel(title));
}

async function fillEditor(amount, purpose, note) {
  await h.typeInto("editor.amount", amount);
  await h.typeInto("editor.purpose", purpose);
  await h.typeInto("editor.note", note);
}

async function saveAndExpectToast(toast) {
  await h.tapId("editor.save");
  await h.expectToast(toast);
}

describe("ExpensesTracker: records", () => {
  before(async () => {
    await h.signIn();
  });

  it("shows the seeded records on the Dashboard and in both lists", async () => {
    await h.selectTab("Dashboard");
    await h.expectVisible(firstTile("income"));
    await h.expectVisible(firstTile("expense"));

    await h.selectTab("Income");
    await h.expectVisible(recordCell("income", "Salary"));

    await h.selectTab("Expense");
    await h.expectVisible(recordCell("expense", "Groceries"));
  });

  it("cancels adding a record", async () => {
    await openAddEditor("Add income", "Add income");
    await h.tap(h.byLabel("Cancel"));
    await h.expectVisible(h.byId("dashboard.balance"));
  });

  it("validates every editor field", async () => {
    await openAddEditor("Add income", "Add income");

    await h.tapId("editor.save");
    await h.expectText("Amount required....");

    await h.typeInto("editor.amount", "10");
    await h.tapId("editor.save");
    await h.expectText("Purpose required....");

    await h.typeInto("editor.purpose", INCOME);
    await h.tapId("editor.save");
    await h.expectText("Note required....");

    await h.typeInto("editor.note", "Quarterly");
    await h.typeInto("editor.amount", "0");
    await h.tapId("editor.save");
    await h.expectText("Amount must be a whole number greater than zero");

    await h.tap(h.byLabel("Cancel"));
  });

  it("adds an income record", async () => {
    await openAddEditor("Add income", "Add income");
    await fillEditor("250", INCOME, "Quarterly");
    await saveAndExpectToast("Data Inserted");

    await h.selectTab("Income");
    await h.expectVisible(recordCell("income", INCOME));
  });

  it("adds an expense record", async () => {
    await openAddEditor("Add expense", "Add expense");
    await fillEditor("5", EXPENSE, "Flat white");
    await saveAndExpectToast("Data Inserted");

    await h.selectTab("Expense");
    await h.expectVisible(recordCell("expense", EXPENSE));
  });

  it("updates a record from the Income list", async () => {
    await h.selectTab("Income");
    await h.tap(recordCell("income", INCOME));
    await h.expectVisible(h.byLabel("Edit income"));

    await h.typeInto("editor.amount", "300");
    await saveAndExpectToast("DATA UPDATED");
    await h.expectVisible(recordCell("income", INCOME));
  });

  it("opens and cancels the editor from both Dashboard strips", async () => {
    await h.selectTab("Dashboard");

    await h.tap(firstTile("income"));
    await h.expectVisible(h.byLabel("Edit income"));
    await h.tap(h.byLabel("Cancel"));

    await h.tap(firstTile("expense"));
    await h.expectVisible(h.byLabel("Edit expense"));
    await h.tap(h.byLabel("Cancel"));
  });

  it("updates a record from a Dashboard strip", async () => {
    // Strips are newest first, so the first expense tile is the one added above.
    await h.selectTab("Dashboard");
    await h.tap(firstTile("expense"));
    await h.expectVisible(h.byLabel("Edit expense"));
    await h.typeInto("editor.note", "Oat flat white");
    await saveAndExpectToast("DATA UPDATED");
  });

  it("declines, then confirms, deleting each record", async () => {
    for (const [tab, kind, purpose] of [
      ["Income", "income", INCOME],
      ["Expense", "expense", EXPENSE],
    ]) {
      await h.selectTab(tab);
      await h.tap(recordCell(kind, purpose));

      await h.tapId("editor.delete");
      await h.expectText("Delete record?");
      await h.tapAlertButton("Cancel");

      await h.tapId("editor.delete");
      await h.tapAlertButton("Delete");
      await h.expectToast("Record deleted");

      await recordCell(kind, purpose).waitForExist({ timeout: 5000, reverse: true });
    }
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
