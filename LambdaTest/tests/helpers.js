/**
 * Shared steps for the NRTestApp suite.
 *
 * Every spec file runs in its own Appium session (and so its own fresh install), so each starts from the UIKit
 * home screen and ends with flushHarvest().
 *
 * Selectors use labels and types, not accessibility identifiers. In NRTestApp most identifiers are Session
 * Replay masking directives ("nr-mask", "nr-unmask", "private", "public"), so an element's name is often one of
 * those and `~<its text>` cannot find it. Text and search fields have no label at all; they are found by the
 * placeholder XCUITest reports as their value.
 */

const quote = (text) => text.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

const predicate = (expression) => `-ios predicate string:${expression}`;

const ofType = (type, label) => predicate(`type == "XCUIElementType${type}" AND label == "${quote(label)}"`);

/** Selector strings rather than elements, so that each lookup re-runs the query after a scroll. */
const sel = {
  label: (label) => predicate(`label == "${quote(label)}"`),
  text: (label) => ofType("StaticText", label),
  button: (label) => ofType("Button", label),
  switch: (label) => ofType("Switch", label),
  /** A text field, search field or text view, by the placeholder or text it shows. */
  field: (value) =>
    predicate(
      `type IN {"XCUIElementTypeTextField", "XCUIElementTypeSecureTextField", "XCUIElementTypeSearchField", ` +
        `"XCUIElementTypeTextView"} AND value == "${quote(value)}"`
    ),
};

/** The UIKit home screen's unmasked greeting, which only that screen shows. */
const HOME = sel.text("Hello, World");

/** The strip at the bottom of the screen kept clear of taps and drags. */
const HOME_INDICATOR = 40;

async function rectOf(el) {
  return driver.getElementRect(el.elementId);
}

/**
 * The part of the screen that scrolls, minus whatever the keyboard covers, and the scroller itself. A drag is
 * sized to it: the home screen's table only gets the bottom ~350pt, and a full-screen swipe carries its rows
 * from below the fold to above its top edge in one go, where they are recycled before they can be found.
 */
async function viewport() {
  const window = await driver.getWindowRect();
  let best = { x: 0, y: 0, width: window.width, height: window.height, scroller: null };
  let bestArea = 0;
  const scrollers = await $$(
    predicate('type IN {"XCUIElementTypeTable", "XCUIElementTypeCollectionView", "XCUIElementTypeScrollView"}')
  );
  for (const scroller of scrollers) {
    if (!(await scroller.isDisplayed())) continue;
    const rect = await rectOf(scroller);
    const top = Math.max(rect.y, 0);
    // A table can run under the home indicator, where a tap does not reach the row.
    const bottom = Math.min(rect.y + rect.height, window.height - HOME_INDICATOR);
    const area = rect.width * (bottom - top);
    if (area > bestArea) {
      bestArea = area;
      best = { x: rect.x, y: top, width: rect.width, height: bottom - top, scroller };
      // Tables and collection views (SwiftUI Lists included) only keep the cells near the screen.
      best.cellBased = (await scroller.getAttribute("type")) !== "XCUIElementTypeScrollView";
    }
  }
  // SwiftUI content scrolls under the navigation bars (UIKit's and the NavigationView's), where a tap lands
  // on the bar instead.
  for (const bar of await $$("-ios class chain:**/XCUIElementTypeNavigationBar")) {
    if (!(await bar.isDisplayed())) continue;
    const rect = await rectOf(bar);
    const bottom = rect.y + rect.height;
    if (bottom > best.y && bottom < best.y + best.height) {
      best.height -= bottom - best.y;
      best.y = bottom;
    }
  }
  const keyboard = await $("-ios class chain:**/XCUIElementTypeKeyboard");
  if (await keyboard.isExisting()) {
    const { y } = await rectOf(keyboard);
    best.height = Math.min(best.height, y - best.y);
  }
  return best;
}

/**
 * The first text inside the viewport, with its position, or null if there is none. It moves with the
 * content, so an unchanged mark after a drag means the content was already at that end. Text outside the
 * viewport will not do: a table keeps recycled cells in the tree at stale positions, and the label is part of
 * the mark because a recycled cell can come back at the same place showing another row.
 */
async function contentMark(view) {
  if (!view.scroller) return null;
  const texts = await view.scroller.$$("-ios class chain:**/XCUIElementTypeStaticText");
  for (const text of texts.slice(0, 25)) {
    const rect = await rectOf(text);
    if (rect.y >= view.y && rect.y + rect.height <= view.y + view.height) {
      return `${text.elementId}|${await text.getAttribute("label")}|${rect.y}`;
    }
  }
  return null;
}

