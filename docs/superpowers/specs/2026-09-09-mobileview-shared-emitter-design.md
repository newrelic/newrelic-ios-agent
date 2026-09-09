# MobileView: one shared Swift emitter, built-in event in both event systems

| Field | Value |
|-------|-------|
| Date | 2026-09-09 |
| Branch | `mobile-views-2` |
| Status | Implemented. See "Implementation notes" for where the build diverged from this design. |
| Related | `.claude/daci-mobileview-event-naming.md` (DACI Option C), `docs/superpowers/specs/2026-08-28-mobileview-timing-design.md` |

## Problem

Two problems, one fix.

### 1. MobileView events are silently dropped on the default configuration

`MobileView` is already in the C++ reserved event-type list
(`libMobileAgent/src/Analytics/include/Analytics/AnalyticsController.hpp:36-44`), and
`AnalyticsController::newCustomEvent` rejects reserved types by throwing from the
eventType validator lambda (`AnalyticsController.cxx:145`, reached from
`newCustomEvent` at `:891`). `NRFeatureFlag_NewEventSystem` is **not** in the
default flag set (`Agent/FeatureFlags/NRMAFlags.m:37-55`).

So on a default-configured agent, every `recordCustomEvent("MobileView", …)`
reaches the old event system, hits that throw, is caught, logged, and returns
`NO`. The events only survive when a customer opts into the new event system,
where `addCustomEvent:` (`Agent/Analytics/NRMAAnalytics.mm:872`) does nothing but
a regex check on the event type.

This is total data loss for the feature as shipped, on the configuration almost
every customer runs.

### 2. Eight emission sites have already drifted

| # | File | Site |
|---|---|---|
| 1-2 | `Agent/MobileViews/NRMAMobileViewTracker.m:323,393` | UIKit appear / disappear |
| 3 | `Agent/MobileViews/NRMAViewContext.m:301` | synthesized re-appearance |
| 4 | `Agent/MobileViews/NRMAViewContext.m:434` | manual producer |
| 5-6 | `Agent/Instrumentation/MethodProfiling/NRViewModifier.swift:171,207` | SwiftUI appear / disappear |
| 7-8 | `Agent/Instrumentation/MethodProfiling/NRViewModifier.swift:410,438` | TabView select / close |

Sites 1-4 use `kNRAttr_*` constants — redefined `static` in three separate files
(`NRMAViewContext.m:19-27`, `NRMAViewTiming.m:27-30`, `NRMAMobileViewTracker.m:33+`).
Sites 5-8 use bare string literals. Only 5-6 set `churn`; only 3 sets
`reappeared`; only 7-8 set `navigationKind`. The schema has no single owner, so
it drifts every time a producer is added.

`MobileViewTiming` (`NRMAViewTiming.m:195`) is a ninth site. It is *not* in the
reserved list, so it is unaffected by problem 1, but it is in scope here so the
whole feature is treated consistently.

## Decisions

Settled during brainstorming; recorded here because each one closes off
alternatives that would otherwise look reasonable during implementation.

| # | Decision | Consequence |
|---|---|---|
| 1 | **DACI Option C**: dedicated event type *and* a `category` attribute, for both event types | Needs an internal event class per system; not reachable via the public `recordCustomEvent` path |
| 2 | The shared Swift place **owns the whole event**, not just transport | The 9 sites describe what happened; the emitter decides what the event looks like |
| 3 | **Both** `MobileView` and `MobileViewTiming` become built-in | `MobileViewTiming` joins the reserved list; `recordCustomEvent("MobileViewTiming")` starts failing for anyone already calling it |
| 4 | Boundary **A**: Swift value type + thin `@objc` facade | Swift sites build the struct; ObjC sites call the facade. Locked regions untouched |
| 5 | `category = "View"` for **both** event types | One category constant. `category` is a feature-area label, not an event discriminator; `eventType` discriminates |
| 6 | The new event system **also** rejects reserved event types | Same customer call, same outcome, either flag. Behavior change for anyone emitting either name |
| 7 | Correct the header doc to **milliseconds** | Comment-only. Wire format unchanged. Closes DACI action #5 |

