# MobileViewTiming — design

Date: 2026-08-28
Status: approved design, not yet implemented
Branch context: `mobile-views-2`

## Purpose

MobileViews today emits a single timing, `loadTime` (viewDidLoad → viewDidAppear), synchronously on the
`MobileView` appear event. That shape cannot express the timings customers actually need, because the
interesting ones are only known *after* the view has appeared: Time to Full Display, Time to Interactive.
A screen that renders a spinner in 80 ms and real content in 900 ms currently reports 80 ms.

This design adds an asynchronous, streamed timing event — `MobileViewTiming` — modelled on browser's
`PageViewTiming`, plus a minimal manual API for customers to record timings the agent cannot observe.

### Accepted non-goals

- **First Input Delay.** Descoped for this round. Worth recording that FID was the *only* metric in the
  original discussion that could have been measured out of the box (via `UIWindow -sendEvent:`); everything
  shipping here requires customer code.
- **Time to First Byte.** Not a view timing. TTFB is a property of a network request, and belongs on
  `MobileRequest`, not on a view. See "Optional extension" below.
- **Hooking interaction/activity traces.** Explicitly out of scope by prior agreement.
- **Automatic TTFD/TTI.** Not obtainable generically. Accurate mobile view timing requires customer
  instrumentation; this design accepts that and optimises for making the required work small and for
  reporting which screens still lack it.

## Prior art already in the tree

Discovery confirmed several pieces of the browser mapping already exist and must not be rebuilt:

- `+[NewRelic setCurrentView:attributes:]` is the `setPageViewName()` / SPA route-change analog, and is
  documented as such in `NRMAViewContext.h`.
- `nrMobileViewName` (subclass hook; returning `nil` ignores the view) and `nrMobileViewAttributes` provide
  custom naming and custom attributes.
- `MobileView` already carries `viewClass`, `viewName`, `viewInstanceId`, `appeared`, `restarted`,
  `reappeared`, `loadTime`, `timeVisible`, `previousView`, `previousViewInstanceId`, `uiPlatform`, and
  `component` / `componentOf` / `interactionId`.
- `scripts/mobileview_flow.py` renders the session DAG from `previousView` → `viewName` edges.

The gap is timing depth, not naming and not navigation.

## Architecture

`NRMAViewContext` is already the thread-safe source of truth for the current view across all three
producers (UIKit swizzle, SwiftUI `.NRMobileView` modifier, manual `setCurrentView:`), and already stores
`_currentViewAppearTime`. The zero point for every mark therefore already exists and is already consistent.
This design adds a second *reader* of that state and a second *emitter*; it adds no new measurement.

### Components

| Change | File | Responsibility |
|---|---|---|
| New | `Agent/MobileViews/NRMAViewTiming.{h,m}` | Validate, cap, and emit `MobileViewTiming`. No UIKit dependency, unit-testable in isolation. |
| Edit | `Agent/MobileViews/NRMAViewContext.{h,m}` | Add a `snapshotForTiming` accessor returning name / instanceId / appearTime / previousView / uiPlatform as one value. |
| Edit | `Agent/Public/NewRelic.{h,m}` | Two public class methods. |
| Edit | appear path (`NRMAViewContext` / `NRMAMobileViewTracker`) | Emit the OOTB `timeToInitialDisplay` row alongside the existing `MobileView` appear event. |
| New | Tests | Unit tests for `NRMAViewTiming`; an `NRTestApp` screen exercising a real async TTFD. |

### Threading invariant (load-bearing)

`NRMAViewContext` guards its state with `os_unfair_lock`. `NRMAViewTiming` MUST:

1. take the lock,
2. copy the snapshot,
3. **release the lock**,
4. only then call into `analyticsController`.

Emitting while holding `_lock` is forbidden. This repository already has a documented deadlock in which
adding a mutex around a session/view path collided with the harvester lock; the same hazard applies here.
`os_unfair_lock` is also non-recursive and priority-inversion-prone, so no call-outs may happen under it.

### Feature gating