/**
 * A slow touch drag over 60% of the viewport, held before release so the content does not coast on (at 400ms
 * a drag carries a SwiftUI list 60% further than the finger went; at 800ms it stops where the finger does). Unlike
 * `mobile: scroll`, which flings about a page, it moves a known distance, and it does not focus the text field
 * it starts on. With checkEnd, returns false when the content did not move, i.e. it was already at that end;
 * the check costs a few lookups, so scrollTo only asks for it while the target is not in the tree.
 */
async function drag(direction, area, checkEnd = false) {
  const view = area || (await viewport());
  const x = Math.round(view.x + view.width / 2);
  const low = Math.round(view.y + view.height * 0.8);
  const high = Math.round(view.y + view.height * 0.2);
  const [from, to] = direction === "down" ? [low, high] : [high, low];
  const before = checkEnd ? await contentMark(view) : null;
  await driver
    .action("pointer", { parameters: { pointerType: "touch" } })
    .move({ x, y: from })
    .down()
    .move({ duration: 800, x, y: to })
    .pause(300)
    .up()
    .perform();
  await driver.pause(200);
  return before === null || before !== (await contentMark(view));
}

/** Taps the status bar, which scrolls the screen's scroll view back to its top. */
async function scrollToTop() {
  const { width } = await driver.getWindowRect();
  await driver.execute("mobile: tap", { x: Math.round(width / 2), y: 5 });
  await driver.pause(1000);
}

/** Whether an element is still in the same place a moment later. */
async function isAtRest(el) {
  const before = await rectOf(el);
  await driver.pause(300);
  const after = await rectOf(el);
  return before.x === after.x && before.y === after.y;
}

/**
 * How far inside the viewport an element has to be. A row scrolled up against a table's top edge is reported
 * clipped to it, and a tap at the middle of that sliver does not select the row.
 */
const EDGE = 10;

/** Where an element sits relative to the viewport: "above", "below", "inside", or "missing". */
async function placement(selector, view) {
  // One lookup: checking a $() result with isExisting() re-runs the query, and an element that appears in
  // between comes back without an id.
  const [el] = await $$(selector);
  if (!el) return { where: "missing" };
  const rect = await rectOf(el);
  if (rect.y < view.y + EDGE) return { el, rect, where: "above" };
  if (rect.y + Math.min(rect.height, view.height - 2 * EDGE) > view.y + view.height - EDGE) {
    return { el, rect, where: "below" };
  }
  return { el, rect, where: "inside" };
}

/**
 * Scrolls until the element is inside the viewport, and returns it. An element already in the tree is
 * scrolled toward, until it gets there or stops moving because the content is at its end. One that is not
 * (a list's rows only exist near the screen) is searched for from the top of the list down, and then back up
 * should the jump to the top not have happened.
 */
async function scrollTo(selector, maxDrags = 25) {
  const view = await viewport();
  let searching = "down";
  let lastY = null;
  let jumpedToTop = false;
  for (let i = 0; i < maxDrags; i++) {
    try {
      let { el, rect, where } = await placement(selector, view);
      // In a table or collection view, a hidden match is a recycled cell left in the tree at a stale position;
      // the row itself is still to be found. A plain ScrollView keeps its off-screen content where it is.
      if (view.cellBased && where !== "inside" && where !== "missing" && !(await el.isDisplayed())) {
        where = "missing";
      }
      // A tap on a list that is still settling only stops it, so wait until the element has come to rest.
      if (where === "inside") {
        if (await isAtRest(el)) return el;
        continue;
      }
      // A screen with nothing to scroll: what is displayed is as far as it goes.
      if (!view.scroller && where !== "missing" && (await el.isDisplayed())) return el;

      // Dragged toward it last time and it did not move. Displayed, it is as close as the content's end allows;
      // hidden, it is out of reach where it is, so look elsewhere.
      const stuck = where !== "missing" && lastY === rect.y;
      if (stuck && (await el.isDisplayed())) return el;

      if (where === "missing" && view.cellBased && !jumpedToTop) {
        // A list keeps its scroll position when a pushed screen is popped, so the row may be above or below.
        jumpedToTop = true;
        await scrollToTop();
        continue;
      }
      if (where === "missing" || stuck) {
        lastY = null;
        if (!(await drag(searching, view, true))) {
          if (searching === "up") break;
          searching = "up";
        }
        continue;
      }
      lastY = rect.y;
      // "below" means the content has to move up, which is a downward scroll.
      await drag(where === "below" ? "down" : "up", view);
    } catch (err) {
      // A table that reloads (a new page of rows, say) replaces the cell that was just looked up.
      if (!/stale element/i.test(err.message)) throw err;
      lastY = null;
    }
  }
  throw new Error(`Could not scroll ${selector} into view`);
}

