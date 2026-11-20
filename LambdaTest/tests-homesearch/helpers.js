/**
 * Shared steps for the HomeSearch suite.
 *
 * Every spec file runs in its own Appium session (and so its own fresh install), so each one starts with
 * waitForResults() and ends with flushHarvest(). Selectors lean on the accessibilityIdentifiers the app
 * sets ("search.filters", "detail.save", "contact.submit", ...) and fall back to labels for what SwiftUI
 * names on its own: tab bar items, segmented-control segments, menu options and the switches in a Form.
 *
 * The listing data is the app's bundled fixture (Data/listings.json), served by its in-process stub
 * server, so listing ids, prices and counts are the same on every run.
 */

const TOTAL_LISTINGS = 12;

const byId = (id) => $(`~${id}`);

const quote = (text) => text.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

const byLabel = (label) => $(`-ios predicate string:label == "${quote(label)}"`);

const containing = (text) => $(`-ios predicate string:label CONTAINS "${quote(text)}"`);

const button = (label) => $(`-ios predicate string:type == "XCUIElementTypeButton" AND label == "${quote(label)}"`);

/** By type, because a Stepper's title is also in the tree as a hidden StaticText with the same label. */
const stepper = (label) => $(`-ios predicate string:type == "XCUIElementTypeStepper" AND label == "${quote(label)}"`);

const tabBarButton = (label) =>
  $(`-ios class chain:**/XCUIElementTypeTabBar/**/XCUIElementTypeButton[\`label == "${quote(label)}"\`]`);

/**
 * A SwiftUI Toggle reports as a Switch spanning its whole row, with the actual control as a child Switch.
 * Tapping the row's centre lands on the label and does nothing, so this targets the child.
 */
const toggleControl = (nameOrLabel) =>
  $(
    `-ios class chain:**/XCUIElementTypeSwitch[\`name == "${quote(nameOrLabel)}" OR label == "${quote(nameOrLabel)}"\`]` +
      "/XCUIElementTypeSwitch"
  );

const searchField = () => $("-ios class chain:**/XCUIElementTypeSearchField");

/** The first row of the search results, i.e. what the current sort puts on top. */
const firstResult = () => $('-ios predicate string:name BEGINSWITH "search.listing."');

async function tap(element, timeout = 10000) {
  const el = await element;
  await el.waitForDisplayed({ timeout });
  await el.click();
}

async function tapId(id, timeout) {
  await tap(byId(id), timeout);
}

async function expectVisible(element, timeout = 10000) {
  const el = await element;
  await el.waitForDisplayed({ timeout });
  return el;
}

async function expectGone(element, timeout = 5000) {
  const el = await element;
  await el.waitForExist({ timeout, reverse: true });
}

/**
 * SwiftUI combines a row's texts into one element ("Active filters, 0") but keeps the parts in the tree as
 * hidden children, so the first element containing a text is often not the one on screen. Any displayed
 * match will do.
 */
async function expectText(text, timeout = 10000) {
  const selector = `-ios predicate string:label CONTAINS "${quote(text)}"`;
  await driver.waitUntil(
    async () => {
      for (const el of await $$(selector)) {
        if (await el.isDisplayed()) return true;
      }
      return false;
    },
    { timeout, timeoutMsg: `No displayed element containing "${text}" after ${timeout}ms` }
  );
}

async function expectLabel(id, label, timeout = 10000) {
  const el = await expectVisible(byId(id), timeout);
  await expect(el).toHaveAttribute("label", label);
  return el;
}

/**
 * Lists are lazy, so a row off screen is not in the tree at all until it is scrolled to. A list keeps its
 * scroll position when a pushed screen is popped, so the row can be above the fold as well as below it:
 * search down first, then back up.
 */
async function scrollTo(element, maxSwipes = 6) {
  const el = await element;
  for (const direction of ["down", "up"]) {
    for (let i = 0; i < maxSwipes && !(await el.isExisting()); i++) {
      await driver.execute("mobile: scroll", { direction });
    }
  }
  await el.waitForExist({ timeout: 5000 });
  if (!(await el.isDisplayed())) {
    await driver.execute("mobile: scroll", { elementId: el.elementId, toVisible: true });
  }
  return el;
}