## Architecture

```
NRMAMobileViewTracker.m ─┐
NRMAViewContext.m ───────┼─→ NRMAMobileViewRecorder ──┐   (@objc facade, Swift)
NRMAViewTiming.m ────────┘                            │
                                                      ├─→ MobileViewRecord
NRViewModifier.swift ─────────────────────────────────┘   ViewTimingRecord
                                                          (Swift, owns the schema)
                                                              │
                                                              ▼
                                     NRMAAnalytics -addMobileViewEventWithAttributes:
                                                    -addViewTimingEventWithAttributes:
                                                              │
                                          ┌───────────────────┴───────────────────┐
                                          ▼                                       ▼
                                  NewEventSystem ON                        OFF (default)
                                  NRMAViewEvent                            C++ ViewEvent
                                  → _eventManager addEvent:                → addEventWithMetrics
```

The layering rule: **the producer owns *when* things happened; the emitter owns
*what the event looks like*.** Producers hold the timestamps, the associated
objects, and the `os_unfair_lock`; they keep computing durations and deciding
whether a load was measurable. The emitter never runs inside a locked region.

### Units

Every duration crossing the boundary is **milliseconds**, matching what the code
emits today. `loadTime`, `timeVisible`, and `timingValue` are unchanged on the
wire.

## Components

### Swift: `Agent/MobileViews/MobileViewEmitter.swift` (new)

Types, all `internal` except the `@objc` facade:

```swift
enum ViewPlatform { case uiKit, swiftUI, manual }        // → "UIKit" / "SwiftUI" / "Manual"

enum LoadOutcome {
    case measured(Double)                                // ms → writes loadTime, nothing else
    case unavailable(Reason)                             // → writes loadTimeUnavailable, nothing else
    enum Reason { case constructedBeforeAppear, noConstructionObserved, notRebuilt }
}

enum ViewPhase { case appeared, disappeared }

struct MobileViewRecord {
    var viewName, viewClass, instanceId: String
    var platform: ViewPlatform
    var phase: ViewPhase
    var load: LoadOutcome?            // appear only
    var timeVisibleMs: Double?        // disappear only
    var restarted: Bool?
    var reappeared: Bool
    var navigationKind: String?
    var custom: [String: Any]?
    func attributes() -> [String: Any]
    func emit()
}

struct ViewTimingRecord { /* timingName, timingValueMs, viewName, viewInstanceId, previousView, uiPlatform */ }
```

`LoadOutcome` is the point of the type: it makes "exactly one of `loadTime` /
`loadTimeUnavailable`" unrepresentable-if-wrong, which is the rule that is
currently inconsistent across sites.

`ViewPhase` is one decision point in one file. That is what makes DACI action #2
(collapse to one event on disappear) a single-file change later — **not done
here**, see Non-goals.

The emitter owns, in one place:

- attribute names — replacing the three duplicated `static` blocks
- reserved-keys-win precedence over customer-supplied attributes
- the referrer merge (`previousView` / `previousViewInstanceId`)
- the `kNRMAMinDwellMs` churn threshold
- `agentName`
- the feature-flag gate
- the `isShutdown` check (see Risks)

`@objc(NRMAMobileViewRecorder) final class MobileViewRecorder: NSObject` is the
ObjC surface — roughly 30 lines, three class methods (view appeared, view
disappeared, timing), each building the same record type the Swift sites build
directly. It is the only thing that can drift, and it has no logic of its own.

### ObjC: `Agent/Analytics/Events/NRMAViewEvent.{h,m}` (new)