No new feature flag. Timing is active when
`[NRMAFlags shouldEnableAutomaticMobileViews] || [NRMAFlags shouldEnableManualMobileViews]` — the exact
condition `+[NewRelic recordBreadcrumb:attributes:]` already uses to decide whether to stamp referrer
attributes. When both are off, both public methods no-op and return `NO`.

## Public API

```swift
// duration = now − currentView.appearTime
// returns false when no view is current: there is no zero point to measure from
@discardableResult
NewRelic.markViewTiming(_ name: String) -> Bool

// customer supplies the duration; succeeds even when no view is current
@discardableResult
NewRelic.recordViewTiming(_ name: String, milliseconds: Double) -> Bool
```

```objc
+ (BOOL)markViewTiming:(NSString *)name;
+ (BOOL)recordViewTiming:(NSString *)name milliseconds:(double)milliseconds;
```

`BOOL` returns follow the existing convention set by `recordBreadcrumb:attributes:`.

Rationale for this shape over start/end pairs or full browser `mark`/`measure` parity: TTID, TTFD and TTI
are all "from view appear until X", which the implicit zero point expresses in one call. Anything with a
different zero point is expressible via `recordViewTiming:milliseconds:`. This avoids a registry of open
marks, and therefore avoids eviction policy, timeout semantics, and leaks on views that vanish — the
interaction-trace problem in miniature.

## Event schema

Event type: `MobileViewTiming`. One event per timing, streamed as soon as the value is known.

| Attribute | Type | Source |
|---|---|---|
| `timingName` | string | Caller, or `timeToInitialDisplay` when agent-emitted |
| `timingValue` | double (ms) | Computed or caller-supplied |
| `viewName` | string | Snapshot; omitted if no view is current |
| `viewInstanceId` | string | Snapshot; omitted if no view is current |
| `previousView` | string | Snapshot, when present |
| `uiPlatform` | string | Snapshot, when present |
| `agentName`, `sessionId` | standard | Analytics pipeline |

`viewInstanceId` is the key design element: it makes `MobileViewTiming` joinable to the specific
`MobileView` visit that produced it, per visit rather than per screen name. Carrying `previousView` means
timings are queryable by *route* — the same screen can be shown to be fast when reached from search and
slow when reached from a deeplink.

Milliseconds are produced via the existing `+[NRMAViewContext millisecondsBetween:and:]` so the unit cannot
drift from `loadTime`.

## Out-of-the-box baseline

Whenever the agent emits a `MobileView` appear event carrying `loadTime`, it additionally emits one
`MobileViewTiming` row with `timingName = "timeToInitialDisplay"` and the same value.

- This is a second projection of a number already measured. No new measurement, no new swizzle.
- It makes every timing dashboard populate with zero customer code, and puts customer TTFD marks on the
  same axis as the agent's TTID.
- `reappeared` views emit no TTID row, mirroring the existing deliberate decision that a resurfaced view
  carries no `loadTime`: nothing was constructed or laid out, so there is nothing to time.
- `loadTime` **remains** on `MobileView`. This is deliberately additive; removing it would break already
  shipped panels in `mobviews-dashboard.json`.

## Guardrails

| Rule | Reason |
|---|---|
| `timeToInitialDisplay` is reserved; customer use is rejected | Keeps the OOTB series clean and comparable across apps |
| Max 16 **customer** timing events per `viewInstanceId`; warn once when exceeded | The default event buffer holds 1000 events. An unguarded `markViewTiming` in `cellForRowAt` would evict the customer's real events |
| The agent's own `timeToInitialDisplay` row does not count toward that 16 | The OOTB baseline must never be the row that gets dropped |
| Rows with no `viewInstanceId` (from `recordViewTiming:` with no current view) share one "unattributed" cap bucket, reset on session start | Otherwise an uncapped path exists precisely where no view identity is available to key a cap on |
| Reject empty names and names longer than 128 chars | Cardinality and storage hygiene |
| Reject non-finite (`NaN`, `±inf`) and negative durations | A single `NaN` silently poisons every `average()` and `percentile()` in the dashboard |
| Reject durations above a sane ceiling (10 minutes) | Catches unit errors, e.g. seconds passed where ms expected |
| `markViewTiming` returns `NO` when no view is current | No zero point exists; emitting a wrong number is worse than emitting nothing |
| `recordViewTiming:milliseconds:` succeeds with no current view | The caller supplied the value; the row lands without `viewName` and is queryable as unattributed |