/** The software keyboard covers the lower half of a Form; Return ends editing on a single-line field. */
async function dismissKeyboard() {
  const keyboard = await $("-ios class chain:**/XCUIElementTypeKeyboard");
  if (!(await keyboard.isExisting())) return;
  const returnKey = await $(
    '-ios class chain:**/XCUIElementTypeKeyboard/**/XCUIElementTypeButton[`name == "Return"`]'
  );
  if (await returnKey.isExisting()) {
    await returnKey.click();
  } else {
    await driver.hideKeyboard();
  }
  await keyboard.waitForExist({ timeout: 5000, reverse: true });
}

async function typeInto(id, value, { keepKeyboard = false } = {}) {
  const field = await expectVisible(byId(id));
  await field.click();
  await field.clearValue();
  await field.setValue(value);
  if (!keepKeyboard) await dismissKeyboard();
}

/**
 * A menu-style Picker in a Form reports an element covering only its title, so a tap on its centre can
 * miss the row. Retry on the row's trailing edge, where the current value is drawn.
 */
async function chooseFromMenuPicker(titlePrefix, option) {
  const picker = await expectVisible(
    $(`-ios predicate string:type == "XCUIElementTypeButton" AND label BEGINSWITH "${quote(titlePrefix)}"`)
  );
  const choice = await button(option);
  await picker.click();
  if (!(await choice.waitForExist({ timeout: 3000 }).catch(() => false))) {
    const { width } = await driver.getWindowSize();
    const rect = JSON.parse(await picker.getAttribute("rect"));
    await driver.execute("mobile: tap", { x: width - 50, y: Math.round(rect.y + rect.height / 2) });
    await choice.waitForExist({ timeout: 5000 });
  }
  await choice.click();
  await choice.waitForExist({ timeout: 5000, reverse: true });
}

async function selectTab(name) {
  await tap(tabBarButton(name));
}

async function goBack() {
  await tapId("BackButton");
}

/** From launch to a loaded Search tab. The fixture loads over HTTP from the app's own stub server. */
async function waitForResults(timeout = 30000) {
  await expectLabel("search.count", `${TOTAL_LISTINGS} of ${TOTAL_LISTINGS} homes`, timeout);
}

async function expectResultCount(count) {
  await expect(byId("search.count")).toHaveAttribute("label", `${count} of ${TOTAL_LISTINGS} homes`);
}

/** Opens a listing from the Search tab and waits for its detail screen. */
async function openListing(id) {
  await tap(await scrollTo(byId(`search.listing.${id}`)));
  await expectVisible(byId("detail.save"));
}

/**
 * From iOS 26 a popover's rows can report visible="false" even while on screen, so popovers are waited for
 * by existence. The popover is dismissed by tapping outside it.
 */
async function dismissPopover() {
  const region = await byId("PopoverDismissRegion");
  await region.waitForExist({ timeout: 5000 });
  await region.click();
  await region.waitForExist({ timeout: 5000, reverse: true });
}

/**
 * Backgrounding the app makes the agent harvest immediately, so the events a spec generated reach the
 * collector before LambdaTest tears the session down. It also closes the current MobileView visit, which
 * is itself something the agent should report.
 */
async function flushHarvest(seconds = 5) {
  await driver.execute("mobile: backgroundApp", { seconds });
  await driver.pause(3000);
}

module.exports = {
  TOTAL_LISTINGS,
  byId,
  byLabel,
  containing,
  button,
  stepper,
  tabBarButton,
  toggleControl,
  searchField,
  firstResult,
  tap,
  tapId,
  expectVisible,
  expectGone,
  expectText,
  expectLabel,
  scrollTo,
  dismissKeyboard,
  typeInto,
  chooseFromMenuPicker,
  selectTab,
  goBack,
  waitForResults,
  expectResultCount,
  openListing,
  dismissPopover,
  flushHarvest,
};