```objc
@interface NRMAViewEvent : NRMAMobileEvent
@property (nonatomic, strong) NSString *category;
- (instancetype)initWithEventType:(NSString *)eventType
                         category:(NSString *)category
                        timestamp:(NSTimeInterval)timestamp
      sessionElapsedTimeInSeconds:(NSTimeInterval)seconds
           withAttributeValidator:(nullable id<AttributeValidatorProtocol>)validator;
@end
```

One class serves both event types; only `eventType` varies, and per decision 5
both callers pass the same category.

`category` is injected in `-JSONObject`, **not** via `-addAttribute:`. That is how
it gets past `NRMAAttributeValidator -nameValidator:`
(`Agent/Analytics/AttributeValidator/NRMAAttributeValidator.m:30-35`), which
rejects any attribute whose name is in `[NRMAAnalytics reservedKeywords]`
(`NRMAAnalytics.mm:1293`) — and `category` is in that list. Precedent:
`NRMAUserActionEvent.m:34-41`.

`NSSecureCoding`: `encodeWithCoder:` / `initWithCoder:` carry `category`, and the
class is added to `+[PersistentEventStore classList]`
(`Agent/Analytics/PersistentEventStore.m:218`). Without that registration,
`decodeObjectOfClasses:` fails on an unknown class and offline-stored events are
lost.

### C++: `libMobileAgent/src/Analytics/{include/Analytics,src}/Events/ViewEvent.{hpp,cxx}` (new)

`ViewEvent : AnalyticEvent`, mirroring `UserActionEvent.cxx:22-32`:

- `put(os)` writes `eventType << AnalyticEvent::_delimiter`
- `generateJSONObject()` takes the base object and adds `(*json)["category"]`

Constructed via `EventManager::newViewEvent(eventType, category, ts, dur, validator)`
(alongside `newUserActionEvent` at `EventManager.cxx:185` and `newBreadcrumbEvent`
at `:208`), reached from `AnalyticsController::newMobileViewEvent()` and
`newViewTimingEvent()`. Both **bypass the eventType validator**, exactly as
`newBreadcrumbEvent()` does (`AnalyticsController.cxx:874`) — which is the
mechanism that fixes problem 1.

### C++: `EventDeserializer` — the branch is load-bearing

The wire format is `eventType|timestamp|sessionElapsed|key|value|…`
(`AnalyticEvent.cxx:169-179`: `operator<<` calls `put()`, then writes timestamp
and session-elapsed itself). `EventDeserializer::deserialize` dispatches on that
first field.

Without a new branch, `MobileView` matches neither `Mobile` nor
`MobileUserAction`, so it falls through to `deserializeCustomEvent`
(`EventDeserializer.cxx:20-21`) and comes back as a plain `CustomEvent`, whose
`generateJSONObject()` adds no category. The failure mode:

> **An offline-stored view event ships without `category`; a live one ships with
> it.** Same event type, two shapes, split on whether the device had connectivity
> when the event was recorded.

`deserializeViewEvent` reconstitutes a `ViewEvent` with the right eventType and
category. Since both event types carry category `"View"` (decision 5), the
category needs no lookup table — it is a constant.

One structural difference from `UserActionEvent`: because `ViewEvent` takes its
eventType as a constructor parameter rather than owning a
`static const std::string __eventType`, the dispatch in `deserialize` compares
against the `__kNRMA_RET_mobileView` / `__kNRMA_RET_mobileViewTiming` constants
directly rather than against a class-static member.

The new branch **must** use the guarded loop form:

```cpp
while (!is.eof() && !is.fail()) { … }
```

not `deserializeCustomEvent`'s unguarded `while (auto attribute = …)`. The guard
exists because `istream::get(streambuf&, delim)` sets failbit rather than eofbit
when the next character is already the delimiter and zero characters are
extracted; the unguarded form spins forever. See the comment at
`EventDeserializer.cxx:66-68`.

### Routing: `NRMAAnalytics`

Two new methods, each mirroring `-addBreadcrumb:withAttributes:`:

```objc
- (BOOL)addMobileViewEventWithAttributes:(NSDictionary *)attributes;
- (BOOL)addViewTimingEventWithAttributes:(NSDictionary *)attributes;
```

Each branches on `[NRMAFlags shouldEnableNewEventSystem]`:

- **new**: build `NRMAViewEvent`, add attributes, `[_eventManager addEvent:]`
- **old**: `_analyticsController->newMobileViewEvent()`, `-event:withAttributes:`,
  then `addEventWithMetrics`, with the same `checkOfflineStatus` /
  `checkBackgroundStatus` stamps the other built-ins apply, inside the same
  `try` / `catch (std::exception&)` / `catch (...)` shape

### Reserved event-type symmetry (decision 6)

The new event system has **no** reserved event-type enforcement today —
`[NRMAAnalytics reservedKeywords]` (`NRMAAnalytics.mm:1293`) covers attribute
*names* only, and `-addCustomEvent:withAttributes:` does nothing but a regex
check on the event type.

So this adds a new `+[NRMAAnalytics reservedEventTypes]` returning the same set
the C++ `_reserved_eventTypes` holds (`Mobile`, `MobileCrash`, `MobileRequest`,
`MobileRequestError`, `MobileSession`, `MobileBreadcrumb`, `MobileView`,
`MobileViewTiming`), and `-addCustomEvent:withAttributes:` rejects and logs on a
match — mirroring `AnalyticsController.cxx:145`. Note the C++ list omits
`MobileUserAction`; the new list matches it exactly rather than silently
correcting that, so the two systems cannot diverge. Bringing
`MobileUserAction` into both lists is a separate change.

After this, `recordCustomEvent("MobileView")` and
`recordCustomEvent("MobileViewTiming")` are rejected and logged identically under
both event systems.

### Constants

| File | Add |
|---|---|
| `Agent/Analytics/Constants.{h,m}` | `kNRMA_RET_mobileViewTiming = @"MobileViewTiming"`, `kNRMA_RET_view = @"View"` |
| `libMobileAgent/.../Constants.{hpp,cxx}` | `__kNRMA_RET_mobileViewTiming = "MobileViewTiming"`, `__kNRMA_RET_view = "View"` |
| `AnalyticsController.hpp:36-44` | `__kNRMA_RET_mobileViewTiming` in `_reserved_eventTypes` |

The category constants follow the existing convention where
`kNRMA_RET_userAction = @"UserAction"` is the *category* for the
`MobileUserAction` event type (`Constants.m:49-51`).

The MobileView attribute-name constants move out of their three `static` copies.
Swift owns them in the emitter; the ObjC producers stop needing them entirely,
since they no longer assemble dictionaries.

## Call-site migration

| Site | Record it builds |
|---|---|
| `NRMAMobileViewTracker.m:323` | `.appeared`, `.uiKit`, load outcome from the existing `kNRMAMaxPlausibleLoadMs` test |
| `NRMAMobileViewTracker.m:393` | `.disappeared`, `.uiKit`, `timeVisibleMs`, `restarted` |
| `NRMAViewContext.m:301` | `.appeared`, platform from the uncovered entry, `reappeared: true`, no load |
| `NRMAViewContext.m:434` | phase from its `appeared:` parameter, `.manual`, `timeVisibleMs` when present |
| `NRViewModifier.swift:171` | `.appeared`, `.swiftUI`, load outcome, `restarted` |
| `NRViewModifier.swift:207` | `.disappeared`, `.swiftUI`, `timeVisibleMs`; churn now decided by the emitter |
| `NRViewModifier.swift:410` | `.appeared`, `.swiftUI`, `navigationKind: "tab"`, `.unavailable(.noConstructionObserved)` |
| `NRViewModifier.swift:438` | `.disappeared`, `.swiftUI`, `navigationKind: "tab"`, `timeVisibleMs` |
| `NRMAViewTiming.m:195` | `ViewTimingRecord` from the existing snapshot |

