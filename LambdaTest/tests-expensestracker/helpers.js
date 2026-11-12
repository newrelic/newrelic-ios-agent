/**
 * Shared steps for the ExpensesTracker suite.
 *
 * Every spec file runs in its own Appium session (and so its own fresh install), so each one starts
 * with signIn() and ends with flushHarvest(). Selectors lean on the accessibilityIdentifiers the app
 * sets ("login.email", "home.menu", "editor.save", ...) and fall back to labels only where the app has
 * no identifier: alert buttons, menu actions, and the toasts that are the only on-screen evidence most
 * test-menu options ran.
 */

const crashUpload = require("./crash-upload");

const BUNDLE_ID = "com.newrelic.ExpensesTracker";

/**
 * The bundle id actually installed. The real-device archive can be built under another app's id when only
 * that app's provisioning profile is available (it passes ET_BUNDLE_ID), and LambdaTest's resigning can
 * rewrite it again, so the live session wins. LT_BUNDLE_ID is the manual override, as in the NRTestApp
 * real-device crash spec.
 */
function bundleId() {
  if (process.env.LT_BUNDLE_ID) return process.env.LT_BUNDLE_ID;
  const caps = driver.capabilities || {};
  return (
    caps.bundleID ||
    caps.bundleId ||
    caps["appium:bundleId"] ||
    caps.CFBundleIdentifier ||
    process.env.ET_BUNDLE_ID ||
    BUNDLE_ID
  );
}

// Any email with a dot in its domain signs in; passwords need six characters (AuthService).
const TEST_EMAIL = "lambdatest@example.com";
const TEST_PASSWORD = "secret123";

const byId = (id) => $(`~${id}`);

const quote = (text) => text.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

const byLabel = (label) => $(`-ios predicate string:label == "${quote(label)}"`);

const containing = (text) => $(`-ios predicate string:label CONTAINS "${quote(text)}"`);

/** A button inside a UIAlertController, alert or action sheet style. */
const alertButton = (label) =>
  $(
    `-ios class chain:**/*[\`type == "XCUIElementTypeAlert" OR type == "XCUIElementTypeSheet"\`]` +
      `/**/XCUIElementTypeButton[\`label == "${quote(label)}"\`]`
  );

const tabBarButton = (label) =>
  $(`-ios class chain:**/XCUIElementTypeTabBar/**/XCUIElementTypeButton[\`label == "${quote(label)}"\`]`);

async function tap(element, timeout = 10000) {
  const el = await element;
  await el.waitForDisplayed({ timeout });
  await el.click();
}

async function tapId(id, timeout) {
  await tap(byId(id), timeout);
}

async function typeInto(id, value) {
  const field = await byId(id);
  await field.waitForDisplayed({ timeout: 10000 });
  await field.click();
  await field.clearValue();
  await field.setValue(value);
}

async function expectVisible(element, timeout = 10000) {
  const el = await element;
  await el.waitForDisplayed({ timeout });
  return el;
}

async function expectText(text, timeout = 10000) {
  return expectVisible(containing(text), timeout);
}

/**
 * Toasts fade after ~2.5s. Waiting for this one to go before moving on keeps the next assertion from
 * matching a stale toast with the same wording.
 */
async function expectToast(text, timeout = 10000) {
  const toast = await containing(text);
  await toast.waitForExist({ timeout });
  await toast.waitForExist({ timeout: 8000, reverse: true });
}

async function tapAlertButton(label, timeout) {
  await tap(alertButton(label), timeout);
}

/**
 * From iOS 26 the test menu's action sheet is presented as a popover, whose rows report visible="false"
 * even while on screen, so this waits for existence rather than visibility. The sheet scrolls; bring the
 * option into view first in case it is below the fold.
 */
async function tapSheetOption(label) {
  const option = await alertButton(label);
  await option.waitForExist({ timeout: 10000 });
  try {
    await driver.execute("mobile: scrollToElement", { elementId: option.elementId });
  } catch (err) {
    // Already in view, or a driver without scrollToElement; the tap below says which.
  }
  await option.click();
}