async function tap(selector, timeout = 10000) {
  const el = await $(selector);
  await el.waitForDisplayed({ timeout });
  await el.click();
  return el;
}

/** Scrolls to an element and taps it, finding it again if a table recycles its cell in between. */
async function scrollAndTap(selector) {
  for (let attempt = 1; ; attempt++) {
    const el = await scrollTo(selector);
    try {
      await el.click();
      return el;
    } catch (err) {
      if (attempt === 3 || !/stale element/i.test(err.message)) throw err;
    }
  }
}

/** Taps near an element's trailing edge, where a custom-styled Toggle draws the control that takes taps. */
async function tapTrailing(selector, inset = 25) {
  const el = await scrollTo(selector);
  const rect = await rectOf(el);
  await driver.execute("mobile: tap", { x: Math.round(rect.x + rect.width - inset), y: Math.round(rect.y + rect.height / 2) });
  return el;
}

/** Drags a slider's thumb from one position to another, each a fraction of the track (0 to 1). */
async function slide(el, from, to) {
  const rect = await rectOf(el);
  // The thumb's centre travels between one thumb radius in from either end.
  const radius = Math.min(14, rect.width / 4);
  const at = (fraction) => Math.round(rect.x + radius + (rect.width - 2 * radius) * fraction);
  const y = Math.round(rect.y + rect.height / 2);
  await driver
    .action("pointer", { parameters: { pointerType: "touch" } })
    .move({ x: at(from), y })
    .down()
    .move({ duration: 500, x: at(to), y })
    .up()
    .perform();
}

async function expectVisible(selector, timeout = 10000) {
  const el = await $(selector);
  await el.waitForDisplayed({ timeout });
  return el;
}

async function expectGone(selector, timeout = 5000) {
  await (await $(selector)).waitForExist({ timeout, reverse: true });
}

/** Taps a field, types into it, and leaves the keyboard up; viewport() keeps later targets above it. */
async function typeInto(selector, text) {
  const field = await scrollTo(selector);
  await field.click();
  await field.addValue(text);
  return field;
}

/**
 * Pops one screen. SwiftUI screens here sit in a NavigationView inside the UIKit navigation controller, so a
 * screen can show two or three back buttons; the lowest one belongs to the innermost stack.
 */
async function goBack() {
  let innermost = null;
  let innermostY = -1;
  for (const el of await $$("~BackButton")) {
    if (!(await el.isDisplayed())) continue;
    const { y } = await rectOf(el);
    if (y > innermostY) {
      innermost = el;
      innermostY = y;
    }
  }
  if (!innermost) throw new Error("No back button on screen");
  await innermost.click();
  await driver.pause(500);
}

async function waitForHome(timeout = 30000) {
  await expectVisible(HOME, timeout);
}

async function goHome() {
  for (let i = 0; i < 5; i++) {
    if (await (await $(HOME)).isDisplayed()) return;
    await goBack();
  }
  await waitForHome(5000);
}

/** Opens one of the home screen's rows ("Utilities", "Text Masking", ...). */
async function openFromHome(title) {
  await goHome();
  await scrollAndTap(sel.text(title));
}

/** Opens a row of the SwiftUI Elements list ("Toggles", "Grids", ...). */
async function openSwiftUIScreen(title) {
  await openFromHome("SwiftUI");
  await expectVisible(sel.text("SwiftUI Elements"));
  await scrollAndTap(sel.text(title));
}

/**
 * Backgrounding the app makes the agent harvest immediately, so the events a spec generated reach the
 * collector before LambdaTest tears the session down.
 */
async function flushHarvest(seconds = 5) {
  await driver.execute("mobile: backgroundApp", { seconds });
  await driver.pause(3000);
}

module.exports = {
  sel,
  HOME,
  viewport,
  drag,
  scrollToTop,
  scrollTo,
  tap,
  scrollAndTap,
  tapTrailing,
  slide,
  expectVisible,
  expectGone,
  typeInto,
  goBack,
  waitForHome,
  goHome,
  openFromHome,
  openSwiftUIScreen,
  flushHarvest,
};
