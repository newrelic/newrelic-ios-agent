/**
 * SwiftUI Masking: MaskingView's permutations of masked and unmasked elements (direct, inherited from a parent,
 * overridden by a child, deeply nested, reused). Session Replay is what judges the masking; this spec puts text
 * into every field and brings every section on screen so the replay has all of them to record.
 */

const h = require("./helpers");

const SECTIONS = [
  "Direct Elements (Single Controls)",
  "Parent Masked → Children Inherit (no explicit child id)",
  "Parent Masked → Child Override Unmasked",
  "Parent Unmasked → Child Explicit Masked",
  "Deep Nesting (Mixed Overrides)",
  "Sibling Mix (Explicit IDs on Each)",
  "Reuse In Subview (Parameter Controlled)",
  "NavigationLink Within Masked Parent",
];

const FIELDS = [
  ["Masked TextField", "masked direct 123"],
  ["Unmasked TextField", "unmasked direct 456"],
  ["Implicit masked inheritance?", "Sensitive inherited data 123"],
  ["Child unmasked override", "Public override text 456"],
  ["Masked inside unmasked parent", "Secret in public 789"],
  ["Deep masked field", "deep secret 000"],
];

describe("SwiftUI Masking Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Masking from the SwiftUI list", async () => {
    await h.openSwiftUIScreen("Masking");
    await h.expectVisible(h.sel.text("Masking Permutations"));
  });

  it("types into every field", async () => {
    for (const [placeholder, text] of FIELDS) {
      await h.typeInto(h.sel.field(placeholder), text);
      // Found by placeholder until it has text, then by the text. Exists rather than visible: the keyboard
      // that typing raised can cover it.
      await (await $(h.sel.field(text))).waitForExist({ timeout: 5000 });
    }
  });

  it("brings every section on screen", async () => {
    for (const section of SECTIONS) {
      await h.scrollTo(h.sel.text(section));
    }
    for (const label of ["Child Label A", "Inherited Masked Label", "Level 3 Explicit Masked", "Reusable Row (Masked)"]) {
      await h.scrollTo(h.sel.text(label));
    }
  });

  it("follows the NavigationLink inside the masked parent and back", async () => {
    await h.scrollAndTap(h.sel.button("Go To TextFieldsView (inherits parent)"));
    await h.expectVisible(h.sel.text("Single Line Text Field"));
    await h.goBack();
    await h.scrollTo(h.sel.button("Go To TextFieldsView (inherits parent)"));
  });

  it("returns to the home screen", async () => {
    await h.goHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
