/**
 * The SwiftUI Elements list's control screens: Pickers, Toggles, Sliders, Steppers, Date Pickers, Progress
 * Views, Segmented Controls, Scroll Views, Stacks and Grids (Buttons has its own spec). Each block opens its
 * screen from the home screen, so one failure does not strand the blocks after it, and checks each
 * interaction by the state it changes.
 */

const h = require("./helpers");

/** The last displayed match: a menu's rows are added to the tree after the controls it covers. */
async function lastDisplayed(selector) {
  const matches = await $$(selector);
  for (let i = matches.length - 1; i >= 0; i--) {
    if (await matches[i].isDisplayed()) return matches[i];
  }
  throw new Error(`Nothing displayed matches ${selector}`);
}

describe("SwiftUI Pickers Screen", () => {
  it("selects each segment of the segmented picker", async () => {
    await h.openSwiftUIScreen("Pickers");
    await h.expectVisible(h.sel.text("Pickers Example"));
    for (const option of ["Option 2", "Option 3", "Option 1"]) {
      await h.tap(h.sel.button(option));
      await h.expectVisible(h.sel.text(`Selected option: ${option}`));
    }
  });

  it("chooses from the menu picker", async () => {
    await h.tap(h.sel.button("Custom Picker, Option 1"));
    await driver.pause(500);
    await (await lastDisplayed(h.sel.button("Option 3"))).click();
    await h.expectVisible(h.sel.text("Custom Picker selection: Option 3"));
  });
});

describe("SwiftUI Toggles Screen", () => {
  const STANDARD = ["Toggle is Off", "Another Toggle is On"];
  const CUSTOM = ["Custom Style", "Pill-Shaped Thumb", "Square Toggle", "Colorful Gradient"];

  it("opens Toggles", async () => {
    await h.openSwiftUIScreen("Toggles");
    await h.expectVisible(h.sel.text("Toggle Examples"));
  });

  it("flips the standard toggles, whose labels track their state", async () => {
    await h.tap(h.sel.switch("Toggle is Off"));
    await h.expectVisible(h.sel.switch("Toggle is On"));
    await h.expectVisible(h.sel.text("Standard: On ✓"));

    await h.tap(h.sel.switch("Another Toggle is On"));
    await h.expectVisible(h.sel.switch("Another Toggle is Off"));
    await h.expectVisible(h.sel.text("Blue: Off"));

    // And back, so the screen ends as it started.
    await h.tap(h.sel.switch("Toggle is On"));
    await h.tap(h.sel.switch("Another Toggle is Off"));
    for (const label of STANDARD) {
      await h.expectVisible(h.sel.switch(label));
    }
  });

  it("flips each custom-styled toggle and back", async () => {
    // A custom ToggleStyle takes taps only on the control it draws at the row's trailing edge.
    for (const label of CUSTOM) {
      const toggle = await h.scrollTo(h.sel.switch(label));
      const before = await toggle.getAttribute("value");
      const after = before === "1" ? "0" : "1";
      await h.tapTrailing(h.sel.switch(label));
      await expect(toggle).toHaveAttribute("value", after);
      await h.tapTrailing(h.sel.switch(label));
      await expect(toggle).toHaveAttribute("value", before);
    }
  });
});

describe("SwiftUI Sliders Screen", () => {
  it("moves both sliders", async () => {
    await h.openSwiftUIScreen("Sliders");
    await h.expectVisible(h.sel.text("Continuous Slider"));
    const [continuous, discrete] = await $$('-ios class chain:**/XCUIElementTypeSlider');

    await h.expectVisible(h.sel.text("Value: 50"));
    await h.slide(continuous, 0.5, 0.9);
    await h.expectGone(h.sel.text("Value: 50"));

    await h.expectVisible(h.sel.text("Value: 1"));
    await h.slide(discrete, 0, 1);
    await h.expectVisible(h.sel.text("Value: 5"));
  });
});

describe("SwiftUI Steppers Screen", () => {
  it("increments, decrements, resets and adds ten", async () => {
    await h.openSwiftUIScreen("Steppers");
    await h.expectVisible(h.sel.text("Current Value: 0"));

    for (let i = 0; i < 3; i++) {
      await h.tap("~Increment");
    }
    await h.expectVisible(h.sel.text("Current Value: 3"));
    await h.tap("~Decrement");
    await h.expectVisible(h.sel.text("Current Value: 2"));

    await h.tap(h.sel.button("Reset"));
    await h.expectVisible(h.sel.text("Current Value: 0"));

    await h.tap(h.sel.button("Increase by 10"));
    await h.tap(h.sel.button("Increase by 10"));
    await h.expectVisible(h.sel.text("Current Value: 20"));
  });
});

describe("SwiftUI Date Pickers Screen", () => {
  it("pages the calendar and reaches the time wheel", async () => {
    await h.openSwiftUIScreen("Date Pickers");
    const month = await h.scrollTo("~DatePicker.Show");
    const shown = await month.getAttribute("value");
    await h.tap("~DatePicker.NextMonth");
    await expect(month).not.toHaveAttribute("value", shown);
    await h.tap("~DatePicker.PreviousMonth");
    await expect(month).toHaveAttribute("value", shown);

    await h.scrollTo('-ios predicate string:type == "XCUIElementTypeStaticText" AND label BEGINSWITH "Selected Time: "');
  });
});

describe("SwiftUI Progress Views Screen", () => {
  it("starts and stops loading", async () => {
    await h.openSwiftUIScreen("Progress Views");
    await h.expectVisible('-ios class chain:**/XCUIElementTypeProgressIndicator');
    await h.tap(h.sel.button("Start Loading"));
    await h.tap(h.sel.button("Stop Loading"));
    await h.expectVisible(h.sel.button("Start Loading"));
  });
});

describe("SwiftUI Segmented Controls Screen", () => {
  it("selects each segment", async () => {
    await h.openSwiftUIScreen("Segmented Controls");
    for (const option of ["Option 2", "Option 3", "Option 1"]) {
      await h.tap(h.sel.button(option));
      await h.expectVisible(h.sel.text(`Selected Segment: ${option}`));
    }
  });
});

describe("SwiftUI Scroll Views Screen", () => {
  it("scrolls to the last item", async () => {
    await h.openSwiftUIScreen("Scroll Views");
    await h.expectVisible(h.sel.text("Item 0"));
    await h.scrollTo(h.sel.text("Item 49"));
  });

  it("scrolls back to the first item", async () => {
    await h.scrollTo(h.sel.text("Item 0"));
  });
});

describe("SwiftUI Stacks Screen", () => {
  it("shows the VStack, HStack and ZStack examples", async () => {
    await h.openSwiftUIScreen("Stacks");
    for (const label of ["VStack Example", "Item 1", "HStack Example", "Item C", "ZStack Example", "Overlay Text"]) {
      await h.scrollTo(h.sel.text(label));
    }
  });
});

describe("SwiftUI Grids Screen", () => {
  it("scrolls to the end of the grid", async () => {
    await h.openSwiftUIScreen("Grids");
    await h.expectVisible(h.sel.text("Item 1"));
    await h.scrollTo(h.sel.text("Item 30"));
  });

  it("returns to the home screen", async () => {
    await h.goHome();
  });

  it("flushes the harvest", async () => {
    await h.flushHarvest();
  });
});
