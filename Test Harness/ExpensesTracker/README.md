# ExpensesTracker

A native iOS port of the Android [ExpensesTracker](../../../android-test-apps-publicGH/ExpensesTracker) test
app, built to exercise the New Relic iOS agent from the same app the Android agent is exercised from.

It links the agent **built from this working tree** (`Agent.xcodeproj` → `Agent_iOS`), not a published
XCFramework, which is what makes the MobileViews API available.

## Running it

```sh
cd "Test Harness/ExpensesTracker"
ruby generate_project.rb          # re-run after adding source files
open ExpensesTracker.xcodeproj
```

Any email signs in; passwords need six characters.

## Two UI toolkits, deliberately

The Android app is half Activities/Fragments and half Jetpack Compose, reached from a toolbar item. The port
keeps that split, because it is the reason the app is useful here — one app, both instrumentation paths:

| | Android | iOS |
|---|---|---|
| Launch | `SpalashScreen` | `SplashViewController` |
| Auth | `MainActivity`, `registration`, `forgotpassword` | `LoginViewController`, `RegistrationViewController`, `ForgotPasswordViewController` |
| Shell | `HomeActivity` — Toolbar, DrawerLayout, BottomNavigationView | `HomeViewController` — navigation bar, `SideMenuViewController`, child `UITabBarController` |
| Tabs | `dashboardFragment`, `incomeFragment`, `expenseFragment` | `DashboardViewController`, `IncomeViewController`, `ExpenseViewController` |
| Dialogs | `custom_layout_for_adding_data`, `update_item` | `RecordEditorViewController` |
| Second toolkit | `ComposeActivity` + 5 Compose files | `SwiftUISectionHost` + `Screens/SwiftUI` |

`ViewName` is the single source of truth for every view name the app reports; nothing passes a literal. The
complete inventory is `ViewName.allCases`, so NRQL expectations can be written off that list.

## Modes

Set `NR_MODE` in the scheme's environment (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Arguments):

- **`live`** (default when a token is available) — reports to the staging collector, matching the Android
  app's `usingCollectorAddress("staging-mobile-collector.newrelic.com")`. Override the token with
  `NR_APP_TOKEN`, the user id with `NR_USER_ID`.
- **`capture`** — reports to `NRCollectorStub` on `localhost:8080`, which prints every harvested event to the
  console. No account needed.

Capture mode needs port 8080 exclusively (the agent only drops to plain HTTP for the literal string
`localhost:8080`), so **only one** of ExpensesTracker, HomeSearch and NRTestApp can be in capture mode at a
time.

## No Firebase

The Android app uses Firebase Auth and Realtime Database. Rather than pull `firebase-ios-sdk` into this repo:

- `AuthService` simulates auth, including the one Firebase behaviour the Android UI surfaced
  (`fetchSignInMethodsForEmail` → "Email already exists!").
- `LedgerStubServer` is a local Swifter server on **port 8081** backed by a JSON file, and every read and
  write goes through it over real HTTP — so the agent records genuine `MobileRequest` events attributable to
  the screen that issued them. Reading the file directly would produce no network events at all.

It also hosts the failure routes the test menu drives (`/simulate/slow/:ms`, `/simulate/status/:code`),
replacing the Android app's calls to `postman-echo.com` and to deliberately non-existent public domains.

## The New Relic test menu

`NewRelicTestMenu` is the port of `incomeFragment.testNewRelicReporting()` — all thirteen options, same
order. Reachable from the ladybug button on the **Income** tab. The **Expense** tab's button fires a handled
exception and a custom event in one tap, as `fab_test_exception` did.

Three options needed translating rather than transcribing:

- **ANR → main-thread hang.** iOS has no ANR watchdog. Android blocked with `while (true) {}` and never
  recovered, destroying the session that was supposed to report the stall; these block for a bounded ten
  seconds.
- **Crashes** are real Swift traps — an out-of-bounds subscript and a failed forced cast, matching Android's
  `ArrayIndexOutOfBoundsException` and `ClassCastException` — rather than `NewRelic.crashNow()`.
- **Slow network** issues an actual slow request. The Android version only posted a delayed `Runnable`, so
  the agent never saw a slow transaction at all.

## Fixed rather than ported

Bugs in the original that would have become misleading data here. Each is commented at its site:

- The dashboard computed its balance by parsing the two total **labels** it had just formatted, commas and
  all (`dashboardFragment.updateBalance`). It reads the numbers.
- The add/update dialogs called `Integer.parseInt` before validating the other fields, so a non-numeric
  amount crashed instead of failing validation.
- Tapping a row stashed the record in five mutable fields on the fragment before opening the dialog, so a
  second tap could update the wrong record. The record is passed directly.
- The drawer built a **new** fragment per selection while the bottom bar reused the originals, so the two
  paths gave you different instances of the same tab. Both select the same tab.
- "Back to login" and password-reset success called `startActivity(MainActivity)`, stacking a second login
  screen rather than returning to the first.
- The expanding FAB gated its children on `isClickable` alone, leaving them tappable after the close
  animation. It is a `UIMenu`.
- The Compose "Total Expenses" card displayed a hardcoded `$343.54` that stopped being true on the sixth
  entry. It is computed.