ObjC producers add `#import <NewRelic/NewRelic-Swift.h>`. Precedent:
`Agent/General/NewRelicAgentInternal.m:63`. Swift reaches `NRMAAnalytics` through
`@_implementationOnly import NewRelicPrivate`, since `NRMAAnalytics.h` is already
in `Agent/APrivateHeader.h:26`. Both directions are proven in this target.

`NRMobileViewGate.shouldRecord` stays as the SwiftUI-side early-out — it avoids
building a record at all — but the emitter becomes the authority on the gate, so
a producer cannot emit while the feature is disabled.

`NRMAMobileViewTracker.h:25-26` is corrected from seconds to milliseconds
(decision 7).

New files are added to both the **Agent** and **Agent-watchOS** targets in
`Agent.xcodeproj/project.pbxproj`. The emitter must not require UIKit — it needs
only Foundation and `NRMAAnalytics`.

## Data flow

1. A producer observes a lifecycle event and computes its durations under
   whatever lock or associated-object state it owns.
2. It builds a record — directly in Swift, or via the `@objc` facade.
3. `attributes()` merges customer attributes first, then the referrer, then the
   reserved keys, so reserved keys always win.
4. `emit()` checks the flag gate and `isShutdown`, then calls the matching
   `NRMAAnalytics` method.
5. `NRMAAnalytics` branches on the event-system flag and builds the built-in
   event for whichever system is live.
6. `category` is added at serialization time in both systems, past the attribute
   validator.

## Risks

**`isShutdown` regression.** All nine sites currently reach analytics through
`+[NewRelic recordCustomEvent:]`, which checks
`[NewRelicAgentInternal sharedInstance].isShutdown` first
(`Agent/Public/NewRelic.m:723-726`). Going direct to `NRMAAnalytics` skips that.
The facade must carry the check forward, or a shut-down agent starts emitting
view events. Needs a test.

**Reserved-type rejection is customer-visible.** Decision 6 makes
`recordCustomEvent("MobileView"|"MobileViewTiming")` fail under the new event
system where it previously succeeded. Accepted; worth a release note.

**Locked regions.** The design deliberately keeps the emitter out of
`NRMAViewContext.m`'s `os_unfair_lock` regions and the swizzle bodies. The
existing comment at `NRMAViewContext.m:217-219` — that the analytics stack must
never be entered while holding that non-recursive lock — still applies to the new
call path.

## Testing

The 42 existing MobileViews tests exercise context and timing logic rather than
transport, so they are the regression net and should pass unchanged:
`NRMAViewTimingTests.m` (25), `NRMAViewContextPersistenceTests.m` (10),
`NRMAViewContextChurnTests.m` (4), `NRMobileViewFeatureFlagGateTests.swift` (3).

New tests, written first:

| Area | Test |
|---|---|
| `NRMAViewEvent` | `-JSONObject` includes `category`; secure-coding round trip preserves it |
| `NRMAAnalytics` | `-addMobileViewEventWithAttributes:` lands the event under **both** flag states — the test that would have caught problem 1 |
| `NRMAAnalytics` | same for `-addViewTimingEventWithAttributes:` |
| C++ `ViewEvent` | serialize → deserialize preserves eventType and category (the offline-storage failure mode) |
| Emitter | record → expected attributes, per platform and phase |
| Emitter | `LoadOutcome` produces exactly one of `loadTime` / `loadTimeUnavailable` |
| Emitter | customer attributes cannot override reserved keys |
| Emitter | nothing is emitted when the feature flag is off, or when the agent is shut down |
| Reserved types | `recordCustomEvent("MobileView")` is rejected under both event systems |

Running the suite on this machine: needs `IPHONEOS_DEPLOYMENT_TARGET=15.0` under
Xcode 27; skip the two `NSURLSession` classes, which hang forever behind a TLS
proxy. Baseline is 787 tests / 3 network failures, and 5
`NRMASessionExclusivityWithDelegateTests` upload tests already fail on a clean
tree.