## Testing

Unit tests against `NRMAViewTiming` with a stubbed context snapshot:

1. `markViewTiming` with no current view → returns `NO`, emits nothing.
2. `markViewTiming` with a current view → emits one event with correct `viewName`, `viewInstanceId`,
   `previousView`, and a `timingValue` matching `millisecondsBetween:and:`.
3. Reserved name `timeToInitialDisplay` from the public API → rejected.
4. 17 marks against one `viewInstanceId` → 16 emitted, 17th dropped, warning logged once.
5. `NaN`, `-1`, and `10 * 60 * 1000 + 1` durations → all rejected.
6. Both feature flags off → both methods return `NO`, emit nothing.
7. Appear event with `loadTime` → exactly one `timeToInitialDisplay` row; `reappeared` appear event → none.

Integration: an `NRTestApp` screen that appears, loads asynchronously, then calls
`markViewTiming("timeToFullDisplay")`; verified by dumping the buffered events and asserting the TTID and
TTFD rows share a `viewInstanceId` with the `MobileView` appear event.

Note for whoever runs the suite: per existing project notes, `Agent` tests need
`IPHONEOS_DEPLOYMENT_TARGET=15.0` under Xcode 27, two `NSURLSession` test classes hang behind a TLS proxy
and must be skipped, and five `NRMASessionExclusivityWithDelegateTests` upload tests fail on a clean tree.
Baseline before attributing failures to this change.

## Dashboards

The existing DAG shows the *shape* of a session's route. Timings show the *cost* on that shape. Four
additions, in priority order.

### 1. The lie window (headline)

How long a screen looked finished but was not. The metric that justifies the feature, and one with no
direct browser equivalent.

```sql
SELECT filter(percentile(timingValue, 50), WHERE timingName = 'timeToFullDisplay')
     - filter(percentile(timingValue, 50), WHERE timingName = 'timeToInitialDisplay')
       AS 'Lie window p50 (ms)'
FROM MobileViewTiming FACET viewName SINCE 1 day ago
```

### 2. Cost-weighted DAG

Extend `scripts/mobileview_flow.py` to label each `previousView` → `viewName` edge with p50 TTFD, so the
Mermaid diagram shows where the route hurts rather than only where it goes. This is a script change, not a
dashboard panel, and it is the most direct complement to the existing session diagram.

### 3. Timings by route, not only destination

```sql
SELECT percentile(timingValue, 50, 95) FROM MobileViewTiming
WHERE timingName = 'timeToFullDisplay' FACET previousView, viewName SINCE 1 day ago
```

Surfaces destination-slow-from-one-entry-point, which is invisible in browser's model.

### 4. Instrumentation coverage

Because accurate timing requires customer code, the dashboard must say which screens still lack it.
Screens showing only `timeToInitialDisplay` are the backlog.

```sql
SELECT uniques(timingName) FROM MobileViewTiming FACET viewName SINCE 1 day ago
```

### Also worth a panel

- **Re-entry vs first visit.** Compare TTFD on first visit against re-entry, using `MobileView.reappeared`
  joined on `viewInstanceId`, to show whether caching is working.
- **Worst instances, not averages.** `max(timingValue)` with `viewInstanceId` listed, for drilling into a
  specific bad visit via the session walk page.

### Optional extension (decide separately)

`MobileRequest` does **not** currently carry `currentView` — verified: `referrerAttributes` has exactly one
consumer, `recordBreadcrumb:`. Stamping referrer attributes onto network events (a small change mirroring
the breadcrumb path) would unlock "which screens are slow *because of* network," correlating TTFD against
request duration on the same screen. This is where the most explanatory dashboard lives, and it is also the
correct home for TTFB. Out of scope here; recommended as the next increment.

## Open questions

None blocking. Two decisions deferred by choice: FID (descoped) and referrer-stamping on `MobileRequest`
(recommended next increment).