/** The popover form has no Cancel action (it is dismissed by tapping outside); the classic sheet does. */
async function dismissSheet() {
  const cancel = await alertButton("Cancel");
  if (await cancel.isExisting()) {
    await cancel.click();
  } else {
    await tap(byId("PopoverDismissRegion"));
  }
  await byLabel("Test New Relic Reporting").waitForExist({ timeout: 5000, reverse: true });
}

async function waitForLogin(timeout = 20000) {
  await expectVisible(byId("login.email"), timeout);
}

async function waitForHome(timeout = 20000) {
  await expectVisible(byId("home.menu"), timeout);
}

async function fillLogin(email, password) {
  await typeInto("login.email", email);
  await typeInto("login.password", password);
  await tapId("login.submit");
}

/** From launch to the Home screen. The app keeps the user signed in across launches, so either is valid. */
async function signIn() {
  const login = await byId("login.email");
  const home = await byId("home.menu");
  await driver.waitUntil(async () => (await login.isDisplayed()) || (await home.isDisplayed()), {
    timeout: 30000,
    timeoutMsg: "Neither the login screen nor Home appeared after the splash",
  });
  if (await home.isDisplayed()) return;

  await fillLogin(TEST_EMAIL, TEST_PASSWORD);
  await waitForHome();
}

async function selectTab(name) {
  await tap(tabBarButton(name));
}

async function openSideMenu() {
  await tapId("home.menu");
  await expectVisible(byId("sidemenu.dashboard"));
}

async function openTestMenu() {
  await selectTab("Income");
  await tapId("income.testmenu");
  await byLabel("Test New Relic Reporting").waitForExist({ timeout: 10000 });
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

/** Brings the app back after a crash. The relaunch is what uploads the crash report. */
async function relaunchAfterCrash() {
  const id = bundleId();
  await driver.waitUntil(
    async () => {
      try {
        return (await driver.execute("mobile: queryAppState", { bundleId: id })) !== 4;
      } catch (err) {
        return false; // a dying app can make this fail transiently
      }
    },
    { timeout: 30000, timeoutMsg: `App ${id} was still in the foreground; the crash did not happen` }
  );
  // Terminate first so this is a cold start, never a reinstall: reinstalling would delete the pending
  // crash report before the agent could upload it.
  try {
    await driver.execute("mobile: terminateApp", { bundleId: id });
  } catch (err) {
    // already gone
  }
  await driver.execute("mobile: activateApp", { bundleId: id });
  await waitForHome(60000);
}

/**
 * Accepts one of the test menu's crash options, then relaunches so the agent uploads the report. With
 * ET_VERIFY_CRASH_UPLOAD=1 (real devices) the upload is asserted from syslog; otherwise the spec just stays
 * up long enough for it to happen.
 */
async function crashAndRelaunch(title) {
  if (crashUpload.enabled()) await crashUpload.expectAgentLogsInSyslog();

  await openTestMenu();
  await tapSheetOption(title);
  await tapAlertButton("Yes");
  await relaunchAfterCrash();

  if (crashUpload.enabled()) {
    await crashUpload.expectCrashUploaded();
  } else {
    await driver.pause(15000);
  }
  await flushHarvest();
}

module.exports = {
  crashAndRelaunch,
  BUNDLE_ID,
  bundleId,
  TEST_EMAIL,
  TEST_PASSWORD,
  byId,
  byLabel,
  containing,
  alertButton,
  tabBarButton,
  tap,
  tapId,
  typeInto,
  expectVisible,
  expectText,
  expectToast,
  tapAlertButton,
  tapSheetOption,
  dismissSheet,
  waitForLogin,
  waitForHome,
  fillLogin,
  signIn,
  selectTab,
  openSideMenu,
  openTestMenu,
  flushHarvest,
  relaunchAfterCrash,
};
