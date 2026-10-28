/**
 * SwiftUI Text Fields: TextFieldsView's Form with a TextField, a TextEditor and a SecureField, and a Validate
 * button that raises an alert while either required field is empty.
 */

const h = require("./helpers");

describe("SwiftUI Text Fields Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Text Fields from the SwiftUI list", async () => {
    await h.openSwiftUIScreen("Text Fields");
    await h.expectVisible(h.sel.text("Single Line Text Field"));
  });

  it("rejects validation while the fields are empty", async () => {
    await h.scrollAndTap(h.sel.button("Validate Input"));
    await h.expectVisible(h.sel.text("Validation Error"));
    await h.tap(h.sel.button("OK"));
    await h.expectGone(h.sel.text("Validation Error"));
  });

  it("types into every field and validates", async () => {
    // Found by placeholder until it has text, then by the text.
    await h.typeInto(h.sel.field("Enter single line text"), "single line input");
    await (await $(h.sel.field("single line input"))).waitForExist({ timeout: 5000 });

    const editor = await h.scrollTo('-ios class chain:**/XCUIElementTypeTextView');
    await editor.click();
    await editor.addValue("multi-line input");

    await h.typeInto(h.sel.field("Enter secure text"), "secret");

    await h.scrollAndTap(h.sel.button("Validate Input"));
    await h.expectGone(h.sel.text("Validation Error"), 3000);
  });

  it("returns to the home screen", async () => {
    await h.goHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
