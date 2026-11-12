/**
 * Text Masking (UIKit): TextMaskingViewController's sections of masked and unmasked labels, text fields and
 * text views, tagged through accessibility identifiers (nr-mask / nr-unmask, and the app's custom private /
 * public), plus mask propagation from parent views and through a table view. Session Replay is what judges
 * the masking; this spec types into fields of every kind and brings every section on screen.
 *
 * Fields are found by placeholder: their identifiers are the masking tags, shared by a whole section.
 */

const h = require("./helpers");

describe("Text Masking (UIKit) Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Text Masking", async () => {
    await h.openFromHome("Text Masking");
    await h.expectVisible(h.sel.text("Search & Credentials Fields"));
  });

  it("types into the search and credentials fields", async () => {
    await h.typeInto(h.sel.field("Search query (masked)"), "confidential search query");
    await h.typeInto(h.sel.field("Username (unmasked)"), "john.doe@example.com");
    await h.typeInto(h.sel.field("Password (masked)"), "SecureP@ssw0rd123");
    await h.typeInto(h.sel.field("Credit Card Number (masked)"), "4532-1234-5678-9012");
    await h.typeInto(h.sel.field("CVV (masked)"), "987");
  });

  it("types into the masked and unmasked fields", async () => {
    for (const section of ["Masked Fields", "Unmasked Fields"]) {
      await h.scrollTo(h.sel.text(section));
      for (let i = 1; i <= 4; i++) {
        await h.scrollTo(h.sel.text(`${section} UILabel ${i}`));
      }
      await h.typeInto(h.sel.field(`${section} UITextField 1`), `${section} input 1`);
      await h.typeInto(h.sel.field(`${section} UITextField 2`), `${section} input 2`);
      await h.typeInto(h.sel.field(`${section} UITextView 1`), `${section} notes\nsecond line`);
    }
  });

  it("types into the fields tagged with the custom private and public identifiers", async () => {
    for (const section of ["Custom Masked Fields", "Custom Unmasked Fields"]) {
      await h.scrollTo(h.sel.text(`${section} UILabel 1`));
      await h.typeInto(h.sel.field(`${section} UITextField 1`), `${section} reference 456`);
    }
  });

  it("taps the children of the masked and unmasked parent views", async () => {
    await h.scrollTo(h.sel.text("Parent-Child Relationship"));
    await h.scrollTo(h.sel.text("Masked Parent View"));
    await h.scrollAndTap(h.sel.button("Child Button 1"));
    await h.scrollTo(h.sel.text("Nested Child Label"));
    await h.scrollTo(h.sel.text("Unmasked Parent View"));
  });

  it("taps a row's button in the masked table view", async () => {
    await h.scrollTo(h.sel.text("TableView Masking Test"));
    await h.scrollTo(h.sel.text("Title 1"));
    await h.scrollAndTap(h.sel.button("Action"));
    await h.scrollTo(h.sel.text("Subtitle 3"));
  });

  it("returns to the home screen", async () => {
    await h.goBack();
    await h.waitForHome(5000);
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
