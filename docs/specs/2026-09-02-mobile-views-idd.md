# Mobile Views Initiative Design Doc (IDD)

> Markdown copy of the Confluence page
> [Mobile Views Initiative Design Doc (IDD)](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5548769647),
> synced 2026-10-21. Inline comments are not copied.

| | | |
| --- | --- | --- |
| Status | In Review | |
| Start Date | 05/05/2026 | |
| Due Date | 10/30/2026 | |
| Architect/Driver | Justin Rush, Chris Dillard | |
| Product Manager | Cheryl Frankenfield | |
| Single Threaded Leader | Chris Dillard | |
| Link to product doc | [Docs draft - Mobile views \*WIP\*](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/3902931300/Docs+draft+-+Mobile+views+WIP) | |
| Link to JIRA Initiative | [NR-356639](https://new-relic.atlassian.net/browse/NR-356639) | |
| Link to Production Readiness Checklist | [Template is here](https://newrelic.atlassian.net/wiki/templates?template=2608824354) | |
| Reviewers | Justin Rush<br>Ying Wang 9-30-26<br>Mike Bruin<br>Nisarg Desai<br>9-16-26 revised version review<br>AppEx:<br>Jodi 'JBJ' Kansagor<br>Sara Schultz<br>Product:<br>Cheryl Frankenfield 5-8-2026, 9-16-26 revised version review | September 16, 2026<br>AppExp: ✅ 10/2/2026 |
| Informed | Puneet Arora, Nanda Kishor Jeripothula<br>DEMPLA:<br>David Gay (David please add an engineer if needed) | |
| API Reviewers | Name | Date Reviewed |

---

## 1. Problem

Customers instrumenting with any New Relic mobile agent — iOS, Android, React Native, Flutter,
Capacitor/Cordova, .NET MAUI — can already see HTTP requests, requests, ~~interactions~~, events, and crashes.
None of them provides a built-in way to measure **which screens users visit, how long each screen takes to
load, or how long users spend on each screen**.

Today that requires hand-instrumenting every screen with `recordCustomEvent` and picking a custom event name.
Customers could pick custom event name = “MobileView” which would conflict with our chosen event name.
(Discussed in Collision Analysis below) Or calling recordBreadcrumb with a custom breadcrumb name. Many
customers tend to use our breadcrumb feature for view tracking. This is error-prone and inconsistent within a
single app, and inconsistent *between* platforms.

- Collision Analysis: It was determined no customers use “MobileView” or “MobileViewTiming” event name
  currently so we can use it. Checked on 10/19/2026 by Justin Rush with this
  [NR1 query](https://onenr.io/0Bj35OaOJwX). After upgrading, recordCustomEvent rejects both names, so release
  notes must say an app already sending either one stops sending it. Slack context
  [here](https://newrelic.slack.com/archives/C08T8SS3V8X/p1792091952893629?thread_ts=1792088433.878829&cid=C08T8SS3V8X).
- MobileViews documentation and MobileViews release notes will incorporate information about how
  recordCustomEvent rejects both names “MobileView” and “MobileViewTiming”.

## 2. Background

Four properties are already true of every agent, and this initiative is designed to exploit them rather
than add infrastructure:

- Each ships a **build in New Relic event support**. We can add MobileView and MobileViewTiming as new first
  class New Relic events in the same namespace “Mobile General” as normal Mobile events and omit category. This
  gives us 8 / 98 day retention.
- Each performs some form of **lifecycle-aware auto-instrumentation** already, by whatever mechanism suits its
  runtime.
- Each has a **feature-flag mechanism** supporting default-off. Disabled by default; enabled by server config,
  which overrides the local flag in both directions. If no config arrives, local feature flag API calls apply.
  Manual Views feature flag is only controlled with local feature flag API calls.
- No new transport, no new ingest path. “MobileView” registered as first class event with DEM PLATFORM.
  [PR](https://source.datanerd.us/mobile/mobile_data_services/pull/2257)
  [Code](https://source.datanerd.us/mobile/mobile_data_services/blob/579928b912527d55706fe244859c68f3935a9722/mobile_events/src/main/java/com/newrelic/mobile/event/EventRetentionPolicy.java#L27)
  MobileViewTiming registered as first class event in
  [PR](https://source.datanerd.us/mobile/mobile_data_services/pull/2270).

## 3. Goals

1. **Automatic per-screen events with zero (or very little) customer code** when the flag is on, across iOS
   (UIKit, SwiftUI), Android (Activity, Fragment, Compose), React Native, Flutter, Capacitor/Cordova, and .NET
   MAUI.
2. **An identical schema from every agent** (§5.3), so cross-platform dashboards are trivial.
3. **Either use automatically instrumented view name or optionally use a customer-supplied display name per
   screen**. The NRMobileView view modifier and UIViewController overrides allow this.
4. **A manual naming API** for hosts where native lifecycle tracking cannot see screens (§5.5).
5. **Zero impact when disabled.** With all Mobile Views flags off, the agent must be byte-for-byte unchanged:
   no new attribute on any existing event, and no call into the view subsystem from any other subsystem.
6. Potential Post GA Additions:
    1. ~~**Opt-out API.** Every platform needs a "do not track this screen" hook for splash screens, modals, and
       tab containers. The capability is required (§6); iOS has settled on a shape, other agents have not.~~

## 4. Costs

- Events per visit once enabled: 1 MobileView, 1 baseline timing, and up to 16 customer timings.
- A typical-session estimate would be 100s of views every 10 minutes.
- Events are billable ingest.
- These events can push customer events out of the 1000-event buffer. (The cap of 16 only covers customer
  timings.) At 100s of views per 10 minutes and about 2 events per view, that's on the order of 100 events per
  60-second harvest, well below the 1000-event limit. Eviction takes very rapid navigation or many views with
  customer timings near the cap of 16.

## 5. Specification

### 5.1 Architecture

Every agent implements the same four-stage pipeline. Only the first stage is platform-specific.

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  1. PRODUCERS  (platform-specific — owned by each CDD)               │
  │                                                                      │
  │  Host runtime lifecycle or navigation signals, by whatever mechanism │
  │  is native to that runtime. One or more producers per agent.         │
  │  Automatic producers and the manual API are peers here.              │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  2. VIEW CONTEXT  (per agent, single instance)                       │
  │                                                                      │
  │  Thread-safe source of truth for current view + referrer. All        │
  │  producers funnel through it, so identity and ordering are consistent│
  │  no matter which producer is active. Assigns viewInstanceId.         │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  3. EVENT EMISSION                                                   │
  │     MobileEvent("MobileView", attrs)  — schema per §5.3              │
  │     MobileEvent("MobileViewTiming", attrs) — §5.7                    │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  4. EXISTING HARVEST PIPELINE  →  NRDB: MobileView / MobileViewTiming│
  └──────────────────────────────────────────────────────────────────────┘
```

### 5.2 Producer contract

A producer is anything that can observe a screen becoming or ceasing to be visible. Each agent decides how
many it needs and how each hooks its runtime, that is CDD material. What every producer must satisfy:

| Requirement | Why it is initiative-level |
| --- | --- |
| Report appearance and disappearance as a visit, One MobileView containing `viewInstanceId` | - |
| Funnel through the shared view context rather than emitting directly | Otherwise `previousView` diverges between producers |
| Declare a `uiFramework` value from the enumerated set | It is the discriminator every cross-platform query facets on |
| Be inert when its gating flag is off | Goal 5 |

Hybrid agents (Capacitor, Cordova, MAUI) **reuse the native iOS and Android producers** through their
bridge layer and expose only a thin JS/C# surface. Screens the native producer sees report the native
uiFramework (UIKit, SwiftUI, AndroidActivity, …); screens the wrapper names through capability 3 report
Capacitor, Cordova or MAUI. React Native and Flutter require their own producers,
because navigation state lives in JS/Dart and native lifecycle callbacks do not fire per screen.

### 5.3 MobileView Event schema

Event namespace `Mobile General`; event name `MobileView`.

1. All durations on MobileView and MobileViewTiming are in milliseconds. This is a deliberate exception to
   timeSinceLoad, the existing attribute on every mobile event, which is in seconds and so isn't listed here. Every agent also adds its standard event attributes (sessionId,
   appName, hasReplay while Session Replay is recording, …); they aren't listed here either.

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `viewClass` | string | ✅<br>In Manual case the viewClass is passed in | Automatically inferred Platform-native class or type name (Always available.) |
| `viewName` | string | ✅<br>In Manual case the viewName is passed in | Customer override (capability 4), else the inferred route pattern, class or struct name. |
| `viewInstanceId` | string (UUID) | ✅ | Unique per visible lifetime; the join key |
| `loadTime` | double (milliseconds) (ms) | or if not available: loadTimeUnavailable | Best-effort; semantics and accuracy tier per §5.4 |
| `loadTimeUnavailable` | string | only if loadTime unavailable. | - noConstructionObserved: no construction start was seen for this visit, or it was more than 600000 ms before the screen appeared.<br>- notRebuilt: the view's identity was preserved, so nothing was rebuilt.<br>- noLoadStartDeclared: a manual view without capability 9.<br>Closed set; new values only by amending this IDD. |
| `timeVisible` | double (milliseconds) (ms) | ✅ | Appear → disappear, clamped ≥ 0 |
| uiFramework | string | ✅ | Enum: `UIKit`, `SwiftUI`, `AndroidActivity`, `AndroidFragment`, `Compose`, `ReactNative`, `Flutter`, `Capacitor`, `Cordova`, `MAUI`, `Manual`<br>Manual: a manual view whose caller passed Manual or no uiFramework. Values are added by IDD amendment and never renamed or removed; queries treat unknown values as other.<br>`WebView` will be added when supported post GA. |
| `previousView` | string | when known | Referrer: the screen navigated from |
| `previousViewInstanceId` | string | when known | Referrer identity, for exact-visit joins |
| `containsWebView` | boolean | ✅ automatic producers; omitted on Manual | A visible in-process web view was in the screen's view tree, including embedded children, at any point in the visit. §5.3.7 |
| `isFullScreenWebView` | boolean | ✅ automatic producers; omitted on Manual | One web view covered ≥ 80% of the screen's content area at any point in the visit. Implies `containsWebView`. §5.3.7 |
| `isTopLevelView` | boolean | ✅ automatic producers; omitted on Manual | A screen in its own right; `false` for a controller embedded in another tracked screen. §5.3.7 |

#### 5.3.1 Additional Future Attributes for post-GA:

- restarted, reappeared: out of scope for GA.
- **App Hang Detection, Slow/Frozen/Janky Frame Detection**:
  - totalFrameCount — display refreshes the agent observed while this view was the current view. Could be
    used with timeVisible calculation.
  - droppedFrameCount — frames lost. Summed across the visit: for each observed interval,
    round(actual / expected) - 1.
  - jankyFrameCount — stall occurrences. Number of frames that missed their deadline at all, regardless of by
    how much.
  - frozenFrameCount — occurrences over the frozen threshold (700 ms, matching Android's definition), a strict
    subset of jankyFrameCount.

#### 5.3.2 uiFramework Discussion

The implemented iOS agent emits `uiFramework` and avoids collision with the ambient notion of platform
elsewhere in the product. Adopting the implemented name is also the only option that does not require a
breaking rename in shipped iOS code. **Every other agent must emit** `uiFramework`.

- `uiFramework` names the producer; use `platform` for the SDK.

#### 5.3.3 navigation graph

`previousView` / `previousViewInstanceId` are new attributes added to MobileView events. They turn a list of
screen visits into a **navigation graph ([demo](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/4387242580))**,
which is what makes the data explanatory rather than descriptive: the same screen can be shown to be fast when
reached from search and slow when reached from a deeplink.

#### 5.3.4 loadTime and loadTimeUnavailable

exactly one of the two attributes is always present. A manual view declared without a load start will get
**loadTimeUnavailable**. A manual view with capability 9 carries a loadTime.

#### 5.3.5 viewName Privacy

Producers that name screens from routes (React Native, Flutter, Capacitor/Cordova) emit the route pattern
(/user/:id/orders), never the resolved path. viewName, previousView and currentView are truncated at 128
characters. Agents don't scrub view names; customers who name screens from data use capability 4.

#### 5.3.6 Agent-owned MobileViewTiming emission

Independently of anything the customer calls, **every agent emits one baseline timing per MobileView event
automatically.**

- **Name:** `timeToInitialDisplay` — the same string on every agent.
- **Value:** projected from the `loadTime` the agent already measures for that appearance. This is a second
  projection of an existing number, not a new measurement: no new hook, no new swizzle, no added cost.
- **When:** on every `MobileView` visit that carries `loadTime`. A screen that resurfaced without being
  rebuilt emits no baseline MobileViewTiming event, mirroring the `loadTime` rule in §5.4 — nothing was
  constructed, so there is nothing to time. One MobileView per visit, sent when the visit closes: the screen
  disappears, a new manual view is set, or the app backgrounds. Foregrounding starts a new visit with a new
  viewInstanceId and no loadTime. A visit still open at a crash or kill isn't sent; its timeToInitialDisplay
  timing, sent at appear, is.

This matters for three reasons that are all cross-platform:

1. **Every timing dashboard populates with zero customer code.** Without it, a customer who has not yet
   instrumented anything sees empty charts and concludes the feature does not work.
2. **It puts customer marks on the same axis as the agent's own.** `timeToFullDisplay` minus
   `timeToInitialDisplay` is the interval during which the screen looked finished but was not — the single
   most useful number this initiative produces, and it requires both series to exist in the same event type
   with the same units.
3. **It is the coverage signal.** Screens reporting *only* `timeToInitialDisplay` are exactly the screens still
   lacking customer instrumentation.

Consequently the `timeToInitialDisplay` baseline is exempt from the per-view cap. `timeToInitialDisplay` is
**reserved** — capabilities 7 and 8 must reject it.

#### 5.3.7 Screen composition: containsWebView, isFullScreenWebView, isTopLevelView

Why: web content loads after the screen appears, so a web screen's `loadTime` / `timeVisible` read
differently from a native one's; and embedded child views are visits of their own that do not belong in
flow and funnel queries.

- **Always present on automatic events.** `WHERE containsWebView IS false` must match every native
  screen. Manual (`setCurrentView:`) events omit all three: the agent never sees those screens.
- **Any point in the visit.** The event is written when the visit ends, so a web view added or grown
  after appear still counts. iOS samples at appear, `viewWillDisappear:`, close (if still on screen),
  and whenever a `WKWebView` moves into or out of a window. There is no sampling on layout: a web view
  that grows and shrinks back between those moments is reported at the size it had at them.
- **What counts as a web view.** In-process `WKWebView` (and subclasses) that is visible: not hidden or
  transparent, itself or any ancestor, and not clipped away entirely. Out-of-process web content
  (`SFSafariViewController`, `ASWebAuthenticationSession`) and the deprecated `UIWebView` do not count.
- **Content area.** The controller's visible bounds minus its safe area, which removes the status bar,
  home indicator and any navigation, tab or tool bar laid over it. That is what makes the 80% threshold
  hold on iPhone, iPad and in landscape. The threshold applies to *one* web view; several small ones
  never add up. A child controller's own event is measured against the child's content area.
- **isTopLevelView.** Walk up the parent chain to the first ancestor that decides it: a navigation
  container (navigation, tab bar, split view, page view controller, subclasses included, and SwiftUI's
  private equivalents) → `true`; a tracked screen (embedding via `addChild`, directly or through a
  customer's own container) → `false`; no parent (a modal root) → `true`. Untracked hosts are skipped.
  Stopping at the *first* container rather than requiring every ancestor to be one keeps apps whose
  navigation lives inside a custom root container (a drawer, a screen embedding a `UITabBarController`)
  from reporting every screen as embedded.
- **Embedded visits stay out of the flow (UIKit).** A non-top-level controller still reports its visit,
  but never becomes the current view: it is never another screen's `previousView`, carries none of its
  own, and records no `timeToInitialDisplay` baseline; breadcrumbs and `markViewTiming:` while it is up
  belong to the screen that embeds it. The `.NRMobileView` modifier reports `isTopLevelView` but does
  not yet apply this rule, because it opens its visit before its hosting controller is known.
- **Independent of `NRFeatureFlag_WebViewInstrumentation`.** Detection uses its own `WKWebView`
  window-move observer and enables no web view network instrumentation.
- **Hybrid frameworks.** Capacitor and Cordova render in a `WKWebView` filling their bridge controller,
  so the natively observed screen reports `true` / `true`. React Native and Flutter render natively and
  report `false` / `false`. Routes the wrapper names through `setCurrentView:` are manual events and omit
  the attributes.

### 5.4 `loadTime` semantics and accuracy tiers

`loadTime` is **best-effort and not equally meaningful across runtimes**. Some runtimes expose an exact
construction-to-visible boundary; others only permit an approximation. Comparing an exact value against an
approximate one without knowing which is which produces confidently wrong conclusions, so the tier is declared
per platform in the table below.

**Contract:**

1. Each agent's CDD **declares its own mapping** from runtime lifecycle signals to `loadTime`, and states the
   resulting tier.
2. `loadTime` is **only for a genuine first construction**. A screen that resurfaced without being rebuilt has
   nothing to time: it omits loadTime and sets loadTimeUnavailable: notRebuilt. A measured 0 ms is sent as 0.
    1. attribute **loadTimeUnavailable**: with value **noLoadStartDeclared**, **noConstructionObserved**, or
       **notRebuilt** will be added to specify loadTime omission reason.
3. Values are non-negative and monotonic-clock derived. Wall-clock deltas are not acceptable, clock adjustment
   mid-load would otherwise produce negative or absurd durations.
4. All agents emit the **same unit**. Unit drift between agents is the single most likely way to corrupt a
   cross-platform percentile, and it is invisible in the data.

**Tier per platform** (mapping detail lives in each CDD):

| Platform | Tier |
| --- | --- |
| UIKit | Exact |
| Android Activity | Exact |
| Android Fragment | Exact |
| SwiftUI | Approximate |
| Manual (`setCurrentView`) | None, unless the customer declares a load start via capability 9 |
| Jetpack Compose | Approximate |
| React Native | Approximate, subject to JS-thread contention |
| Flutter | Approximate |
| Capacitor / Cordova | Approximate |
| MAUI | Approximate |

Because approximate is the common case, `loadTime` alone is insufficient for the product goal. §5.7 is the
answer.

### 5.5 Feature-flag model

Automatic and manual tracking are **independent flags**. Automatic is disabled by default. This will be hooked
up to a feature flag via our config (same as Logs)

| Flag | Gates |
| --- | --- |
| Automatic Mobile Views (Disabled by Default) | All automatic producers for that agent's native UI runtimes |
| Manual Mobile Views (Disabled by Default) | The manual "set current view" API |

- **Either** flag enables the shared referrer plumbing (`currentView` / `previousView` on breadcrumbs).
- With **both** off, Goal 5 applies strictly: no new attribute anywhere, and no other subsystem calls into the
  view subsystem.

**Why two flags rather than one.** A React Native or Capacitor host must be able to enable **manual only**. Its
native automatic producer would report a single generic host container for the entire app, pure noise, while
the JS layer is the only thing that knows the real screen names. One combined flag forces that host to choose
between no data and bad data. This is the load-bearing reason the split exists, and it generalizes to every
hybrid runtime.

### 5.6 Config

We will follow the remote configuration mechanism that is used for Mobile Logs.

- NR1 app setting accessible via Mobile Application Settings page of new relic UI.
- If no config “mobile_views” flag arrives with first connect it will use the local feature flag API.
- Cached config is used until /connect is called again.
  - Proposed config schema change adding mobile_views:

```
"configuration": {
		"logs": {
			"enabled": true,
			"level": "DEBUG",
			"sampling_rate": 100.0
		},
		"application_exit_info": {
			"enabled": true
		},
		"session_replay": {
			"enabled": true
        },
        "mobile_views": {
			"enabled": true
        }
    }
```

#### 5.7 Companion event: `MobileViewTiming`

`loadTime` is fixed at the moment a screen becomes visible. For most runtimes that is *also* the moment the
screen is still showing a spinner: a screen that renders a skeleton in 80 ms and real content in 900 ms
reports 80 ms.

`MobileViewTiming` is therefore a **separate, streamed event — one per timing, sent as soon as its value is
known** — modeled on browser's `PageViewTiming`.

Initiative-level requirements:

| Requirement | Rationale |
| --- | --- |
| Every timing carries `viewInstanceId` | Joins the timing to the specific *visit*, not merely the screen name |
| Every timing carries `previousView` when known | Makes timings queryable by route, per §5.3 |
| One agent-owned baseline timing is emitted with no customer code | Guarantees dashboards populate for every customer, and puts customer marks on the same axis as the agent's own |
| Customer marks share the baseline's origin whenever one exists | Makes the marks *enclose* the baseline, which is the only arrangement in which subtracting them yields a real interval (§6.2) |
| Customer timings are capped per view instance | An unguarded mark inside a list-row callback would evict the customer's own real events from a bounded buffer |
| Non-finite, negative, and implausibly large durations are rejected | A single `NaN` silently poisons every average and percentile downstream |
| Reserved timing names are rejected from the public API | Keeps the out-of-the-box series comparable across apps |
| `loadTime` remains on `MobileView` | Additive by design; removing it breaks already-shipped panels |

### 5.8 `MobileViewTiming` schema

Event namespace `Mobile General`; event name `MobileViewTiming`.

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `timingName` | string | ✅ | timeToInitialDisplay (agent-owned, §5.3.6) or a customer-supplied name (§6.2). Customer names are validated per §6.3. |
| `timingValue` | double (ms) | ✅ | Duration in **milliseconds**. Finite, ≥ 0, ≤ 600000 (§6.3) |
| `viewName` | string | when a view is current | The screen the timing is about |
| `viewInstanceId` | string (UUID) | when a view is current | Join key back to the exact `MobileView` **visit** that produced it |
| `previousView` | string | when known | Referrer, so timings are queryable by route rather than only by destination |

### 5.8.1 MobileViewTiming timing details

*The timing origin is the time that view construction starts.* This value is shown as loadStart below.

A mark must be measured from the same instant the baseline is, so that the mark **encloses** the baseline:

```markdown
loadStart              appear                    mark
    |--------------------|----------------------->|
    |<---- TTID -------->|                        |
    |<---------------- TTFD ------------------->  |
```

example JSON:

```json
[
  {
    "eventType": "MobileView",
    "timestamp": 1792532153348,
    "viewName": "UtilitiesViewController",
    "viewClass": "NRTestApp.UtilitiesViewController",
    "viewInstanceId": "274F53A9-772B-4990-B96C-624B4B04E9A0",
    "uiFramework": "UIKit",
    "loadTime": 538.1820000475273,
    "timeVisible": 12747.192208946217,
    "previousView": "ViewController",
    "previousViewInstanceId": "C9E001DB-17D5-4436-817E-2861DE041BEF",
    "timeSinceLoad": 45.348809003829956
  },
  {
    "eventType": "MobileViewTiming",
    "timestamp": 1792532140602,
    "timingName": "timeToInitialDisplay",
    "timingValue": 538.1820000475273,
    "viewName": "UtilitiesViewController",
    "viewInstanceId": "274F53A9-772B-4990-B96C-624B4B04E9A0",
    "previousView": "ViewController",
    "timeSinceLoad": 32.6024169921875
  }
]
```

for the loadTimeUnavailable rule in §5.3/§5.4. Second example: the return to the home screen from the same run. It has
no loadTime, so no baseline timing is sent.

```json
{
"eventType": "MobileView",
"timestamp": 1792532158286,
"viewName": "ViewController",
"viewClass": "NRTestApp.ViewController",
"viewInstanceId": "ED94CF61-D2EF-4D61-B9DE-A487CD398543",
"uiFramework": "UIKit",
"loadTimeUnavailable": "noConstructionObserved",
"timeVisible": 4937.412417028099,
"previousView": "UtilitiesViewController",
"previousViewInstanceId": "274F53A9-772B-4990-B96C-624B4B04E9A0",
"timeSinceLoad": 50.28683805465698
}
```

### 5.9 Adding additional MobileViewTiming Marks for Infinite Load Scenarios

Frequently a pattern that appears in mobile applications is a single screen that shows a list or collection of
content. Typically scrolling to the bottom of the feed will perform a “loadMore” or load the next page of data.
This timing is useful for understanding that the app continued performing actions on a single Mobile View
visit.

**“loadMore”**

A customer can use capability 8 with the duration the caller measures for each page, under the name “loadMore”.
This is capped to 16 timings per view and will reject the 17th.

---

## 6. Public API contract

### 6.1 Screen capabilities

| # | Capability | Contract |
| --- | --- | --- |
| 1 | Enable automatic tracking | Independent flag, disabled by default (§5.5) |
| 2 | Enable manual tracking | Independent flag, off by default (§5.5) |
| 3 | Set current view manually | Name, View Class Name, UI Framework plus optional custom attributes. Browser route-change semantics: setting a new view closes the previous one and emits its dwell time<br>an empty viewClass reports the viewName;<br>an empty uiFramework reports `Manual`<br>The manual tracking flag above gates the event whatever framework it declares. |
| 4 | Override display name per screen | Per-screen hook; affects `viewName` only, never `viewClass`. A returned name overrides viewName for that screen; nil or empty keeps the automatic name; viewClass never changes. |
| 5 | reserved (per-screen opt-out, post-GA) | |
| 6 | Attach custom attributes per screen | Merged into that screen's MobileView events only. Must not overwrite any attribute in §5.3 (normal NRDB custom attribute limits apply). |

Rules:

- **Reserved keys are non-overridable.** Every attribute in §5.3 must be rejected if supplied through
  capability 3 or 6.

### 6.2 Timing capabilities

`loadTime` is approximate on most runtimes (§5.4), so the timings customers actually need, Time to Full
Display, Time to Interactive: must come from customer code that knows when the screen genuinely reached that
state. These two capabilities are how they supply it. Both emit `MobileViewTiming` (§5.7).

| # | Capability | Contract |
| --- | --- | --- |
| 7 | **Mark** a timing against the current view | Duration is measured by the agent, from the current view's construction begin time until the moment of the call. Takes a name only |
| 8 | **Record** a timing with a caller-supplied duration | Takes a name and a duration in **milliseconds**. Used when the view's construction start time is the wrong zero point |

Capability 9 - Declare a load start time for setCurrentView API

| | | |
| --- | --- | --- |
| 9 | **Declare a load start** for the next manually-set view | No arguments. Marks "construction of the next manual view starts now"; the next capability-3 call consumes it. Optional, and only meaningful for manual views (§5.3.6) last call wins, it's thread-safe, a pending start is cleared on session start and on background, and an unused start never produces a timing. A start more than 600000 ms before the next capability-3 call is ignored. |

**Why both Mark and Record?** TTID, TTFD, and TTI are all "from view construction until X", which capability 7
expresses in a single call with no state for the customer to manage. Capability 8 exists for the cases that do
not share that zero point — a prefetch that began before navigation, or a duration measured by the customer's
own code or another SDK.

**Divergent no-current-view behavior is deliberate and must be preserved by every agent:**

| | Capability 7 (mark) | Capability 8 (record) |
| --- | --- | --- |
| No view currently tracked | **Fails.** There is no zero point; emitting a wrong number is worse than emitting nothing. Agents must direct callers to capability 8 | **Succeeds.** The caller supplied the value; the event is recorded without view identity and is queryable as unattributed |
| View currently tracked | Emits with `viewName`, `viewInstanceId`, `previousView` | Emits with `viewName`, `viewInstanceId`, `previousView` |

**Both capabilities must report success or failure to the caller.** A timing can be rejected for six distinct
reasons. Agents return a boolean where the language convention allows it; async bridges return Promise<boolean>
(React Native, Capacitor/Cordova) or Future<bool> (Flutter). Every rejection is also logged with its reason at
warning level.

**Gating.** Both are active when **either** Mobile Views flag is enabled (§5.5), and both fail when both flags
are off.

### 6.3 Shared constants

| Constant | Value | Applies to | Rationale |
| --- | --- | --- | --- |
| Baseline timing name | `timeToInitialDisplay` | §5.3.6 | Cross-app comparability; reserved from customer use |
| Standard timing names | timeToFullDisplay, timeToInteractive | Capabilities 7, 8 | Same string on every agent so dashboards line up across apps; not reserved; agents ship them as constants |
| Max customer timings per view instance | **16** | Capabilities 7, 8 | The event buffer is bounded (1000 by default). An unguarded mark inside a list-row callback would evict the customer's own real events. Warn once when exceeded, then drop silently |
| Max timing name length | **128** characters | Capabilities 7, 8 | Bounds attribute cardinality |
| Max accepted duration | **600000** ms (10 minutes) | All timings and loadTime | Catches the seconds-passed-where-milliseconds-expected mistake instead of recording it as a ten-hour screen load |
| Timing unit | milliseconds | Capabilities 7, 8; §5.7 | Unit drift between agents corrupts cross-platform percentiles invisibly |

**Rejection rules, applied by every agent in this order.** A timing is rejected — and the failure reported per
§6.2 — when:

1. Both Mobile Views flags are off;
2. The name is empty, or longer than 128 characters;
3. The name is reserved (only `timeToInitialDisplay`)
4. Capability 7 was called with no view currently tracked;
5. The duration is non-finite (`NaN`, `±inf`), negative, or above 600000 ms
6. the per-view-instance cap of 16 is already reached.

Timings with no `viewInstanceId` — capability 8 called with no current view — share a single unattributed cap
bucket, reset on session start. Otherwise an uncapped path exists in precisely the case where no view identity
is available to key a cap on.

### 6.4 Proposed Public API naming

(Implemented in the iOS POC) To be implemented on other platforms.

| # | iOS | Android |
| --- | --- | --- |
| 1 Enable automatic tracking | `NRFeatureFlag_AutomaticMobileViews` | `FeatureFlag.AutomaticMobileViews` |
| 2 Enable manual tracking | `NRFeatureFlag_ManualMobileViews` | `FeatureFlag.ManualMobileViews` |
| 3 Set current view manually | `+(BOOL)setCurrentView:viewClass:uiFramework:attributes:` | `boolean NewRelic.setCurrentView(String name, String viewClass, String uiFramework, Map<String, Object> attributes)` |
| 4 Override display name per screen | `.NRMobileView(name:attributes:)`<br>`nrMobileViewName` hook in SwiftUI, UIKit | `Modifier.nrMobileView(name, attributes)` (Compose);<br>`nrMobileViewName()` on Activity/Fragment |
| 6 Attach custom attributes per screen | `nrMobileViewAttributes` hook in SwiftUI, UIKit | `nrMobileViewAttributes()` on Activity/Fragment;<br>Compose passes attributes through row 4 |
| 7 **Mark** a timing against the current view | `+(BOOL)markViewTiming:` | `boolean NewRelic.markViewTiming(String name)` |
| 8 **Record** a timing with a caller-supplied duration | `+(BOOL)recordViewTiming:milliseconds:` | `boolean NewRelic.recordViewTiming(String name, double milliseconds)` |
| 9 **Declare a load start** for the next manually-set view | `+beginViewLoad` | `NewRelic.beginViewLoad()` |

React Native, Flutter, Capacitor/Cordova and MAUI names are defined in each agent's CDD before GA.

## 7. Decorate existing events

**Decorate** `MobileRequest`, `MobileRequestError`, `MobileHandledException` and `MobileBreadcrumb` on every
platform, and `MobileApplicationExit` on Android, with the current/previous view (`currentView`,
`currentViewInstanceId`, `previousView`, `previousViewInstanceId`), so a request, a request error, or a handled
exception can be joined back to the screen it happened on.

example MobileRequest containing currentView and currentViewInstanceId:

```json
{
    "id": "c1527e21531e441c",
    "connectionType": "wifi",
    "eventType": "MobileRequest",
    "timestamp": 1788537301172,
    "requestMethod": "GET",
    "contentType": "image\/jpeg",
    "trace.id": "49b6068bdf9d41a7b66f916e57a2854e",
    "requestDomain": "apod.nasa.gov",
    "currentView": "Main ViewController",
    "currentViewInstanceId": "B9BBE684-17F8-42D9-9024-5A490FD9F963",
    "requestUrl": "https:\/\/apod.nasa.gov\/apod\/image\/2011\/GWaveSources2020Oct_LigoVIrgo_960.jpg",
    "requestPath": "\/apod\/image\/2011\/GWaveSources2020Oct_LigoVIrgo_960.jpg",
    "statusCode": 200,
    "traceId": "49b6068bdf9d41a7b66f916e57a2854e",
    "bytesReceived": 76416,
    "guid": "c1527e21531e441c",
    "responseTime": 0.89526806640625001,
    "timeSinceLoad": 535.17252695560455,
    "payload": {
        "v": "[0,2]",
        "d": {
            "ap": "246132793",
            "ac": "10816994",
            "id": "c1527e21531e441c",
            "tk": "1",
            "ti": 1788537300.2787971,
            "ty": "mobile",
            "tr": "49b6068bdf9d41a7b66f916e57a2854e"
        }
    }
}
```

HeX showing currentView

<https://staging.onenr.io/0BQ1AgeoXQx>

## 8. DECORATING **MobileCrash** with **MobileView** data

   Decorating crashes on iOS needs the current/previous view persisted to disk on every transition so it
   survives the crash. Every platform should make sure the view context survives the crash and makes it to the
   MobileCrash event. **Implemented on iOS (**`mobile-views-2`**).** `MobileRequest`, `MobileRequestError`,
   `MobileHandledException` and `MobileBreadcrumb` now all carry. now all carry `currentView`/`currentViewInstanceId`/
   `previousView`/ `previousViewInstanceId` when a Mobile Views flag is on and a view is current — one shared,
   flag-gated merge point (`NRMAViewContext`) feeding all producers and breadcrumbs. **Every other agent should
   decorate the equivalent of these four event types identically.** The requirement is the four attributes above on
   the request, request-error, handled-exception and breadcrumb events, not iOS's specific mechanism.

   `MobileCrash` is decorated too, but by a different, cross-platform-relevant mechanism worth stating
   explicitly: **crash reporting and handled-exception reporting are two different pipelines on iOS**
   (native-signal/PLCrashReporter for `MobileCrash` vs. the Hex report system for `MobileHandledException`),
   and only the crash pipeline has the "state doesn't survive the crash" problem described above. iOS solves it
   by persisting the referrer to disk on every view transition and reading it back into the crash's attributes
   during next-launch crash processing, then clearing it unconditionally so a clean session never leaves state
   a *later* crash could be misattributed to. Any agent whose crash reporter is similarly
   out-of-process/next-launch (which is the common case, not an iOS peculiarity) will need an equivalent
   persist-and-recover step — this is not something a live in-memory accessor like `referrerAttributes` can
   solve on its own, and is worth a line in each CDD rather than being assumed to fall out of the shared
   mechanism for free.

MobileCrash example session Attributes containing currentView, currentViewInstanceId and previousView,
previousViewInstanceId

```
"sessionAttributes": {
    "osVersion": "26.6.1",
    "osMajorVersion": "26",
    "currentView": "UtilitiesViewController",
    "previousView": "Main ViewController",
    "appBuild": "1",
    "uuid": "d4b436525bdc97a8888f192b6eec932652e581929052869bf1de4ece5a1b52ae",
    "hasReplay": true,
    "sessionId": "78B6DB32-F1F9-4597-83B0-5835574FAD02",
    "previousViewInstanceId": "0FB7490F-43F9-4E84-935C-F9099B6BEC95",
    "test1": 1,
    "lastInteraction": "Display NRTestApp.UtilitiesViewController",
    "platform": "Native",
    "sessionDuration": 19.060999870300293,
    "carrier": "wifi",
    "memUsageMb": 26.282127380371094,
    "deviceManufacturer": "Apple Inc.",
    "deviceModel": "iPhone14,5",
    "newRelicVersion": "DEV",
    "currentViewInstanceId": "9E1E0AAA-56A1-47D6-988A-9540E915D539",
    "nr.noSecureUDID": true,
    "osName": "iOS",
    "platformVersion": "DEV"
}
```

Verified on iOS with

```
SELECT currentView, currentViewInstanceId, previousView FROM MobileCrash SINCE 1 day ago

result = currentView UtilitiesViewController, previousView Main ViewController.
```

**MobileView Term Glossary**

- **TTID: “timeToInitialDisplay”** is the Out of the box appearance timing that should be included with each
  MobileView visit. it is the view timing the represents the moment the view appeared.
- **TTFD: “timeToFullDisplay”** is the view timing representing the view being fully loaded and not loading
  anymore.
- **TTI: Time to Interactive** is an additional one that could be used to say the view is now interactive and
  responds to touches.
- **Dwell time / “timeVisible”**: “timeVisible”: The amount of time a user spent on a visit to a screen.

---

## 9. MobileView and Interaction remain completely independent.

## 10. Customer Zero

**New Relic Mobile Apps team** (the team that ships our own NR1 mobile clients) — if they run iOS + Android +
any hybrid, they dogfood three agents at once and validate cross-platform dashboard parity in real conditions.

- **Internal demo apps per agent** — each agent's example app enables the flag in CI to catch schema drift.
- **AppExp team** will utilize the MobileView events to decorate more of the MSR experiences.

### Teams

List all teams that you expect to have work for this initiative.

| **Team Name** | **Jira Epic/Feature (if available)** |
| --- | --- |
| Mobile Agents - telemetry | [iOS Implementation](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5536055442/Mobile+Views+iOS+Telemetry+-+Change+Design+Document)<br>[Android Implementation](https://newrelic.atlassian.net/wiki/x/A4AVTAE)<br>Hybrids (Flutter & React Native) |
| App Experience Mobile - app settings, charts, experiences, etc. | [App Exp feature](https://new-relic.atlassian.net/browse/NR-562386)<br>[UI Entry Points](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5558075536/Entry+Points+in+the+UI+for+Mobile+Views) |

## 11. API Review Board Prerequisites

The following must be completed prior to API review board submission

- [ ] UI product requirements and v1 designs
- [ ] IDD sign off from reviewers
