# Mobile Views — Initiative Design Doc (IDD)

| | |
| --- | --- |
| Status | In Review |
| Start Date | 2026-05-05 |
| Architect / Driver | Justin Rush, Chris Dillard |
| Product Manager | Cheryl Frankenfield |
| Single Threaded Leader | Chris Dillard |
| Product doc | [APPEXP/3902931300](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/3902931300) |
| JIRA Initiative | [NR-356639](https://new-relic.atlassian.net/browse/NR-356639) |
| Production Readiness Checklist | [Template](https://newrelic.atlassian.net/wiki/templates?template=2608824354) |
| Reviewers | Justin Rush, Ying Wang, Mike Bruin, Nisarg Desai; AppEx: Jodi 'JBJ' Kansagor, Sara Schultz; Product: Cheryl Frankenfield (2026-05-08) |
| Supersedes | [Mobile Views Initiative Design Doc (IDD)](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5548769647) rev. 2026-08-24 |

## About this revision

This revision exists to **restore the IDD to initiative scope**. The previous revision had accumulated
per-platform implementation detail — swizzling and associated-object mechanics, `ActivityLifecycleCallbacks`
and `WeakHashMap` state, `DisposableEffect` composition hooks, navigation-container listener wiring,
`NavigatorObserver` overrides, feature-flag bit positions, and language-specific API signatures for six
platforms. That material is real and needed, but it belongs to the agents that implement it, where it can
change on each agent's own release cadence without reopening an initiative-level review.

What stays here is the part every agent must agree on and no agent may decide alone: the **event contract**,
the **flag semantics**, the **timing semantics**, and the **capability set** the public API must expose. What
moved is catalogued in §7.

It also reconciles the document with what is actually implemented on the iOS `mobile-views-2` branch, which
has diverged from the previous revision in three ways that matter cross-platform (§5.3, §5.5, §5.6).

## 1. Problem

Customers instrumenting with any New Relic mobile agent — iOS, Android, React Native, Flutter,
Capacitor/Cordova, .NET MAUI — can already see HTTP requests, interactions, and crashes. None of them
provides a built-in way to measure **which screens users visit, how long each screen takes to load, or how
long users spend on each screen**.

Today that requires hand-instrumenting every screen with `recordCustomEvent("MobileView", …)`. This is
error-prone and inconsistent within a single app, and — the more damaging failure — inconsistent *between*
platforms. A customer shipping iOS, Android, and React Native clients cannot build one screen-level
dashboard, because the three clients do not agree on event names, attribute names, or timing semantics.

The deliverable is therefore not "screen tracking" per agent. It is **one schema, emitted identically by
every agent**, such that a single NRQL query answers the question for a whole customer estate.

## 2. Background

Four properties are already true of every agent, and this initiative is designed to exploit them rather
than add infrastructure:

- Each ships a **custom-events transport** that flushes to the existing ingest pipeline.
- Each performs some form of **lifecycle-aware auto-instrumentation** already, by whatever mechanism suits
  its runtime.
- Each has a **feature-flag mechanism** supporting dark-ship → default-on promotion.
- The Android agent has an internal prototype emitting a `MobileView` event from its activity lifecycle
  callbacks. This IDD aligns all agents on that schema rather than inventing a third one.

No new transport, no new ingest path, no new NRDB event namespace.

## 3. Goals

1. **Automatic per-screen events with zero customer code** when the flag is on, across iOS (UIKit, SwiftUI),
   Android (Activity, Fragment, Compose), React Native, Flutter, Capacitor/Cordova, and .NET MAUI.
2. **An identical schema from every agent** (§5.3), so cross-platform dashboards are trivial rather than a
   per-customer mapping exercise.
3. **A customer-supplied display name per screen**, exposed through whatever hook is idiomatic for the host
   runtime. The *capability* is required of every agent (§6); the *syntax* is each agent's choice.
4. **A manual naming API** for hosts where native lifecycle tracking cannot see screens (§5.5).
5. **Zero impact when disabled.** With all Mobile Views flags off, the agent must be byte-for-byte
   unchanged: no new attribute on any existing event, and no call into the view subsystem from any other
   subsystem.

## 4. Non-goals and fast-follow

- **Web-view page tracking** (WKWebView, Android WebView, RN WebView). Deferred, but the schema reserves
  room for it: `uiPlatform` accepts a `WebView` value without a schema change.
- **Opt-out API.** Every platform needs a "do not track this screen" hook for splash screens, modals, and
  tab containers. The capability is required (§6); iOS has settled on a shape, other agents have not.
- **Coupling to Interactions.** Explicitly out of scope — see §5.6.
- **Agent-measured Time to First Byte.** The agent does not measure TTFB as a view timing: it is a property
  of a network request, and its natural home is `MobileRequest`. It is nonetheless *expressible* by customers
  through capability 8 (§6.2), which is the intended use of a caller-supplied duration whose zero point is not
  the view's appearance. Stamping referrer attributes onto network events — so "which screens are slow
  *because of* network" becomes answerable, and TTFB lands where it belongs — is the recommended next
  increment and is not in scope here.
- **Automatic Time to Full Display / Time to Interactive.** Not obtainable generically on any runtime. This
  initiative accepts that accurate screen timing requires customer instrumentation, and optimises instead for
  making the required call small (§6.2) and for making the remaining backlog queryable (§6.3, §8).

## 5. Design

### 5.1 Architecture

Every agent implements the same four-stage pipeline. Only the first stage is platform-specific.

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │  1. PRODUCERS  (platform-specific — owned by each CDD)               │
  │                                                                      │
  │  Host runtime lifecycle or navigation signals, by whatever mechanism  │
  │  is native to that runtime. One or more producers per agent.          │
  │  Automatic producers and the manual API are peers here.               │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  2. VIEW CONTEXT  (per agent, single instance)                        │
  │                                                                      │
  │  Thread-safe source of truth for current view + referrer. All         │
  │  producers funnel through it, so identity and ordering are consistent │
  │  no matter which producer is active. Assigns viewInstanceId.          │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  3. EVENT EMISSION                                                   │
  │     customEvent("MobileView", attrs)  — schema per §5.3              │
  │     customEvent("MobileViewTiming", attrs) — §5.7                    │
  └────────────────────────────────┬─────────────────────────────────────┘
                                   ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │  4. EXISTING HARVEST PIPELINE  →  NRDB: MobileView / MobileViewTiming │
  └──────────────────────────────────────────────────────────────────────┘
```

Two consequences of stage 2 that are initiative-level requirements, not implementation notes:

- **All producers share one context.** An agent with both automatic and manual producers must not keep two
  notions of "current view", or `previousView` becomes unreliable exactly when a customer mixes the two.
- **`viewInstanceId` is assigned at the context**, not by producers, so it is unique per *visible lifetime*
  even when producers overlap.

### 5.2 Producer contract

A producer is anything that can observe a screen becoming or ceasing to be visible. Each agent decides how
many it needs and how each hooks its runtime — that is CDD material. What every producer must satisfy:

| Requirement | Why it is initiative-level |
| --- | --- |
| Report appearance and disappearance as distinct events, each carrying the same `viewInstanceId` | The `appeared` discriminator (§5.3) is how dwell time is computed downstream |
| Funnel through the shared view context rather than emitting directly | Otherwise `previousView` diverges between producers |
| Declare a `uiPlatform` value from the enumerated set | It is the discriminator every cross-platform query facets on |
| Be inert when its gating flag is off | Goal 5 |
| Suppress appear/disappear pairs shorter than the shared dwell minimum (§6.4) | Construction churn would otherwise dominate event volume and evict real events from the buffer. A sub-threshold disappearance must also not synthesize a `reappeared` row for whatever it was covering, or churn manufactures phantom back-navigation |

Hybrid agents (Capacitor, Cordova, MAUI, Xamarin) **reuse the native iOS and Android producers** through
their bridge layer and expose only a thin JS/C# surface. React Native and Flutter require their own
producers, because navigation state lives in JS/Dart and native lifecycle callbacks do not fire per screen.

### 5.3 Canonical event schema

Event namespace `Custom`; event name `MobileView`. **This table is the contract.** An agent that omits a
required attribute or renames one breaks every cross-platform dashboard, so changes here are IDD changes.

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `viewClass` | string | ✅ | Platform-native class or type name |
| `viewName` | string | ✅ | Customer override, else class or route name |
| `viewInstanceId` | string (UUID) | ✅ | Unique per visible lifetime; the join key |
| `appeared` | bool | ✅ | `true` = became visible, `false` = ceased to be visible |
| `restarted` | bool | ✅ | `false` on first appearance of this screen, `true` after |
| `loadTime` | double | on appear | Best-effort; semantics and accuracy tier per §5.4 |
| `timeVisible` | double | on disappear | Appear → disappear, clamped ≥ 0 |
| `uiPlatform` | string | ✅ | Enum: `UIKit`, `SwiftUI`, `Android`, `AndroidFragment`, `Compose`, `ReactNative`, `Flutter`, `Capacitor`, `Cordova`, `MAUI`, `Xamarin`, `WebView` |
| `agentName` | string | ✅ | The SDK: `iOS`, `Android`, `ReactNative`, … |
| `previousView` | string | when known | Referrer — the screen navigated from |
| `previousViewInstanceId` | string | when known | Referrer identity, for exact-visit joins |
| `reappeared` | bool | when true | Set when the agent *synthesized* the appearance because a covering screen went away, rather than observing it |

Three of these need justification, because they are the changes from the previous revision:

**`uiPlatform`, not `platform`.** The implemented iOS agent emits `uiPlatform`. The previous revision
specified `platform`. `uiPlatform` is the better name — it says *UI runtime*, which is what the field means,
and avoids collision with the ambient notion of platform elsewhere in the product. Adopting the implemented
name is also the only option that does not require a breaking rename in shipped iOS code. **Every other
agent must emit `uiPlatform`.**

**`agentName` × `uiPlatform` is a two-axis discriminator, deliberately.** One field cannot express the
space. `agentName` distinguishes *which SDK*; `uiPlatform` distinguishes *which UI runtime*. This separates
"same SDK, two runtimes" (Android + Compose; iOS + SwiftUI) from "two SDKs, same runtime" (the iOS agent and
MAUI both reporting `UIKit`). Collapsing them loses one of those distinctions.

**`previousView` / `previousViewInstanceId` / `reappeared` are new since the previous revision.** They turn a
list of screen visits into a **navigation graph**, which is what makes the data explanatory rather than
descriptive: the same screen can be shown to be fast when reached from search and slow when reached from a
deeplink. `reappeared` exists because some runtimes report that a screen was covered but never report that
it was uncovered; the agent must synthesize the re-appearance, and consumers need to know which rows are
synthesized. Agents whose runtime does not have that gap simply never set it.

**Interaction attributes are absent** — see §5.6.

### 5.4 `loadTime` semantics and accuracy tiers

`loadTime` is **best-effort and not equally meaningful across runtimes**. Some runtimes expose an exact
construction-to-visible boundary; others only permit an approximation. Comparing an exact value against an
approximate one without knowing which is which produces confidently wrong conclusions, so the IDD requires
the distinction be declarable rather than inferred.

**Contract:**

1. Each agent's CDD **declares its own mapping** from runtime lifecycle signals to `loadTime`, and states
   the resulting tier.
2. `loadTime` is emitted **only on appearance**, and **only for a genuine first construction**. A screen
   that resurfaced without being rebuilt has nothing to time and must omit the attribute.
3. Values are non-negative and monotonic-clock derived. Wall-clock deltas are not acceptable — clock
   adjustment mid-load would otherwise produce negative or absurd durations.
4. All agents emit the **same unit**. Unit drift between agents is the single most likely way to corrupt a
   cross-platform percentile, and it is invisible in the data.

**Tier per platform** (mapping detail lives in each CDD):

| Platform | Tier |
| --- | --- |
| UIKit | Exact |
| Android Activity | Exact |
| Android Fragment | Exact |
| SwiftUI | Approximate |
| Jetpack Compose | Approximate |
| React Native | Approximate — subject to JS-thread contention |
| Flutter | Approximate |
| Capacitor / Cordova | Approximate |
| MAUI | Approximate |

Because approximate is the common case, `loadTime` alone is insufficient for the product goal. §5.7 is the
answer.

### 5.5 Feature-flag model

There is **no single Mobile Views switch.** Automatic and manual tracking are **independent flags, both
disabled by default**:

| Flag | Gates |
| --- | --- |
| Automatic Mobile Views | All automatic producers for that agent's native UI runtimes |
| Manual Mobile Views | The manual "set current view" API |

- **Either** flag enables the shared referrer plumbing (`currentView` / `previousView` on breadcrumbs).
- With **both** off, Goal 5 applies strictly: no new attribute anywhere, and no other subsystem calls into
  the view subsystem.

**Why two flags rather than one.** A React Native or Capacitor host must be able to enable **manual only**.
Its native automatic producer would report a single generic host container for the entire app — pure noise —
while the JS layer is the only thing that knows the real screen names. One combined flag forces that host to
choose between no data and bad data. This is the load-bearing reason the split exists, and it generalizes to
every hybrid runtime.

Flag bit positions and per-agent flag plumbing are CDD material (§7).

### 5.6 Relationship to Interactions

**`MobileView` and Interaction remain completely independent.** `MobileView` events carry no interaction,
component, or trace-segment attributes, and the interaction subsystem does not consult the view subsystem.
This is verified in the iOS implementation on `mobile-views-2`.

This was reached by amendment after an earlier design correlated the two. Independence is the right call:
the two subsystems have different lifetimes and different failure modes, and coupling them made view events
inherit interaction-trace timeout semantics — which are themselves not consistent across platforms. Keeping
them separate means a view event is complete and correct on its own.

Correlating views with interactions remains possible downstream, at query time, via `sessionId` and
timestamp. Any agent that reintroduces the coupling in code is diverging from this IDD.

### 5.7 Companion event: `MobileViewTiming`

`loadTime` is fixed at the moment a screen becomes visible. For most runtimes that is *also* the moment the
screen is still showing a spinner: a screen that renders a skeleton in 80 ms and real content in 900 ms
reports 80 ms. Time to Full Display and Time to Interactive cannot ride the `MobileView` event at all,
because they are not yet known when it is emitted.

`MobileViewTiming` is therefore a **separate, streamed event — one per timing, sent as soon as its value is
known** — modelled on browser's `PageViewTiming`.

Initiative-level requirements:

| Requirement | Rationale |
| --- | --- |
| Every timing carries `viewInstanceId` | Joins the timing to the specific *visit*, not merely the screen name |
| Every timing carries `previousView` when known | Makes timings queryable by route, per §5.3 |
| One agent-owned baseline timing is emitted with no customer code | Guarantees dashboards populate for every customer, and puts customer marks on the same axis as the agent's own |
| One event per timing, emitted as soon as its value is known | A screen's timings arrive at different moments; batching them would delay the earliest until the last is known |
| Validation, caps, and reserved names per §6.4 | Every rejection rule is invisible in the data, so all agents must apply the same ones |
| `loadTime` remains on `MobileView` | Additive by design; removing it breaks already-shipped panels |

The event schema is §5.8. The public API for customer-supplied timings, the agent-owned baseline, and the
normative shared constants are specified in §6.2–§6.4.

iOS has this implemented; see `docs/superpowers/specs/2026-08-28-mobileview-timing-design.md` for the iOS
realisation and its threading invariant. That document is a CDD-level companion — where it and §6 differ on a
shared value, §6 governs.

### 5.8 Canonical `MobileViewTiming` schema

Event namespace `Custom`; event name `MobileViewTiming`. **This table is the contract**, on the same terms as
§5.3: an agent that renames `timingName`, or ships `timingValue` in seconds, produces rows that look valid and
aggregate wrongly against every other agent's.

| Attribute | Type | Required | Notes |
| --- | --- | --- | --- |
| `timingName` | string | ✅ | The timing's identity: `timeToInitialDisplay` (§6.3) or a customer-supplied name (§6.2). Validated per §6.4 |
| `timingValue` | double | ✅ | Duration in **milliseconds**. Finite, ≥ 0, ≤ 600000 (§6.4) |
| `agentName` | string | ✅ | The SDK — same enum and meaning as §5.3 |
| `viewName` | string | when a view is current | The screen the timing is about |
| `viewInstanceId` | string (UUID) | when a view is current | Join key back to the exact `MobileView` **visit** that produced it |
| `previousView` | string | when known | Referrer, so timings are queryable by route rather than only by destination |
| `uiPlatform` | string | when a view is current | UI runtime — same enum as §5.3 |

Four properties of this schema are load-bearing and are the ones an agent is most likely to get wrong:

**Name–value, not one attribute per timing.** A timing is `timingName` + `timingValue`, and each event carries
exactly one. The alternative — widening the event with a column per timing — cannot express a set the customer
defines at runtime, and forces every timing to wait for the slowest one before any of them can be sent. This
is why `MobileViewTiming` is a separate streamed event rather than more attributes on `MobileView`; see the
`FACET timingName` queries in §8, which are only possible in this shape.

**View identity is conditional, not required.** Capability 8 succeeds with no view being tracked (§6.2), so
`timingName` + `timingValue` + `agentName` alone is a **valid row**. Agents must not manufacture a placeholder
view name to fill the gap: an unattributed timing that claims a screen is worse than one that admits it has
none, because it is indistinguishable from a real measurement in an aggregate. Consumers filter on
`viewInstanceId IS NOT NULL` when they need attributed rows only.

**Absent means absent.** When a value is unknown the key is **omitted**, never emitted as an empty string,
`"unknown"`, or `null`. Empty strings become a legitimate-looking facet value that silently splits every
group-by, and they defeat `IS NULL` filtering — so this is a query-correctness rule, not formatting.

**Deliberately narrower than `MobileView`.** `viewClass`, `restarted`, `appeared`, `timeVisible`, and
`previousViewInstanceId` are **not** on this event. Everything but the last is already reachable by joining on
`viewInstanceId`, and duplicating it costs event volume for no additional information. `previousViewInstanceId`
is the real omission: timings can be faceted by referrer **name**, but cannot be joined to the exact referrer
*visit* the way `MobileView` rows can. That is a live limitation, not a settled decision — see §11.

## 6. Public API contract

The IDD specifies **capabilities, not syntax.** Every agent must expose all eight; each does so in whatever
form is idiomatic for its language and runtime, documented in its CDD.

### 6.1 View capabilities

| # | Capability | Contract |
| --- | --- | --- |
| 1 | Enable automatic tracking | Independent flag, off by default (§5.5) |
| 2 | Enable manual tracking | Independent flag, off by default (§5.5) |
| 3 | Set current view manually | Name plus optional custom attributes. Browser route-change semantics: setting a new view closes the previous one and emits its dwell time |
| 4 | Override display name per screen | Per-screen hook; affects `viewName` only, never `viewClass` |
| 5 | Ignore a screen | Suppresses all events for that screen. Required for splash screens, modals, and tab containers |
| 6 | Attach custom attributes per screen | Merged into every event for that screen. **Must not** be able to overwrite any attribute in §5.3 |

Two rules that are contract, not style:

- **Capabilities 4 and 5 should share one hook where the language allows it.** iOS folds them together —
  returning a name overrides, returning nothing ignores — which keeps the API surface at one member instead
  of two. Agents whose language cannot express the absent case cleanly may split them.
- **Reserved keys are non-overridable.** Every attribute in §5.3 must be rejected if supplied through
  capability 6. Otherwise a customer can silently corrupt the very fields the cross-platform dashboards
  depend on.

### 6.2 Timing capabilities

`loadTime` is approximate on most runtimes (§5.4), so the timings customers actually need — Time to Full
Display, Time to Interactive — must come from customer code that knows when the screen genuinely reached
that state. These two capabilities are how they supply it. Both emit `MobileViewTiming` (§5.7).

| # | Capability | Contract |
| --- | --- | --- |
| 7 | **Mark** a timing against the current view | Duration is measured by the agent, from the current view's appear time until the moment of the call. Takes a name only |
| 8 | **Record** a timing with a caller-supplied duration | Takes a name and a duration in **milliseconds**. Used when the view's appear time is the wrong zero point |

**Why two, and not one.** TTID, TTFD, and TTI are all "from view appear until X", which capability 7
expresses in a single call with no state for the customer to manage. Capability 8 exists for the cases that
do not share that zero point — a prefetch that began before navigation, or a duration measured by the
customer's own code or another SDK. Together they cover the space without a registry of open marks, which
would drag in eviction policy, timeout semantics, and leaks on screens that vanish mid-measurement.

**Divergent no-current-view behaviour is deliberate and must be preserved by every agent:**

| | Capability 7 (mark) | Capability 8 (record) |
| --- | --- | --- |
| No view currently tracked | **Fails.** There is no zero point; emitting a wrong number is worse than emitting nothing. Agents must direct callers to capability 8 | **Succeeds.** The caller supplied the value; the event is recorded without view identity and is queryable as unattributed |
| View currently tracked | Emits with `viewName`, `viewInstanceId`, `previousView` | Emits with `viewName`, `viewInstanceId`, `previousView` |

**Both capabilities must report success or failure to the caller.** A timing can be rejected for six
distinct reasons (§6.3), all of them silent in the data — a customer who cannot tell that their marks are
being dropped will conclude the feature is broken. Agents return a boolean where the language convention
allows it, and use the idiomatic failure signal otherwise; a fire-and-forget signature is not acceptable.

**Gating.** Both are active when **either** Mobile Views flag is enabled (§5.5), and both fail when both
flags are off. Timing is not separately flagged: a timing with no view context to attach to is not a feature
anyone asked for, and a third flag would let customers reach a state where marks silently vanish.

### 6.3 Agent-owned emission

Independently of anything the customer calls, **every agent emits one baseline timing automatically.**

- **Name:** `timeToInitialDisplay` — the same string on every agent.
- **Value:** projected from the `loadTime` the agent already measures for that appearance. This is a second
  projection of an existing number, not a new measurement: no new hook, no new swizzle, no added cost.
- **When:** on every `MobileView` appearance that carries `loadTime`. A screen that resurfaced without being
  rebuilt emits no baseline row, mirroring the `loadTime` rule in §5.4 — nothing was constructed, so there is
  nothing to time.

This matters for three reasons that are all cross-platform:

1. **Every timing dashboard populates with zero customer code.** Without it, a customer who has not yet
   instrumented anything sees empty charts and concludes the feature does not work.
2. **It puts customer marks on the same axis as the agent's own.** `timeToFullDisplay` minus
   `timeToInitialDisplay` is the interval during which the screen looked finished but was not — the single
   most useful number this initiative produces, and it requires both series to exist in the same event type
   with the same units.
3. **It is the coverage signal.** Screens reporting *only* `timeToInitialDisplay` are exactly the screens
   still lacking customer instrumentation, which makes the instrumentation backlog queryable (§8).

Consequently the baseline is **privileged**: it is exempt from the per-view cap, because the row that
guarantees the dashboard populates must never be the row that gets dropped, and `timeToInitialDisplay` is
**reserved** — capabilities 7 and 8 must reject it, or one app's custom mark silently redefines the
cross-app baseline.

### 6.4 Shared constants (normative)

These are **contract values, not per-agent tuning.** They are shared because every one of them is invisible
in the resulting data: an agent that picks a different ceiling or a different reserved name produces rows
that look valid and aggregate wrongly against every other agent's.

| Constant | Value | Applies to | Rationale |
| --- | --- | --- | --- |
| Baseline timing name | `timeToInitialDisplay` | §6.3 | Cross-app comparability; reserved from customer use |
| Max customer timings per view instance | **16** | Capabilities 7, 8 | The event buffer is bounded (1000 by default). An unguarded mark inside a list-row callback would evict the customer's own real events. Warn once when exceeded, then drop silently |
| Max timing name length | **128** characters | Capabilities 7, 8 | Bounds attribute cardinality |
| Max accepted duration | **600000** ms (10 minutes) | Capability 8 | Catches the seconds-passed-where-milliseconds-expected mistake instead of recording it as a ten-hour screen load |
| Minimum dwell for a real appearance | **100** ms | §5.2 | Below it, an appear/disappear pair is construction churn, not a visit |
| Timing unit | milliseconds | Capabilities 7, 8; §5.7 | Unit drift between agents corrupts cross-platform percentiles invisibly |
| Unattributed-bucket window | **60** seconds | Capability 8 | See below — a rolling window, not a lifetime cap |
| Max tracked cap buckets | **64** | Capabilities 7, 8 | Bounds cap bookkeeping; without it a long session retains one bucket per view instance ever visited |

**Rejection rules, applied by every agent in this order.** A timing is rejected — and the failure reported
per §6.2 — when:

1. both Mobile Views flags are off;
2. the name is empty, or longer than 128 characters;
3. the name is `timeToInitialDisplay` (reserved);
4. capability 7 was called with no view currently tracked;
5. the duration is non-finite (`NaN`, `±inf`), negative, or above 600000 ms — a single `NaN` silently
   poisons every average and percentile computed downstream, so this is a correctness rule, not hygiene;
6. the per-view-instance cap of 16 is already reached.

Rows with no `viewInstanceId` — capability 8 called with no current view — share a single unattributed cap
bucket, because otherwise an uncapped path exists in precisely the case where no view identity is available to
key a cap on. That bucket is a **rolling 60-second rate limit, not a lifetime cap**: a per-view-instance bucket
is self-limiting because the view goes away, but this one never does, so a lifetime cap of 16 would let sixteen
unattributed timings early in a launch silence the path for the whole session.

Cap bookkeeping is itself bounded to 64 buckets, oldest-inserted evicted first. Eviction re-admits a view to
its cap, which is acceptable: an evicted bucket belongs to a screen the user left long ago.

## 7. Delegated to the CDDs

Everything below was removed from this document. Each item is listed with its owner so nothing is lost in
the move.

| Detail | Owner |
| --- | --- |
| Lifecycle-hook mechanism (method swizzling; which methods; installation and idempotency) | iOS CDD |
| Per-instance state storage (associated objects) | iOS CDD |
| SwiftUI producer: view-modifier design, state-tracked timing, the modifier family | iOS CDD |
| Synthesized re-appearance algorithm and view-stack removal semantics | iOS CDD |
| Concrete `loadTime` mapping for UIKit and SwiftUI, and its tier justification | iOS CDD |
| Flag bit positions; Obj-C and Swift signatures for all six capabilities | iOS CDD |
| Threading model: lock choice, snapshot-then-emit ordering, harvester lock-order hazard | iOS CDD |
| Timing storage: per-view-instance cap bookkeeping, bucket lifetime, unattributed-bucket reset | All CDDs |
| Timing signatures and failure signalling for capabilities 7 and 8 in each language | All CDDs |
| How the baseline timing is projected from that agent's `loadTime` on the appear path | All CDDs |
| Activity and Fragment lifecycle-callback registration, incl. recursive fragment registration | Android CDD |
| Jetpack Compose producer: composition-effect and lifecycle-observer design; reuse of existing Compose Navigation instrumentation | Android CDD |
| Per-instance state storage (weak-keyed map) | Android CDD |
| Concrete `loadTime` mapping for Activity, Fragment, and Compose, and tier justification | Android CDD |
| Annotation-based naming and ignore hooks; Kotlin/Java signatures | Android CDD |
| React Navigation state listener and route-stack diffing; wrapper component and hook forms; JS→native bridge timing transfer | React Native CDD |
| `NavigatorObserver` subclass, push/pop/replace handling, per-route naming | Flutter CDD |
| Web-layer router event subscription; reuse of browser page-view implementation; bridge to native plugins | Capacitor / Cordova CDD |
| Page appearing/disappearing subscription; attribute-based naming | MAUI / Xamarin CDD |
| Per-agent tracker class naming and idempotent start | All CDDs |

Existing CDDs: [iOS Implementation](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5536055442) ·
[Android Implementation](https://newrelic.atlassian.net/wiki/x/A4AVTAE). Hybrid CDDs are not yet written.

**Each CDD must state, explicitly, how it satisfies §5.2, §5.3, §5.4, §5.5, and §6.** A CDD that silently
diverges from the schema is the one failure mode this split introduces, and review is the control for it.

## 8. NRDB

- **EventNamespace:** `Custom`
- **EventNames:** `MobileView`, `MobileViewTiming`
- **Schema:** §5.3 and §5.7, plus `timestamp` and standard session attributes

Representative queries the schema must support:

```sql
-- Dwell time and traffic per screen
SELECT average(timeVisible), count(*) FROM MobileView
WHERE appName = 'MyApp' AND appeared IS false FACET viewName SINCE 1 day ago

-- Cross-platform coverage: which SDK, which UI runtime
SELECT count(*) FROM MobileView
WHERE appName = 'MyApp' FACET uiPlatform, agentName SINCE 1 week ago

-- Load percentiles compared across agents
SELECT percentile(loadTime, 50, 95, 99) FROM MobileView
WHERE appeared IS true FACET agentName SINCE 1 day ago

-- Navigation graph: routes, not just destinations
SELECT count(*) FROM MobileView
WHERE appeared IS true FACET previousView, viewName SINCE 1 day ago
```

The navigation-graph query is only answerable because of the referrer attributes added in this revision.

`MobileViewTiming` adds three that the `MobileView` schema alone cannot express:

```sql
-- The interval where the screen looked finished but was not.
-- Requires the agent-owned baseline (§6.3) and a customer mark on the same axis.
SELECT filter(percentile(timingValue, 50), WHERE timingName = 'timeToFullDisplay')
     - filter(percentile(timingValue, 50), WHERE timingName = 'timeToInitialDisplay')
       AS 'ms the screen was lying'
FROM MobileViewTiming FACET viewName SINCE 1 day ago

-- Instrumentation backlog: screens reporting ONLY the agent baseline
-- are the screens with no customer marks yet.
SELECT uniques(timingName) FROM MobileViewTiming FACET viewName SINCE 1 day ago

-- Timings by route rather than destination: the same screen fast from
-- search and slow from a deeplink.
SELECT percentile(timingValue, 50, 95) FROM MobileViewTiming
WHERE timingName = 'timeToFullDisplay' FACET previousView, viewName SINCE 1 day ago
```

The first is the number that justifies the initiative, and it is only computable because the baseline and the
customer mark share an event type, a unit, and a `viewInstanceId` (§6.3, §6.4). The second is why the
agent-owned baseline is required rather than optional: without it, an uninstrumented screen is
indistinguishable from a screen with no traffic.

## 9. Customer Zero

- **New Relic Mobile Apps team** — ships our own NR1 mobile clients. Running iOS + Android + a hybrid means
  dogfooding three agents at once, which is the only realistic way to validate cross-platform dashboard
  parity before customers do.
- **Per-agent internal demo apps** enable the flags in CI, to catch schema drift between agents at build
  time rather than in NRDB.
- **AppExp team** consumes `MobileView` events to decorate MSR experiences.

## 10. Teams

| Team | Work |
| --- | --- |
| Mobile Agents — telemetry | [iOS Implementation](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5536055442) · [Android Implementation](https://newrelic.atlassian.net/wiki/x/A4AVTAE) · Hybrids (Flutter, React Native) |
| App Experience Mobile | [AppExp feature](https://new-relic.atlassian.net/browse/NR-562386) · [UI Entry Points](https://newrelic.atlassian.net/wiki/spaces/APPEXP/pages/5558075536) |

## 11. Open questions

1. **Ratify `uiPlatform` over `platform`** (§5.3). iOS has shipped `uiPlatform`. Needs explicit sign-off so
   Android and the hybrids implement the same name rather than the previous revision's.
2. **Adopt `previousView` / `previousViewInstanceId` / `reappeared` as required, or optional?** They are
   implemented on iOS and unlock the navigation-graph queries. `reappeared` is genuinely
   runtime-conditional, but the two referrer fields arguably should be mandatory for every agent.
3. **Ignore-hook shape for non-iOS agents** (§4, capability 5). iOS has settled; the others have not.
4. **`MobileViewTiming` rollout order.** iOS is implemented. Whether it lands per-agent alongside
   `MobileView` or as a follow-on wave is unresolved, and it determines whether the timing dashboards can be
   cross-platform at launch.
5. **Ratify the shared timing constants in §6.4.** They are lifted from the iOS implementation and are now
   stated normatively here rather than in an iOS-only document. Each is a value an agent could plausibly
   have chosen differently, and every one of them is invisible in the resulting data, so they need explicit
   cross-platform sign-off rather than inheritance.
6. **Should `MobileViewTiming` carry `previousViewInstanceId`?** (§5.8). It carries `previousView`, so timings
   can be faceted by referrer name but not joined to the exact referrer *visit*. Adding it makes the timing
   event a first-class node in the same navigation graph as `MobileView`, at the cost of one attribute on every
   timing row. iOS has shipped without it, so this is cheapest to settle before other agents implement.
7. **Decorate `MobileRequest`, `MobileRequestError`, and Handled Exceptions with the current/previous view**
   (`currentView`, `currentViewInstanceId`, `previousView`, `previousViewInstanceId`), so a request, a
   request error, or a handled exception can be joined back to the screen it happened on without a
   `sessionId` + timestamp correlation at query time. This is the same referrer plumbing §5.5 already
   requires for breadcrumbs, applied to three more producers — iOS has the mechanism (`NRMAViewContext`)
   but today only `recordBreadcrumb:` calls into it, and it does not yet expose `currentViewInstanceId` at
   all (`referrerAttributes` returns `currentView` by name only), so this is a schema addition, not just a
   new consumer of an existing one. It also supersedes the §4 non-goal that named this "the recommended
   next increment... not in scope here" for network events specifically — that line should be reconciled or
   dropped if this question is adopted.

   **Crashes are deliberately excluded from this list** and should be tracked separately rather than folded
   in here. The other three are emitted in-process while the view subsystem's state is still live; a crash
   report is captured by a signal/exception handler and is typically packaged into an event on the *next*
   launch, by which point `NRMAViewContext`'s in-memory state is gone. Decorating crashes needs either (a)
   the current/previous view persisted to disk on every transition so it survives the crash, or (b) a
   snapshot captured from inside the crash handler itself — the latter reintroduces the reentrancy and
   lock-ordering hazard already known from session-start (§6, threading model). That is a materially
   different design problem and should not block sign-off on the other three.