## Non-goals

- **Not** collapsing two events per appearance into one (DACI action #2). That is
  a pending product decision with a public-contract consequence; this design
  makes it a one-file change later.
- **Not** changing the attribute schema, `viewInstanceId` cardinality, or
  retention behavior.
- **Not** moving derivation (the plausibility ceiling, `restarted`, ms
  conversion) into Swift — rejected as approach C because the diff would reach
  into the swizzle bodies and locked regions where timestamp semantics are
  load-bearing.
- **Not** addressing Android parity (DACI action #3).

## Implementation notes

Four things came out differently from the design above. Recorded here because each was a
judgement call, not a detail.

### 1. `agentName` is on MobileViewTiming and not on MobileView

Commit `fb34bb84` ("remove agentName") stripped `agentName` from six emission sites but left
it at three: both `NRMAViewContext.m` sites and the `NRMAViewTiming.m` one. So the attribute
was drifting *within* MobileView (6 sites without, 2 with) but not within MobileViewTiming
(its single site had it, and `NRMAViewTimingTests` asserts it).

Resolved asymmetrically on purpose: MobileView's drift is settled in the direction that commit
chose — no `agentName` — and MobileViewTiming keeps it, because there was no drift there to fix
and removing it would have meant rewriting a test that deliberately pins it. `kNRViewAgentName`
stays the hardcoded `"iOS"` the three producers used, rather than
`+[NewRelicInternalUtils osName]`, which would change the value on tvOS and watchOS — a wire
change, not a refactor.

### 2. `churn` now applies to every producer

It previously reached only the SwiftUI disappear site, so a UIKit or manual view with the same
sub-dwell lifetime went unmarked and inflated screen-view counts. The emitter derives it from
`timeVisible`, so all four disappear producers mark it. Additive — `WHERE churn IS NULL` keeps
working and now also excludes genuinely churny UIKit visits.

### 3. MobileViewTiming splits schema from admission policy

`-[NRMAViewTiming attributesForTimingNamed:...]` is the tested surface for the timing schema (19
of that class's 25 tests assert on its dictionary) *and* the admission gate — it validates the
name and duration and applies the per-view-instance cap, which mutates bucket state under its own
lock. Making the recorder build the event independently left two builders for one event type,
which is how the `agentName` divergence above got through in the first place.

So the two halves were split by owner: `NRMAViewTiming` keeps admission policy and now returns
`+[NRMAMobileViewRecorder timingAttributes:...]` as its dictionary, and emits through
`+emitTimingWithAttributes:`. One schema owner, and the existing tests keep testing the shape
that actually ships.

### 4. `emit()` returns Bool

`-emitTimingNamed:` has a `BOOL` contract that callers use. Returning `YES` whenever validation
passed — even when the gate or the shutdown check suppressed the send — would have quietly
weakened it, so `emit()`, `send()` and `emitTiming(attributes:)` all propagate the result.

## Verification

- `Agent-iOS`, `Agent-tvOS`, `Agent-watchOS` all build with no errors and no new warnings.
- New tests: 30 `MobileViewEmitterTests` + 7 `NRMAViewEventTests`, all passing.
- Existing suites: `NRMAViewTimingTests` 25/25, `NRMAViewContextPersistenceTests` 10/10,
  `NRMobileViewFeatureFlagGateTests` 3/3, `NRMAAnalyticsTest` 31/31 (including the 4 new cases).
- `NRMAViewContextChurnTests`: 3 of 4 fail. **Pre-existing** — confirmed by reverting
  `NRMAViewContext.m` to `HEAD` and re-running, which reproduces the same three failures with
  the same messages. The synthesized re-appearance is not firing for a past-dwell disappearance;
  unrelated to this change, and untouched by it.
