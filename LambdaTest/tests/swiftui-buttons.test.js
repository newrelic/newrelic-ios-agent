/**
 * SwiftUI Buttons: ButtonsView's counter button, a button that toggles its own title, a custom-styled button
 * and an icon-and-text button. Each tap is checked by the state it changes where the screen shows one.
 */

const h = require("./helpers");

describe("SwiftUI Buttons Screen", () => {
  before(async () => {
    await h.waitForHome();
  });

  it("opens Buttons from the SwiftUI list", async () => {
    await h.openSwiftUIScreen("Buttons");
    await h.expectVisible(h.sel.text("Buttons Demo"));
    await h.expectVisible(h.sel.text("Button pressed 0 times"));
  });

  it("counts presses of Press Me", async () => {
    for (let i = 0; i < 3; i++) {
      await h.tap(h.sel.button("Press Me"));
    }
    await h.expectVisible(h.sel.text("Button pressed 3 times"));
  });

  it("flips the toggle button's title both ways", async () => {
    await h.tap(h.sel.button("Toggle is OFF"));
    await h.tap(h.sel.button("Toggle is ON"));
    await h.expectVisible(h.sel.button("Toggle is OFF"));
  });

  it("taps the custom-styled and star buttons", async () => {
    await h.tap(h.sel.button("Custom Styled Button"));
    await h.tap(h.sel.button("Star Button"));
    await h.expectVisible('-ios predicate string:type == "XCUIElementTypeImage" AND name == "star.fill"');
  });

  it("returns to the home screen", async () => {
    await h.goHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
