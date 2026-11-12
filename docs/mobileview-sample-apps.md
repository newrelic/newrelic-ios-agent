# Mobile Views sample apps (iOS)

| | |
| --- | --- |
| Status | Living document |
| Owner | Chris Dillard |
| Last verified | 2026-09-28, against `newrelic-ios-agent` branch `mobile-views-2` (local HEAD 7.7.8-dev.55) |
| Related | [Mobile Views IDD](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5548769647) · Jira [NR-356639](https://new-relic.atlassian.net/browse/NR-356639) · `docs/mobileview-scenario-capture.md` (capture + diagram recipe) |

## Purpose

This page lists the five apps we use to test the iOS agent's **Mobile Views** features and says what each one is good for. The features are:

- `MobileView` events, one per screen visit.
- `MobileViewTiming` events: TTID, TTFD and custom marks.
- Automatic UIKit and SwiftUI screen naming.
- The manual view APIs.
- Session flow and timeline diagrams.

The apps fall into two groups:

- **Three in-house test harnesses** in the agent repo, built for this purpose: NRTestApp, ExpensesTracker and HomeSearch.
- **Two real-world open-source apps** that embed the agent: isowords and SyncUps. Both are built with The Composable Architecture (TCA). We use them to see how automatic naming behaves on code we didn't write for the agent.

## At a glance

| App | Location | UI stack | Agent linked as | Best for |
| --- | --- | --- | --- | --- |
| **NRTestApp** | `newrelic-ios-agent/Test Harness/NRTestApp` | UIKit shell, SwiftUI section | Local source (`Agent.xcodeproj` subproject) | Widest coverage: every MobileView API, timings, guardrails, modals, components, and the in-app Session Diagram |
| **ExpensesTracker** | `newrelic-ios-agent/Test Harness/ExpensesTracker` | Mostly UIKit, one modal SwiftUI section | Local source (`Agent.xcodeproj` subproject) | UIKit app shapes: window-root swaps, container VC with child tab bar, drawer, modal editor, login/logout |
| **HomeSearch** | `newrelic-ios-agent/Test Harness/HomeSearch` | Pure SwiftUI | Local source (`Agent.xcodeproj` subproject) | A realistic SwiftUI app: `TabView` + one `NavigationStack` per tab, route enums, sheet / fullScreenCover / popover |
| **isowords** | `~/Documents/PublicWorkspace/isowords` (fork of `pointfreeco/isowords`) | SwiftUI + TCA | Remote SPM, branch `mobile-views-2` | A large, real, modular TCA app with `Group { switch }` root swapping, custom overlays and deep push chains |
| **SyncUps** | `~/Documents/PublicWorkspace/swift-composable-architecture/Examples/SyncUps` (fork of `pointfreeco/swift-composable-architecture`) | SwiftUI + TCA | Remote SPM, branch `mobile-views-2` | TCA `StackState` navigation: stack screens named from `Path` route enums, TCA alerts and sheets |

### Which app for which feature

| Feature under test | NRTestApp | ExpensesTracker | HomeSearch | isowords | SyncUps |
| --- | :-: | :-: | :-: | :-: | :-: |
| Automatic UIKit screens | ✅ | ✅ | – | – | – |
| Automatic SwiftUI screens (no modifier) | ✅ | ✅ | ✅ | ✅ | ✅ |
| SwiftUI `TabView` tabs | ✅ (iOS 18) | – | ✅ | – | – |
| `NavigationStack` route-enum naming | ✅ | ✅ | ✅ | ✅ | ✅ |
| Sheets / fullScreenCover / popover | ✅ | ✅ (sheet) | ✅ | ✅ (sheet) | ✅ (sheet) |
| UIKit modal styles | ✅ | ✅ | – | – | – |
| Alerts (`UIAlertController` / TCA alerts) | – | ✅ | – | ✅ | ✅ |
| Child-VC components (`component`, `componentOf`) | ✅ | ✅ (drawer, tabs) | – | – | – |
| `.NRMobileView(name:attributes:)` | ✅ | – | – | – | – |
| Manual `setCurrentView` | ✅ | ✅ (drawer only) | ⚠️ (see known issues) | – | – |
| `markViewTiming` / `recordViewTiming` (TTFD, custom marks) | ✅ | – | – | – | – |
| Timing guardrails (reserved / NaN / cap) | ✅ | – | – | – | – |
| Views × Interactions (`interactionId`) | ✅ | – | – | – | – |
| Retained-VC revisit (`loadTimeUnavailable`) | ✅ | – | – | – | – |
| In-app Session Diagram (flow + timeline) | ✅ | – | – | – | – |
| In-app collector stub (no host setup) | ✅ (code edit) | ✅ | ✅ | – | – |
| Screens automatic naming *can't* see yet | – | – | – | ✅ | ✅ |

## Common setup

### Feature flags

MobileView capture depends on these `NRMAFeatureFlags` (defaults are from `Agent/Public/NewRelicFeatureFlags.h`):

| Flag | Default | Controls |
| --- | --- | --- |
| `NRFeatureFlag_NewEventSystem` | Off | The new event pipeline. Every sample app turns it on. |
| `NRFeatureFlag_AutomaticMobileViews` | On | Automatic UIKit capture (the swizzle), and the gate for automatic SwiftUI capture. |
| `NRFeatureFlag_AutomaticSwiftUIViews` | On | Automatic SwiftUI naming by reflecting into hosting controllers. Needs `AutomaticMobileViews`. |
| `NRFeatureFlag_ManualMobileViews` | Off | `setCurrentView:attributes:`, manual load start, and marks on manual views. **Events whose `uiFramework` is manual are dropped while this is off.** |

Some header docs and in-app comments still use the old names (`NRFeatureFlag_AutomaticViews` / `ManualViews`) or say both flags are off by default. Trust the enum.

Each app turns on these flags:

| App | NewEventSystem | AutomaticMobileViews | AutomaticSwiftUIViews | ManualMobileViews |
| --- | :-: | :-: | :-: | :-: |
| NRTestApp | ✅ | ✅ | ✅ | ✅ |
| ExpensesTracker | ✅ | ✅ | ✅ | ✅ |
| HomeSearch | ✅ | ✅ | ✅ | ❌ (commented out) |
| isowords | ✅ \* | ✅ \* | ✅ \* | ❌ |
| SyncUps | ✅ \* | ✅ \* | ✅ \* | ❌ |

\* Only with the temporary capture edits described below. As committed, isowords and SyncUps turn on no flags.

### Seeing the events: the host collector

Point the app at a fake collector on the Mac's `localhost:8080`. That is the most reliable way to see exactly what the agent sends. The simulator shares the host's network, and the exact string `localhost:8080` makes the agent drop TLS.

```bash
./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json                    # HomeSearch, ExpensesTracker, isowords, SyncUps
./scripts/mobileview_capture_collector.py --out /tmp/mv/events.json --nrtestapp-plist  # NRTestApp: points NRAPI-Info.plist at localhost, restores it on exit
```

Then render the capture:

```bash
./scripts/mobileview_flow.py /tmp/mv/events.json --title "My scenario" --svg /tmp/mv/flow.svg
./scripts/mobileview_flow.py /tmp/mv/events.json --timeline --max-visits 100 --svg /tmp/mv/timeline.svg
```

Both commands print Mermaid on stdout, ready to paste into a PR or into this space. The full recipe, including validation checks such as dangling referrer ids and names that aren't screen names, is in `docs/mobileview-scenario-capture.md` in the agent repo.

General rules:

- **Only one app can be in capture mode at a time.** Every harness and the host collector use port 8080. Terminate test apps you're finished with, because a backgrounded app keeps its stub listening.
- **Force a harvest** by backgrounding the app, with Pepper `app_debug command=lifecycle action=background`. The agent otherwise buffers for up to 30–60 s, and a crash loses every event that hasn't been harvested.
- Use a booted **iOS 26.3** simulator for Pepper-driven runs. SyncUps needs iOS 26 or later.
- A previously launched app keeps Pepper's port 8844, and the next app then says "Pepper didn't respond". Fix it with `xcrun simctl terminate <udid> <old bundle id>`.

---

## NRTestApp

**What it is:** the agent's own sample app for iOS, tvOS and watchOS. It has a UIKit home table (the NASA APOD image, then a flat list of rows) and a **SwiftUI** row that opens about 30 SwiftUI demos. The MobileView demos are the rows titled `MobileView · …`.

**Location:** `Test Harness/NRTestApp` in `newrelic-ios-agent`.

### Build and run

- Open `Agent.xcworkspace` at the repo root, scheme **`NRTestApp`**. `NRTestApp (tvOS)` is also shared. The watchOS scheme is user-level only and turns on no MobileView flags.
- Deployment target is iOS 15.0. Some screens need a newer OS: the Tab Bar demo needs iOS 18, PerformanceContentView iOS 17, and ClaimForm iOS 16.
- It links the **local agent source**, so your branch's changes are what you test.

### Configuration

- The token and collectors come from `Test Harness/NRTestApp/NRAPI-Info.plist` (`NRAPIKey`, `collectorAddress`, `crashCollectorAddress`). That file usually carries local staging edits, so **don't commit it**.
- Flags and settings are in `NRTestApp/AppDelegate.swift`. Along with the four MobileView flags, it turns on `SwiftAsyncURLSessionSupport` and `OfflineStorage`, sets an event pool of 5000 and a buffer time of 60 s, and turns on debug logging.
- There are three start modes:
  1. `UITesting` env var: uses `localhost:8080`, served by the UI tests' Swifter server.
  2. `captureMode = true`: a hand edit in `AppDelegate` that starts the in-app `NRCaptureServer`. The **Capture Viewer** row then runs the payload verifiers, including MobileView schema checks.
  3. Otherwise, the plist values.
- For MobileView work, prefer the host collector with `--nrtestapp-plist`. Start it **before** building, because the plist is read at build time.

### MobileView demos

UIKit rows on the home table (`NRTestApp/ViewControllers/`):

| Row | Exercises |
| --- | --- |
| MobileView · Custom Attrs (UIKit) | `nrMobileViewAttributes()` hook with a visit counter; child-VC components (`component: true`, `componentOf`), which don't inherit the parent's attributes |
| MobileView · View Timing / TTFD (UIKit) | Staged load: agent TTID, then `markViewTiming("timeToFullDisplay")` at +600 ms, `timeToInteractive`, `recordViewTiming("timeToFirstByte", milliseconds:)`; buttons for the guardrails (reserved name, NaN, too large, empty name, per-view cap) |
| MobileView · Nil name → class name (UIKit) | `nrMobileViewName()` returns nil, so the event falls back to the class name |
| MobileView · Views × Interactions (UIKit) | `interactionId` correlation, `startInteraction`, `recordBreadcrumb`, `setCurrentView("Checkout")`, components |
| MobileView · Modals (UIKit, iOS only) | `.fullScreen` ends the presenter's visit; `.pageSheet` / `.formSheet` / `.popover` don't; the `previousView` referrer |
| MobileView · Restarted / Legacy Name (UIKit) | Re-pushes one retained VC: revisits omit `loadTime` and set `loadTimeUnavailable`; an empty-string name falls back to the class name |
| MobileView · Session Diagram (SVG, iOS only) | The agent's own Mermaid output (`currentSessionFlowDiagram` / `currentSessionTimeline`, and archived sessions via `archivedFlowDiagramSessionIds`) drawn in a `WKWebView`; Components / Breadcrumbs / Flow-Timeline toggles; the copy button puts the Mermaid on the pasteboard |
| Infinite Scroll View, Infinite Images View | `markViewTiming("timeToFullDisplay")` once the first screenful is real |

SwiftUI rows, under **SwiftUI** (`NRTestApp/SwiftUI/`):

| Row | Exercises |
| --- | --- |
| MobileView · Automatic (no modifier) | No New Relic API at all: push, `navigationDestination`, `.sheet`, a two-tab `TabView`. Each screen's expected `viewName` is its struct name |
| MobileView · Custom Attributes | `.NRMobileView(attributes:)` with no name, so the name is resolved automatically. This is the only live `.NRMobileView` call in the app |
| MobileView · Manual (setCurrentView + referrer) | `setCurrentView` chains with `previousView`; marks and recorded timings against a manual view |
| MobileView · Views × Interactions | Live interaction readout |
| Modals (Sheet / FullScreenCover / Popover) | Plain SwiftUI modal presentations |
| Tab Bar (iOS 18); also the home row "SwiftUI UITabBar" | A plain `TabView` plus custom events |
| NavigationStack, Infinite Images | Stack pushes; SwiftUI TTFD |

### Gotchas

- **A full walk is about 150 MobileView events in about 20 minutes.** Flush before risky screens.
- Inside the SwiftUI section, `nav_back` pops the whole hosting controller back to the UIKit home. Tap the SwiftUI back-button text (`"SwiftUI Elements"`) instead. On ClaimForm, tap the UIKit back chevron.
- `app_look` can't see most of the UIKit home table's cells. Navigate from screenshots with `ui_tap point=`, and take a screenshot after every scroll.
- For TabView screens, use `sim_raw cmd=tap` with points from a screenshot.
- Pepper itself can crash the app, for example in `ElementDedup.isDuplicate` on Date Time Picker. If `crash_log` shows a Pepper frame, it isn't an agent bug.

---

## ExpensesTracker

**What it is:** an iOS port of the Android ExpensesTracker app, a simulated income and expense ledger. It is mostly **UIKit**, and was chosen for UIKit app shapes that NRTestApp doesn't have. The README has the Android-to-iOS screen mapping.

**Location:** `Test Harness/ExpensesTracker` in `newrelic-ios-agent`.

### Navigation

- **Window-root swaps** (`Navigation/AppFlow.swift`): Splash → Login → Home. Login is a `UINavigationController` that pushes Registration and Forgot Password. A signed-in user goes straight from Splash to Home.
- **Home** is a container VC:
  - A child `UITabBarController` with Dashboard, Income and Expense tabs.
  - A slide-in `SideMenuViewController` drawer, added as a child VC.
  - Nav-bar buttons for SwiftUI and logout.
- **RecordEditorViewController** (Add / Update Record) is presented modally inside a nav controller.
- **Logout**, from the nav bar or the drawer, shows a `UIAlertController` ("Are you sure?"). Yes returns to Login.
- **New Relic test menu**: an action sheet behind the ladybug button on the Income tab.
- **SwiftUI section** (`Screens/SwiftUI/SwiftUISectionHost.swift`): a full-screen `UIHostingController` with a `NavigationStack(path:)`. It has a list, a `.navigationDestination` detail screen, and an Add Expense `.sheet`.
- **Login:** any email and a password of 6 or more characters (simulated).

### Build and run

- Open `Test Harness/ExpensesTracker/ExpensesTracker.xcodeproj` (for Pepper: `…/ExpensesTracker.xcodeproj/project.xcworkspace`), scheme **`ExpensesTracker`**, iOS 17+, simulator, unsigned.
- The project is generated. Run `ruby generate_project.rb` after adding files.
- Links the **local agent source** (`Agent_iOS` target).
- A local `LedgerStubServer` serves app data on port 8081.

### Configuration (`ExpensesTracker/App/NewRelicConfig.swift`)

- Flags: `NewEventSystem`, `LogReporting`, `AutomaticMobileViews`, `ManualMobileViews`, `AutomaticSwiftUIViews`.
- Settings: buffer time 30 s, pool size 2000, debug logging, `setUserId`, log attributes, and a startup interaction.
- `NR_MODE`:
  - `capture` starts the in-app `NRCollectorStub` on `localhost:8080`, which prints each harvest to the console.
  - `live` reports to the staging collectors.
  - The default is live when a token is available, otherwise capture.
- Always launch with **`-NR_MODE capture`** for local testing. Without it the app reports live to staging.
- Other env vars: `NR_APP_TOKEN`, `NR_USER_ID`.

### What it covers

- **Almost everything is automatic.** Every UIKit screen subclasses `InstrumentedViewController`, but its `reportView()` call in `viewDidAppear` is commented out. Screens are named by automatic UIKit capture, from the VC class. The only live manual call is `sideMenu.reportView()` when the drawer opens.
- `Navigation/ViewName.swift` holds the intended names: 12 UIKit and 3 SwiftUI.
- The SwiftUI section uses no `.NRMobile*` modifiers, so it is automatic SwiftUI capture only.
- Also tests: breadcrumbs (`login_*`, `tab_selected`, `side_menu_opened`) and a rotation custom event on every screen.

### Gotchas

- `ui_input text:"PASSWORD"` can type into the email field, and `ui_tap text:"PASSWORD" index:2` can hit "Forgot password?". Tap the field by point, then type with `ui_input value:`.
- Pepper labels the app's own logout alert as a "SYSTEM DIALOG". Use `ui_tap text:"Yes"`, not `dismiss_system`.

---

## HomeSearch

**What it is:** a **pure SwiftUI** real-estate search app with local fixtures (`Data/listings.json`). It is structured the way a normal production SwiftUI app is. It is the main test bed for **automatic SwiftUI naming**, `NRFeatureFlag_AutomaticSwiftUIViews`.

**Location:** `Test Harness/HomeSearch` in `newrelic-ios-agent`. There is no README.

### Navigation

- **`RootTabView`**: a `TabView` with Search, Saved, Inbox and Profile. Each tab owns its own `NavigationStack` and route enum (`Navigation/Route.swift`: `AppTab`, `SearchRoute`, `SavedRoute`, `InboxRoute`, `ProfileRoute`).
- **Search**: pushes Listing Detail (and Tour Requested); Filters is a `.sheet`.
- **Listing Detail**: Photo Gallery is a `.fullScreenCover`, Mortgage Calculator a `.popover`, and Contact Agent a sheet (currently unreachable, see known issues).
- **Inbox**: pushes a message thread.
- **Profile**: `NavigationLink(value:)` to Notification Settings, Search Preferences and Debug Info.
- No login flow.

### Build and run

- Open `Agent.xcworkspace` (or `Test Harness/HomeSearch/HomeSearch.xcodeproj`), scheme **`HomeSearch`**, iOS 17, simulator.
- Links the **local agent source**. The project is generated by `generate_project.rb`.
- `ListingStubServer` serves listings on port 8082.

### Configuration (`HomeSearch/App/NewRelicConfig.swift`)

- Flags: `NewEventSystem`, `AutomaticMobileViews`, `AutomaticSwiftUIViews`. `ManualMobileViews` is commented out.
- Buffer time 30 s.
- `NR_MODE` capture / live work the same way as in ExpensesTracker. The mode is read from the environment **or** from UserDefaults, so the launch argument `-NR_MODE capture` works. **Always pass it for local testing.** A token is configured locally, so the default is live, even though the file's header comment says capture.
- In capture mode, look for `[HomeSearch/collector] listening on localhost:8080` and `┌─ harvest ─` in the log:

  ```bash
  xcrun simctl spawn <udid> log stream --style compact --predicate 'process == "HomeSearch"'
  ```

### What it covers

- **Automatic SwiftUI capture only.** Every `.NRMobile*` modifier (`NRMobileTabTracking`, `NRMobileView`, `NRMobileDestination`, `NRMobileSheet`, `NRMobileFullScreenCover`, `NRMobilePopover`) is commented out. The `HomeSearchApp.swift` header still lists them as in use.
- Screens are named from the route and tag enums, case name only (e.g. `AppTab.search`, `SearchRoute.listing`). That is the identity reflection can see in a normally structured app.
- `Screens/DebugInfoScreen.swift` was originally the "not instrumented" negative test. Automatic naming should now pick it up.
- Dynamic names: `ViewName` includes `Message Thread — <name>`.

### Related: HomeSearch-spm-copy (untracked)

An older snapshot of HomeSearch that links the agent through **remote SPM** (`mobile-views-2`) and still uses the manual `.NRMobile*` modifiers with `ManualMobileViews` on. Use it only to test the SPM integration path.

---

## isowords

**What it is:** Point-Free's open-source 3D word-cube game. It is a large, modular **SwiftUI + TCA** app with 16 `Sources/*Feature` modules. We use it to see how automatic naming holds up on a real app nobody wrote with the agent in mind.

**Location:** `~/Documents/PublicWorkspace/isowords`. It is a fork, `github.com/cdillard-NewRelic/isowords`, based on upstream `c727d3a` ("Start using IssueReporting", Aug 2024). The local commit `c938942` "fixes" bumps TCA to at least 1.26 and moves to swift-issue-reporting 2.1.

### Navigation

- **Root** (`Sources/AppFeature/AppView.swift`): `Group { switch store.destination }` swaps between `NavigationStack { HomeView }`, `GameView` and `OnboardingView`.
- **Home**: a `Destination` enum pushed with `.navigationDestination(item:)`: dailyChallenge, leaderboard, multiplayer, settings, solo. Changelog is a `.sheet`.
- **Deeper**:
  - Multiplayer → PastGames.
  - DailyChallenge → Results (plus alerts).
  - Stats → Vocab.
  - Leaderboard and Vocab open CubePreview as a `.sheet`.
  - Settings sub-pages are `NavigationLink`s, with an alert and a share sheet.
- **Game**: a custom `.bottomMenu`, a forfeit `.alert`, and in-game Settings as a `.sheet` inside a `NavigationStack`. GameOver and UpgradeInterstitial are `if let` overlays, not presentations.

### Build and run

- Open `App/isowords.xcodeproj` (for Pepper: `App/isowords.xcodeproj/project.xcworkspace`), scheme **`isowords`**, iOS 17+.
- Needs **git-lfs** and `make bootstrap-client` for assets and the dictionary.
- The first build takes more than 2 minutes.
- The API client expects a server on `localhost:9876` that we don't run, so leaderboards and daily challenges fail or show alerts.
- Onboarding appears on first launch.
- Local modifications against upstream:
  - Bundle id is `com.newrelic.IsoWordsTesting`, and the team is changed.
  - The AppClip target is removed.
  - Entitlements are stripped, so Game Center, push and iCloud don't work.
  - The ngrok ATS exception is removed. `NSAllowsLocalNetworking` stays, because the localhost collector needs it.

### New Relic integration

- `App/iOS/App.swift` calls `NewRelic.start` in `AppDelegate.didFinishLaunching`, through `@UIApplicationDelegateAdaptor`, with debug logging. As committed, it reports to the **staging** collectors.
- It depends on `github.com/newrelic/newrelic-ios-agent.git` through **remote SPM, branch `mobile-views-2`**.

### Capturing MobileViews: three temporary edits

The pushed `mobile-views-2` (`0d6b728f`) still points `Package.swift` at the **7.7.7 release binary**, which has no MobileView support. As checked in, the app emits **zero** MobileView events. To capture (back up first, restore afterwards):

1. `App/iOS/App.swift`: set the collector and crash addresses to `"localhost:8080"`.
2. `App/iOS/App.swift`: add `NewRelic.enableFeatures([.NRFeatureFlag_NewEventSystem, .NRFeatureFlag_AutomaticMobileViews, .NRFeatureFlag_AutomaticSwiftUIViews])` and `NewRelic.setMaxEventBufferTime(30)`.
3. `project.pbxproj`: replace the `XCRemoteSwiftPackageReference` with an `XCLocalSwiftPackageReference` that points at your local `newrelic-ios-agent` checkout.

Afterwards, check `git diff --cached` as well as `git diff`. On one run the temporary edits got staged.

### Findings from the 2026-09-25 capture (27 visits)

- All reported names were clean, and there were 0 dangling referrers.
- **Never reported:** `HomeView` (the `NavigationStack` root), onboarding, `GameView`, `GameOverView`. `AppView` swaps them inside one root host through `Group { switch }`, so no controller changes and nothing triggers a visit. Automatic capture can't see this pattern yet.
- In-game More > Settings is a sheet, reported as `SettingsView ← SoloView`, and its visit spans its child pushes.
- Push TTID was a uniform ~550 ms on every screen.
- Pepper flagged a possible `NRMASwiftUIScreen` leak on DailyChallengeResultsView. Not yet investigated.
- **Pepper crashes the app on Settings > Developer** (`ElementDedup.isDuplicate`). Skip that screen, or flush first.

---

## SyncUps

**What it is:** TCA's reference app, a meeting timer that records stand-ups with speech transcripts. It is small, but it is the canonical example of **TCA `StackState` navigation**, a pattern many TCA customers copy.

**Location:** `~/Documents/PublicWorkspace/swift-composable-architecture/Examples/SyncUps`. It is a fork, `github.com/cdillard-NewRelic/swift-composable-architecture`, based on upstream `377da40` ("Bump to IssueReporting 2.0"). All New Relic edits are uncommitted.

### Navigation

- **Root** (`AppFeature.swift`): `NavigationStack(path: $store.scope(\.path…))` over `StackState<Path.State>`. The `Path` enum has `detail`, `meeting` and `record`.
- **SyncUpsList**: the stack root. Add is a `.sheet` inside a `NavigationStack`, and there is a "load mock data" alert.
- **SyncUpDetail**: Edit is a `.sheet`. Alerts: delete, and speech recognition denied / restricted. **Start Meeting** pushes RecordMeeting.
- **Meeting**: a past meeting's transcript.
- **RecordMeeting**: the timer and speech screen, with an end-meeting alert (save / discard).

### Build and run

- For Pepper, use workspace `Examples/SyncUps/SyncUps.xcodeproj/project.xcworkspace` and scheme **`SyncUps`**. Opening the repo's root `ComposableArchitecture.xcworkspace` also works.
- Deployment target is **iOS 26**. The bundle id is `com.newrelic.SyncUps`, and the team is changed.
- **Start Meeting fires the SpringBoard Speech Recognition prompt.** Pepper doesn't show it, and `dismiss_system` fails. `ui_tap point=` on Allow (about 274,603 on an iPhone 17 Pro) works.
- `UITesting=true` switches storage to in-memory. Under unit tests the app shows `EmptyView`.

### New Relic integration

- `SyncUps/App.swift` calls `NewRelic.start(withApplicationToken:andCollectorAddress:andCrashCollectorAddress:)` inside the `withDependencies:` closure of the static `Store`. The agent therefore starts lazily, the first time `SyncUpsApp.store` is accessed. It reports to the **staging** collectors and turns on no flags.
- It uses **remote SPM, branch `mobile-views-2`**, which resolves to the same 7.7.7 binary as isowords.

### Capturing MobileViews

Make the same three temporary edits as isowords, in `SyncUps/App.swift` and `SyncUps.xcodeproj/project.pbxproj`. After switching to the local package, delete `/tmp/DerivedData-SyncUps.xcodeproj/Build/Intermediates.noindex/SwiftExplicitPrecompiledModules`, or the build fails on a stale precompiled module.

### Findings from the 2026-09-25 capture

- **The `NavigationStack` root, `SyncUpsListView`, is never reported.** isowords' `HomeView` has the same gap.
- Stack screens are named from TCA route enums, e.g. `AppFeature.Path.State.detail`. That is correct per the naming rules (case name, never associated values), but it isn't a pretty name.
- TCA alerts show up as `PlatformAlertController`.

---

## Known issues and housekeeping

These are all true as of 2026-09-28. Fix them or delete them from this list as they're resolved.

| # | Issue | Affects |
| --- | --- | --- |
| 1 | `NRMobileNavigationLink`, `NRMobileSheet`, `NRMobileFullScreenCover`, `NRMobilePopover`, `NRMobileDestination` and `NRMobileTabTracking` are commented out in `Agent/Instrumentation/MethodProfiling/NRViewModifier.swift`. The only live SwiftUI modifiers are `NRMobileView(name:attributes:)` and `NRTrackView`. Header comments, in-app text and READMEs in NRTestApp, HomeSearch and ExpensesTracker still describe the old modifiers. | All harnesses |
| 2 | **The Contact Agent sheet can't be reached.** `.NRMobileSheet(item: $contactTarget…)` was commented out and not replaced with a plain `.sheet(item:)`, so "Request a tour" sets `contactTarget` and nothing appears. Tour Requested can't be reached either. | HomeSearch (`Screens/ListingDetailScreen.swift`) |
| 3 | The Saved tab calls `NewRelic.setCurrentView("Saved / …")`, but `ManualMobileViews` is off, so the agent drops those events (`MobileViewEmitter.isEnabled(for: .manual)`). | HomeSearch (`Screens/SavedTab.swift`) |
| 4 | HEAD doesn't compile without a local edit. `NewRelicConfig.swift` references `fallbackApplicationToken` but never defines it. Define it locally (an empty string gives capture mode), and never commit a token. | HomeSearch, ExpensesTracker |
| 5 | The pushed `mobile-views-2` `Package.swift` points at the 7.7.7 binary, so every remote-SPM consumer gets no MobileView support. Local dev builds (7.7.8-dev.N) aren't pushed. | isowords, SyncUps, HomeSearch-spm-copy |
| 6 | `NavigationStack` roots and `Group { switch }` screen swaps are never reported by automatic SwiftUI capture. | isowords, SyncUps (real-world gap, not a harness bug) |
| 7 | App tokens are hard-coded in `App.swift` in both forks, rather than injected. | isowords, SyncUps |
| 8 | Many `nrMobileViewName()` overrides in NRTestApp are commented out, so those screens report their class names. Only NilName, Restarted and Session Diagram keep active overrides. | NRTestApp |

## References

- `docs/mobileview-scenario-capture.md`: the end-to-end recipe (collector → drive → flush → render → validate).
- `scripts/mobileview_capture_collector.py`: the fake collector.
- `scripts/mobileview_flow.py`: flow and timeline renderer (`--help` lists every flag). Its output is byte-identical to the agent's `NRMASessionFlowRenderer`.
- `Agent/Public/NewRelicFeatureFlags.h`: flag definitions and defaults.
- `docs/specs/2026-09-02-mobile-views-idd.md`: the event, flag and timing contract.
