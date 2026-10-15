/**
 * Splash, Login, Forgot Password, Registration, and both logout paths.
 *
 * Covers every validation message the three auth screens can show, the success path of each, the
 * "Email already exists!" rejection (AuthService remembers registered emails for the life of the
 * process), and the Logout alert's No and Yes.
 */

const h = require("./helpers");

describe("ExpensesTracker: authentication", () => {
  it("shows the splash, then the login screen", async () => {
    await h.waitForLogin(30000);
    await h.expectText("Any email works");
  });

  it("validates the login form", async () => {
    await h.tapId("login.submit");
    await h.expectText("NAME REQUIRED....");

    await h.typeInto("login.email", h.TEST_EMAIL);
    await h.tapId("login.submit");
    await h.expectText("PASSWORD REQUIRED....");

    await h.fillLogin("not-an-email", h.TEST_PASSWORD);
    await h.expectText("INVALID EMAIL");

    await h.fillLogin(h.TEST_EMAIL, "123");
    await h.expectText("INVALID PASSWORD");
  });

  it("validates and submits Forgot Password", async () => {
    await h.tap(h.byLabel("Forgot password?"));
    await h.expectVisible(h.byId("forgot.email"));

    await h.tapId("forgot.submit");
    await h.expectText("Email field can't be empty");

    await h.typeInto("forgot.email", "bad-email");
    await h.tapId("forgot.submit");
    await h.expectText("Error : INVALID EMAIL");

    // Success pops back to the login screen.
    await h.typeInto("forgot.email", h.TEST_EMAIL);
    await h.tapId("forgot.submit");
    await h.waitForLogin();
  });

  it("validates the registration form and returns to login", async () => {
    await h.tap(h.byLabel("Don't have an account? | SIGNUP"));
    await h.expectVisible(h.byId("register.name"));

    await h.tapId("register.submit");
    await h.expectText("NAME REQUIRED....");

    await h.typeInto("register.name", "Lambda Tester");
    await h.tapId("register.submit");
    await h.expectText("EMAIL REQUIRED..");

    await h.typeInto("register.email", "register@example.com");
    await h.tapId("register.submit");
    await h.expectText("PASSWORD REQUIRED..");

    await h.typeInto("register.email", "nope");
    await h.typeInto("register.password", h.TEST_PASSWORD);
    await h.tapId("register.submit");
    await h.expectText("INVALID EMAIL");

    await h.typeInto("register.email", "register@example.com");
    await h.typeInto("register.password", "123");
    await h.tapId("register.submit");
    await h.expectText("INVALID PASSWORD");

    await h.tap(h.byLabel("Already have an account? sign in here"));
    await h.waitForLogin();
  });

  it("registers a new account and lands on Home", async () => {
    await h.tap(h.byLabel("Don't have an account? | SIGNUP"));
    await h.typeInto("register.name", "Lambda Tester");
    await h.typeInto("register.email", "register@example.com");
    await h.typeInto("register.password", h.TEST_PASSWORD);
    await h.tapId("register.submit");
    await h.waitForHome();
  });

  it("keeps the user on Home when Logout is declined, then logs out", async () => {
    await h.tapId("home.logout");
    await h.expectText("Are you sure you want to logout?");
    await h.tapAlertButton("No");
    await h.waitForHome();

    await h.tapId("home.logout");
    await h.tapAlertButton("Yes");
    await h.waitForLogin();
  });

  it("rejects registering the same email twice", async () => {
    await h.tap(h.byLabel("Don't have an account? | SIGNUP"));
    await h.typeInto("register.name", "Lambda Tester");
    await h.typeInto("register.email", "register@example.com");
    await h.typeInto("register.password", h.TEST_PASSWORD);
    await h.tapId("register.submit");
    await h.expectText("Email already exists!");

    await h.tap(h.byLabel("Already have an account? sign in here"));
    await h.waitForLogin();
  });

  it("signs in and logs out from the side menu", async () => {
    await h.fillLogin(h.TEST_EMAIL, h.TEST_PASSWORD);
    await h.waitForHome();

    await h.openSideMenu();
    await h.expectText(h.TEST_EMAIL);
    await h.tapId("sidemenu.logout");
    await h.tapAlertButton("Yes");
    await h.waitForLogin();
  });

  it("signs back in and flushes the harvest", async () => {
    await h.fillLogin(h.TEST_EMAIL, h.TEST_PASSWORD);
    await h.waitForHome();
    await h.flushHarvest();
  });
});
