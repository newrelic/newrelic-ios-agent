# MobileViews — Design Spec

- **Date:** 2026-07-16
- **Status:** Approved design, ready for implementation planning
- **Branch:** `mobileviews-xcode-27` (POC lives here; not on `main`)
- **Author:** Chris Dillard (with Claude Code)

---

## 1. Background

A proof-of-concept for a "MobileViews" feature already exists on this branch (originally
PR #680, commits `mobile views poc` / `mobileviews-xcode-27`). It is **not** shipped — it is
off by default and not on `main`. The POC provides:

- `Agent/MobileViews/NRMAMobileViewTracker.{h,m}` — swizzles `UIViewController`
  `viewDidLoad` / `viewDidAppear:` / `viewDidDisappear:` and emits `MobileView` custom events.
- SwiftUI support in `Agent/Instrumentation/MethodProfiling/NRViewModifier.swift`:
  `.NRMobileView(name:attributes:ignored:)` plus wrappers for navigation, sheets, popovers,
  and tab tracking.
- Custom naming hooks (no protocol adoption required): UIKit `nrMobileViewName` /
  `nrMobileViewAttributes` (return `nil` from `nrMobileViewName` to ignore a view);
  SwiftUI `name:` / `attributes:` / `ignored:` parameters.
- Feature flag `NRFeatureFlag_MobileViews` (`1<<25`), off by default, wired at
  `Agent/General/NewRelicAgentInternal.m:336`.

The current shipping agent has `recordBreadcrumb:` (`Agent/Public/NewRelic.m:740`), Interaction
Traces (`startInteractionWithName:`), and Session Replay. It has **no** MobileViews and **no**
concept of a "previous/referrer view."

This spec hardens the POC into a shippable feature and adds the three capabilities below.

## 2. User stories

1. **Manual view lifecycles / renaming** — As a mobile engineer, I want to manually record
   custom view lifecycles so that when automatic instrumentation misses a view or names it
   wrong, or when the business needs views renamed, I can control it. (Mirae Assets)
2. **Referrer (view before a breadcrumb)** — As a mobile engineer, I want to know the view that
   loaded before a breadcrumb (like a browser referrer) so I can track navigation paths.
   Consumers: User Journeys, Event Trails, Session Replay player playhead. (First Light Media)
3. **Accurate screen names for React Native** — As a mobile engineer, I need accurate screen
   names so I can build a "Top 5 Slowest Screens" report. React Native interactions surface
   generic host names (the Android analog is `MainActivity`); on iOS, RN hosts every screen in a
   single `UIViewController`, so automatic tracking collapses to one name. Applies to **Views &
   Interactions**. (Sporta Technologies)

### Story → mechanism map

| Story | Mechanism |
|-------|-----------|
| 1 (manual / rename) | New public `setCurrentView:attributes:` API (+ existing POC naming hooks) |
| 2 (referrer) | New `NRMAViewContext` tracks current/previous; stamped on breadcrumbs **and** MobileView events |
| 3 (React Native) | `setCurrentView:` called by the RN bridge with the real JS screen name; also names the running interaction trace |

## 3. Goals / non-goals

**Goals**
- Ship the POC's automatic view tracking as a production feature (thread-safe, tested, documented).
- A single, bridge-friendly manual API: `setCurrentView:attributes:` (SPA / route-change model).
- Referrer attributes on breadcrumbs and MobileView events.
- Two independent feature flags with fully-specified interaction semantics.
- Fix the load/visible timing **units bug** (POC emits seconds; must be ms).

**Non-goals (this repo / this spec)**
- The React Native JS + bridge changes (live in `newrelic-react-native-agent`). We only ship the
  native entry point and guarantee it is bridge-callable.
- Android parity.
- Backend / NRQL / dashboard work for "Top 5 Slowest Screens" and User Journeys.
- watchOS automatic tracking (remains `#if !TARGET_OS_WATCH`-guarded).
- Auto-dedup when both flags are on (see §6.5).

## 4. Architecture overview

One new internal component is the single source of truth for "what view is the user on":
**`NRMAViewContext`**. Every view producer writes to it; every event that needs a referrer reads
from it.

```
Producers (independently flag-gated)        Shared truth              Consumers
────────────────────────────────────        ───────────────           ─────────────────────────
UIKit swizzle (AutomaticViews) ─┐
SwiftUI .NRMobileView (Auto)  ──┼──►  NRMAViewContext  ──►  MobileView events (+ previousView)
setCurrentView() (ManualViews) ─┘     current / previous     recordBreadcrumb (+ currentView,
                                       + ms timing helper                       previousView)
                                                             running interaction trace name
```

Guiding rule for the two flags:

> Each flag gates only its own producer. `NRMAViewContext` and the referrer stamping are active
> whenever **either** flag is on. Both off ⇒ no MobileView events and no referrer.

## 5. Component: `NRMAViewContext` (new)

New file(s): `Agent/MobileViews/NRMAViewContext.{h,m}`.

Thread-safe singleton (an `os_unfair_lock` / `dispatch_queue` guards all mutable state, because
view transitions happen on the main thread while breadcrumbs and events are recorded from
arbitrary threads).

State:
- `currentViewName`, `currentViewInstanceId`, `currentViewAppearTime` (`CFAbsoluteTime`, seconds)
- `previousViewName`, `previousViewInstanceId`

Internal API:
- `- (void) transitionToView:(NSString *)name
                  instanceId:(NSString *)instanceId
                  appearTime:(CFAbsoluteTime)appearTime;`
  Shifts `current → previous`, installs the new current. Called by all three producers.
- `- (NSDictionary *) referrerAttributes;`
  Returns `{ currentView, previousView, previousViewInstanceId }` (omitting nil values) for any
  event that wants the referrer. Snapshotted under the lock.
- `+ (double) millisecondsBetween:(CFAbsoluteTime)start and:(CFAbsoluteTime)end;`
  **Single** seconds→ms conversion helper (`(end - start) * 1000.0`, floored at 0). All three
  producers and the background flush use this so the unit can never drift again.

## 6. Component designs

### 6.1 Automatic tracking (harden POC — UIKit)

`NRMAMobileViewTracker.m`:
- On `viewDidAppear:`, after building the MobileView event, call
  `[NRMAViewContext transitionToView:...]` and include `referrerAttributes` (`previousView`) on
  the emitted event.
- On `viewDidDisappear:`, compute `loadTime` / `timeVisible` via
  `NRMAViewContext millisecondsBetween:and:` (**ms**, see §7).
- Keep the existing per-instance associated-object timing, `restarted` logic, class-prefix skip
  list, Swift demangling, and the `nrMobileViewName`/`nrMobileViewAttributes` hooks. Remove "POC"
  labels and finalize doc comments.

### 6.2 Automatic tracking (harden POC — SwiftUI)

`NRViewModifier.swift`:
- On `onAppear`, call `NRMAViewContext.transitionToView` and include `previousView`.
- Compute `loadTime` / `timeVisible` in **ms** via the shared helper (currently seconds; §7).
- Audit the experimental `NRMobileTabTracking` dwell logic (`Task.sleep`) and `@State` timing;
  add tests or mark clearly experimental.

### 6.3 Manual API — `setCurrentView` (Stories 1 & 3)

New public method on `NewRelic` (`Agent/Public/NewRelic.h` + `NewRelic.m`), `@objc`-exposed so
the React Native bridge and Swift both call it with simple bridge-friendly types:

```objc
+ (void) setCurrentView:(NSString * _Nonnull)name
             attributes:(NSDictionary * _Nullable)attributes;
```

Behavior (browser route-change / SPA model):
1. If `NRFeatureFlag_ManualViews` is off → verbose log, no-op (never crashes, never emits).
2. If a current view exists, emit its MobileView `appeared:NO` event with
   `timeVisible = ms(currentViewAppearTime → now)`.
3. `NRMAViewContext transitionToView:` (current → previous, new appearTime = now).
4. Emit the new view's MobileView `appeared:YES` event, stamped with `previousView` (referrer).
5. Name the running interaction trace (see §6.6).

- **Story 1:** native engineers call `setCurrentView("Checkout")` where automatic instrumentation
  missed or mislabeled a screen.
- **Story 3:** the RN navigation listener calls it on every screen focus with the real JS screen
  name, replacing the generic host-VC name. The RN apps run with **AutomaticViews off** and
  **ManualViews on**, so there is no generic host noise and no double-counting.

### 6.4 Referrer stamping (Story 2)

- **Breadcrumbs:** in `NewRelic.m:740 recordBreadcrumb:attributes:`, merge
  `NRMAViewContext.referrerAttributes` (`currentView` + `previousView`) into the breadcrumb
  attributes before `addBreadcrumb:withAttributes:`. Reserved keys win over caller-supplied ones.
- **MobileView events:** add `previousView` (+ `previousViewInstanceId`) to the attribute set
  every producer emits.
- Attribute names (ours to define; no fixed platform contract): **`currentView`**,
  **`previousView`**, **`previousViewInstanceId`**.
- Referrer stamping runs only when `NRMAViewContext` is active (AutomaticViews OR ManualViews).

### 6.5 Feature flags (renamed; two independent flags)

`Agent/Public/NewRelicFeatureFlags.h` + `Agent/FeatureFlags/NRMAFlags.{h,m}`:

- **Rename** `NRFeatureFlag_MobileViews` → **`NRFeatureFlag_AutomaticViews`** (`1<<25`) — gates
  the UIKit swizzle + SwiftUI auto-appear tracking. Rename `shouldEnableMobileViews` →
  `shouldEnableAutomaticViews`; update `NewRelicAgentInternal.m:336`. (Safe: nothing ships yet.)
- **Add** **`NRFeatureFlag_ManualViews`** (`1<<26`), off by default — gates `setCurrentView`.

Truth table:

| AutomaticViews | ManualViews | Swizzle/SwiftUI auto | `setCurrentView()` | Referrer on breadcrumbs | Typical consumer |
|:---:|:---:|:---:|:---:|:---:|---|
| OFF | OFF | off | no-op (verbose log) | none | default today |
| ON | OFF | on | no-op (verbose log) | ✅ from auto | native, auto only |
| OFF | ON | off | works | ✅ from manual | **React Native** |
| ON | ON | on | works | ✅ from both | native + manual overrides |

Conflict case (**both ON**): a native screen can emit two MobileView events if a developer both
auto-tracks it and calls `setCurrentView` on it. We do **not** auto-dedup (too magical). Devs
mixing both suppress the automatic event per-screen using the existing POC mechanisms —
`nrMobileViewName` returning `nil` (UIKit) or `.NRMobileView(ignored: true)` (SwiftUI). Documented
as advanced usage.

### 6.6 Interaction naming (Story 3 — "Views & Interactions")

`setCurrentView` also sets the name of the running interaction trace so React Native interactions
stop showing generic host names, aligning with the existing `startInteractionWithName:`
mechanism. Exact hook point (interaction controller vs. public shim) to be finalized during
planning; treat as a required part of Story 3, not optional.

### 6.7 Background flush

Hook the existing `applicationDidEnterBackground` (`NewRelicAgentInternal.m:922`) to emit the
current view's `appeared:NO` / `timeVisible` (via the ms helper) so the last visible view's
duration is not lost when the app backgrounds or terminates.

## 7. Units fix (seconds → ms)

The POC computes **seconds** everywhere but documents **ms**. Fix all producers to emit **ms**
through the single `NRMAViewContext millisecondsBetween:and:` helper:

| Path | Line (current) | Today | Fix |
|------|----------------|-------|-----|
| UIKit | `NRMAMobileViewTracker.m:279` | `disappear − appear` (sec) | `× 1000` via helper; rename `…Sec → …Ms` |
| UIKit | `NRMAMobileViewTracker.m:282` | `appear − load` (sec) | `× 1000` via helper |
| SwiftUI | `NRViewModifier.swift:78` | `timeIntervalSince` (sec) | `× 1000` via helper |
| SwiftUI | `NRViewModifier.swift:99` | `timeIntervalSince` (sec) | `× 1000` via helper |
| Doc | `NewRelicFeatureFlags.h:87` | claims `(ms)` | keep `(ms)`; now accurate |

Event keys stay `loadTime` / `timeVisible`.

## 8. MobileView event schema

Event type: `MobileView`. Attributes (reserved keys always win over caller-supplied ones):

| Attribute | Type | Notes |
|-----------|------|-------|
| `viewClass` | string | Fully-qualified demangled class (auto). For manual, equals `viewName`. |
| `viewName` | string | Display name (custom hook, `setCurrentView` name, or demangled class). |
| `viewInstanceId` | string (UUID) | Unique per visible lifetime. |
| `previousView` | string | **New** — referrer. |
| `previousViewInstanceId` | string | **New**. |
| `restarted` | bool | NO on first appearance, YES thereafter. |
| `loadTime` | double (**ms**) | On `appeared:YES`. |
| `timeVisible` | double (**ms**) | On `appeared:NO`. |
| `appeared` | bool | YES on appear, NO on disappear. |
| `uiPlatform` | string | `UIKit` / `SwiftUI` / (manual: see planning). |
| `agentName` | string | `iOS`. |
| *custom* | any | From `nrMobileViewAttributes` / `.NRMobileView(attributes:)` / `setCurrentView` attributes. |

Breadcrumb events additionally receive `currentView` + `previousView` (+ `previousViewInstanceId`).

## 9. Testing plan

No MobileViews tests exist today. Add unit coverage for:
- Swift name demangling / module stripping (`NRMA_DemangledName`, `NRMA_StripOuterModule`).
- `NRMAViewContext` current→previous shifting and `referrerAttributes` snapshotting.
- `restarted` transitions.
- Reserved-key precedence (custom attrs cannot overwrite reserved keys).
- Ignore-via-`nil` (UIKit) and `.NRMobileView(ignored:)` (SwiftUI).
- `setCurrentView` transition sequence (disappear previous → appear new → referrer set).
- Breadcrumb referrer stamping.
- Units: emitted `loadTime`/`timeVisible` are ms.
- Flag matrix: the four rows of §6.5 behave as specified; `setCurrentView` is a safe no-op when
  ManualViews is off.
- Thread-safety: concurrent breadcrumb recording during a view transition.

Test harness: the POC already added `MobileViewAttributes*` / `MobileViewIgnored*` demo screens in
NRTestApp. Add a `setCurrentView` demo and a referrer/breadcrumb demo.

> Note (from project memory): `xcodebuild test` currently fails linking `libOCMock.a` under the
> Xcode 27 beta. Verify ObjC changes via the isolated clang harness + `xcodebuild build`; run the
> full unit suite where the toolchain allows.

## 10. Rollout

- Both flags off by default. Ship dark; enable AutomaticViews for validation first and confirm
  MobileView event volume before wider enablement.
- ManualViews can be enabled independently for RN / manual adopters.

## 11. Risks / open questions

- **Interaction-naming hook point (§6.6)** — exact integration with the interaction controller to
  be finalized in planning.
- **Both-flags-on double emission (§6.5)** — mitigated by existing ignore hooks + docs; confirm
  this is acceptable for GA.
- **`uiPlatform` value for manual/RN events** — `Manual`, `ReactNative`, or caller-supplied?
  Decide in planning.
- **SwiftUI `loadTime` semantics** — "modifier creation → onAppear" is an approximation; document
  the caveat.

## 12. File change map

- **New:** `Agent/MobileViews/NRMAViewContext.{h,m}`
- **Edit:** `Agent/MobileViews/NRMAMobileViewTracker.m` (route through context, ms, de-POC)
- **Edit:** `Agent/Instrumentation/MethodProfiling/NRViewModifier.swift` (context, ms)
- **Edit:** `Agent/Public/NewRelic.{h,m}` (`setCurrentView:attributes:`; referrer in `recordBreadcrumb:`)
- **Edit:** `Agent/Public/NewRelicFeatureFlags.h` (rename flag, add `NRFeatureFlag_ManualViews`, doc)
- **Edit:** `Agent/FeatureFlags/NRMAFlags.{h,m}` (rename `shouldEnableMobileViews` → `shouldEnableAutomaticViews`, add `shouldEnableManualViews`)
- **Edit:** `Agent/General/NewRelicAgentInternal.m` (flag rename at :336; background flush at :922)
- **Edit:** `Agent/APrivateHeader.h` (import `NRMAViewContext.h` if needed)
- **New tests:** MobileViews unit tests (see §9)
- **Edit:** NRTestApp demo screens (`setCurrentView`, referrer)
