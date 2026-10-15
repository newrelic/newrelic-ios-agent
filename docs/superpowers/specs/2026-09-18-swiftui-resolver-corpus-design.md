# Third-Party App Corpus for the SwiftUI Automatic Views Resolver

Date: 2026-09-18
Status: Design approved, implementation not started
Feature under test: `NRFeatureFlag_AutomaticSwiftUIViews` / `Agent/MobileViews/SwiftUIScreenResolver.swift`

## 1. Problem

`SwiftUIScreenResolver` recovers a screen name for a SwiftUI hosting controller by
`Mirror`-walking the host's storage. Every input it depends on is an undocumented SwiftUI
implementation detail: the `"HostingController"` substring in a class name, `AnyViewStorage`,
`LazyView` / `ParameterizedLazyView`, `superclassMirror` layout, and the fact that
`Optional<AnyView>.none` satisfies `value is any View`.

The feature is on by default (`NewRelicFeatureFlags.h:130`) and its designed failure mode is
silence: when the content type cannot be recovered, nothing is emitted. That combination means
we currently have no way to answer "does this work on apps we did not write?"

The existing evidence base cannot answer it either:

- All 36 tests in `Tests/Unit-Tests/NewRelicAgentTests/MobileViews-Tests/SwiftUIScreenResolverTests.swift`
  instantiate `UIHostingController` or a hand-written subclass. The four classes that motivated
  the resolver — `NavigationStackHostingController`, `PresentationHostingController`,
  `TabHostingController`, `UIKitTabBarController` — are private to SwiftUI and never appear in
  the suite.
- `SwiftUIScreenResolver.swift` records two bugs that shipped through exactly that gap: *"Plain
  `UIHostingController` worked, which is why unit tests over it passed while a whole app stayed
  silent"*, and a route-scan misfire that named every tab in an app `__C.CoreSystem.CoreSystem`.
- `HomeSearch`, `ExpensesTracker` and `NRTestApp` were written by the same people who wrote the
  resolver, so they encode the same assumptions about how a SwiftUI app is structured. That is
  the specific blind spot this corpus exists to escape.

## 2. Goals

1. Measure the resolver's **unresolved rate** against SwiftUI apps written by people who have
   never heard of this agent.
2. Attribute the numerator: for each unresolved host, know its class and which stage of
   resolution gave up.
3. Produce a committed baseline so a resolver change shows up as a numeric diff in a PR.
4. Incidentally validate the three node budgets (`maxNodes`, `rootSearchMaxNodes`,
   `routeSearchMaxNodes`) and the main-thread cost of the walk, both of which are currently
   unverified guesses.

## 3. Non-goals

- **Supportability metrics.** Explicitly out of scope. Fleet-wide measurement through the
  harvest is a separate piece of work; this design uses debug logging only and adds nothing to
  the wire.
- **Fixing the defects the corpus finds.** Each becomes its own change.
- **Exact-name assertions.** We measure whether a host resolved and eyeball the resulting names
  for plausibility. Golden-file name assertions belong to the idiom-matrix work, not here.
- **CI integration and real-device runs.** Both are plausible follow-ups; neither is in this
  design.
- **Design-partner customer builds.** The other half of the original recommendation. Out of
  scope here; this covers the open-source half.

## 4. Decisions

Each of these was a real fork. Recording the rejected option matters because several were
chosen against the recommendation, and the reasons should survive.

### 4.1 Full agent per app, not a standalone probe dylib

`SwiftUIScreenResolver.swift` imports only `Foundation`, `UIKit` and `SwiftUI` — no agent
dependencies — so it could have been compiled into a small dylib and injected with
`DYLD_INSERT_LIBRARIES`, requiring no changes to corpus apps at all.

**Chosen: the real agent, linked into each app.** The probe would have measured the resolver in
isolation, missing the parts of the path that also decide whether a screen is reported: the
class-prefix exclusion list, `NRMA_ShouldSkipClass`, the uncached-miss behaviour, the appear /
disappear / background-flush call sites, and whether resolved names actually reach a
`MobileView` event. The corpus should exercise what a customer would get.

### 4.2 Vendor app source into this repo

Alternatives were a manifest plus per-app patch files with gitignored checkouts, or forks in a
New Relic org.

**Chosen: vendor.** Self-contained, always builds, no setup script between a developer and a
working corpus app.

Accepted consequences, which become hard admission gates in §6:

- `newrelic-ios-agent` is a **public Apache-2.0 repo**. Vendored source must be permissively
  licensed (MIT / Apache-2.0 / BSD), with the upstream `LICENSE` preserved verbatim and
  attribution recorded. GPL/AGPL apps are excluded. Apple sample code is excluded — its license
  restricts redistribution.
- Upstream changes cannot be pulled; a vendored app is a snapshot. Re-vendoring is a manual
  refresh, which is why `PROVENANCE.md` records the exact upstream SHA.
- A human must sign off on vendoring third-party source into a public New Relic repo before the
  first app is committed.

### 4.3 Link the agent from `Agent.xcodeproj`, not a prebuilt XCFramework

**Chosen: a subproject reference,** exactly as `Test Harness/HomeSearch/generate_project.rb:104-148`
does it. No build step to remember, no binary in the repo, no staleness, and breakpoints in
`SwiftUIScreenResolver.swift` are live while a third-party app runs — which for diagnosing *why*
a host failed is worth more than any log line.

### 4.4 Selection by navigation-idiom coverage

Alternatives were realism/size, architecture diversity, or whatever builds first.

**Chosen: idiom coverage.** Each app earns its slot by covering a host shape no other app does
(§6). The acknowledged weakness is that we can only enumerate idioms we already know about,
which is a milder version of the blind spot being escaped — partly mitigated because the apps
themselves are foreign, so their *accidental* structure is still outside our assumptions.

### 4.5 A shared generic crawler with per-app overrides

**Chosen** over an unconstrained monkey (nondeterministic, wanders into destructive actions) and
over recorded manual walks (not unattended).

### 4.6 Debug-only agent logging as the denominator

**Chosen** over inferring misses by comparing the walk's screen list against captured
`MobileView` events. Logging gives an exact per-host denominator *and* the cause, which is what
turns a bad number into a fix. Walk-based ground truth would need human judgement per app and
could not say why anything was missed.

## 5. Architecture

### 5.1 Layout

```
Test Harness/Corpus/
  README.md                 # purpose, how to run, license inventory
  corpus.yml                # per app: upstream URL, pinned SHA, license, scheme, idiom slot
  THIRD_PARTY_NOTICES.md    # attribution for every vendored app
  integrate_agent.rb        # xcodeproj-gem surgery; generalized from generate_project.rb
  Bootstrap/
    NRCorpusBootstrap.m     # starts the agent with zero app source edits
  apps/<AppName>/
    LICENSE                 # upstream, verbatim
    PROVENANCE.md           # upstream URL, SHA, vendored date, license, what we changed
    walk.yml                # per-app crawler overrides (optional)
    <vendored source tree>
scripts/
  corpus_walk.py            # pepper-ctl driven crawler
  corpus_report.py          # log parser and report generator
docs/superpowers/specs/
  2026-09-18-swiftui-resolver-corpus-design.md
```

Corpus app projects are added to `Agent.xcworkspace` as `FileRef`s alongside `NRTestApp` and
`HomeSearch`.

### 5.2 Agent integration, per app

`integrate_agent.rb` takes a project path and target name and performs the same surgery as
`generate_project.rb`:

1. Add a file reference to `Agent.xcodeproj`, which makes the `xcodeproj` gem generate the
   subproject wiring (container item proxies, product reference proxies, `project_references`).
2. Find the product proxy by the **remote UUID** of the `Agent_iOS` product. Matching on the
   name `NewRelic.framework` is a coin flip between the iOS, tvOS and watchOS products.
3. Add a `PBXTargetDependency` on `Agent_iOS` so the agent builds first.
4. Link the proxy into the frameworks build phase.
5. Add an `Embed Frameworks` copy phase with `RemoveHeadersOnCopy`.
6. Add `Bootstrap/NRCorpusBootstrap.m` to the app target's sources.

Steps 1-5 are ported; step 6 is new. **No corpus app source file is edited**, so the entire diff
against pristine upstream is project-file plus one added file, and `PROVENANCE.md` can state
that precisely.

### 5.3 `NRCorpusBootstrap.m`

An `+load` that registers for `UIApplicationDidFinishLaunchingNotification` and, when it fires,
configures and starts the agent. `+load` alone would run before `UIApplication` exists; the
notification is a supported start point and needs no app source change.

It sets:

- a corpus application token,
- `[NRLogger setLogTargets:NRLogTargetConsole|NRLogTargetFile]` and verbose level,
- `NRFeatureFlag_AutomaticMobileViews | NRFeatureFlag_AutomaticSwiftUIViews` explicitly rather
  than relying on defaults, so the corpus states what it is measuring.

### 5.4 `SwiftUIScreenOutcome`

Four distinct situations currently collapse into one `nil`. A denominator without a cause is not
actionable, so the resolver gains:

```swift
internal enum SwiftUIScreenOutcome {
    case notNavigationParticipating
    case noRootView
    case suppressedByModifier
    case unresolved                                  // root found, nothing named it
    case resolved(SwiftUIScreenIdentity, via: Path)

    internal enum Path {
        case storedType      // the app's own view struct, found in the content chain
        case lazyGeneric     // read out of a lazy wrapper's generic parameters
        case routeEnum       // the route or tab-tag fallback
    }
}
```

`automaticScreen(for:)` returns `SwiftUIScreenOutcome?`, where `nil` means the controller is not a
SwiftUI hosting controller at all. That case is deliberately outside the enum: a plain UIKit
controller is not a failed resolution and must never enter any denominator. Every case *inside*
the enum describes a host. The existing `NRMASwiftUIScreenResolver.screen(for:)`
facade maps `.resolved` to an identity and every other case to `nil`.

**This is a pure-addition refactor with no semantic change.** The 36 existing resolver tests
staying green is the proof, and it is a load-bearing property: a measurement apparatus that
alters the thing it measures is worthless.

### 5.5 Instrumentation counters

Each walk already maintains a local `visited` count. The outcome additionally carries
nodes-visited per walk stage and a resolve duration.

These are computed **unconditionally, not under `#if DEBUG`**. Making the resolver's internals
differ by build configuration would mean measuring code that is not the code that ships.

This is what validates the three budgets. A host that resolves only because it came in under
`maxNodes = 256` is a latent failure in a larger app, and today nothing would tell us.

### 5.6 The log line

One line per host, key=value for trivial parsing:

```
[MobileViews][SwiftUI] host=NavigationStackHostingController nav=1 outcome=resolved
    via=routeEnum name=Route.listing class=App.Route.listing us=412
    rootNodes=12/128 contentNodes=41/256 routeNodes=173/512
```

Each stage reports visited-over-budget, so a run that is approaching a ceiling is visible without
having to correlate anything. Stages that did not run report `0`.

Gated `#if DEBUG` plus `NRLOG_AGENT_VERBOSE`, so a customer release carries none of it and it is
silent unless verbose logging is on.

Emitted **only from the appear path, once per controller** — a `#if DEBUG` associated-object flag
set after the first line is written suppresses the rest. `NRMA_SwiftUIScreenForController`
is also called on disappear and on every background flush, and because misses are not cached
(`NRMAMobileViewTracker.m:322-333`) an unresolved host re-walks on every one of those calls.
Logging naively would multiply-count precisely the hosts being counted. A side benefit: the log
makes that repeated re-walk visible and quantifies its cost.

### 5.7 Readout

`NRLogTargetFile` writes JSON-format messages to the path from `+[NRLogger logFilePath]`. After
a walk the file is pulled with `simctl get_app_container <bundle-id> data`. Parsing a JSON file
is immune to console truncation and reordering, and the file diffs cleanly between runs.

No collector is required: `[[NRMAMobileViewTracker sharedInstance] start]` happens in
`-[NewRelicAgentInternal initialize]` (`NewRelicAgentInternal.m:343`) as part of instrumentation
setup, independent of any collector handshake. See open question O1.

### 5.8 `corpus_walk.py`

Deterministic bounded breadth-first exploration over `pepper-ctl --json`:

1. `snapshot` the screen; sort interactive elements by (y, x) rather than traversal order, so
   ordering is stable between runs.
2. Fingerprint the screen from its sorted element labels; keep a visited set so loops terminate.
3. Tap at most N elements per screen (default 4) to depth D (default 3). After each, `back`, then
   re-fingerprint to confirm the return. If it fails, `back` up to k times, then relaunch.
4. Enforce a step budget and a per-app wall-clock timeout.
5. **Default-deny destructive labels** — `Delete`, `Remove`, `Sign out`, `Log out`, `Buy`,
   `Subscribe`, `Block`, `Report` — extended per app. These are real apps that may reach a real
   network.
6. Write a walk trace (steps, fingerprints, taps) so a run is auditable and a specific number
   can be reproduced exactly.

`apps/<App>/walk.yml` carries only what the generic pass cannot infer: launch preconditions
(dismiss onboarding, tap "Skip"), extra seed elements, additional avoid patterns, budget
overrides.

**Repeatability limit, stated plainly.** Pinning the source freezes the UI but not the content: an
app fetching live data yields different rows and therefore different fingerprints run to run.
Mitigated by preferring apps that run offline or on bundled data (a soft selection criterion),
by the unresolved *rate* being robust to minor path variation even when the exact path is not,
and by the walk trace for exact reproduction.

### 5.9 `corpus_report.py`

Parses the JSON logs and writes `Test Harness/Corpus/REPORT.md` with per-app and rollup rows:

- hosts seen; navigation-participating
- resolved, broken down by `storedType` / `lazyGeneric` / `routeEnum`
- `suppressedByModifier`, `noRootView`, `unresolved`
- p50 / p95 resolve duration
- peak nodes visited against each budget
- the distinct resolved names, for human plausibility review

`--check` fails when the unresolved rate regresses against the committed baseline. Committing the
report is what makes a resolver change show up as a numeric diff inside a PR.

## 6. The corpus

### Admission gates

Every app must clear all of:

1. Permissive license (MIT / Apache-2.0 / BSD), `LICENSE` preserved, attribution recorded.
2. SwiftUI-based.
3. Plain `.xcodeproj` plus SPM dependencies. A CocoaPods app needs its own generated
   `.xcworkspace` and cannot nest inside `Agent.xcworkspace`.
4. Builds for the simulator on current Xcode.
5. Fills an idiom slot nothing else covers.
6. Soft preference: runs offline or on bundled data.

### Idiom slots

| Slot | Idiom | Why it is in the corpus |
|---|---|---|
| 1 | `NavigationStack` + `navigationDestination(for:)` | `ParameterizedLazyView` generic path and the route-enum fallback |
| 2 | TabView-rooted | `TabHostingController` — no generic parameter at all; the shape that produced `__C.CoreSystem.CoreSystem` |
| 3 | `NavigationSplitView` / multi-column | `StyleContextSplitViewNavigationController`, presently only an exclusion-list entry and essentially untested |
| 4 | Modal-heavy (sheet / cover / popover) | `PresentationHostingController<AnyView>`, plus open question O3 |
| 5 | Third-party router or TCA-style navigation | screens live in a reducer/state tree rather than the view chain — where the mirror walk is least likely to see anything |
| 6 | UIKit app hosting SwiftUI | probably the most common real customer shape; where `isNavigationParticipating` needs checking |
| 7 (opportunistic) | `WindowGroup { ContentView() }`, no nav container | would settle open question O4 |

**Filling the slots is a research step, not part of this design.** Naming apps here would mean
guessing at licenses. That step's deliverable is `corpus.yml` recording, per slot, the candidate,
its verified license, confirmation of gate 3, and a passing simulator build.

## 7. Metric definitions

- **Candidate host**: a controller for which `isSwiftUIHost` is true and
  `isNavigationParticipating` is true.
- **Miss rate** (the headline number) = `(unresolved + noRootView) / candidate hosts`. Both are
  screens a customer would not see, so both belong in the number that decides whether this
  feature works.
- The two are then **reported separately for diagnosis**, because they mean different things.
  `unresolved` means the walk ran and nothing in the graph named the screen — expected for some
  idioms. `noRootView` means reflection could not find a root view at all, which indicates a
  storage-layout change and is the more alarming of the two.
- `suppressedByModifier` is excluded from the numerator: it is correct behaviour, not a miss.
  `notNavigationParticipating` is excluded from the denominator: it is not a candidate.
- Counts are per host **instance**, deduped by controller identity, so the uncached-miss re-walk
  does not inflate anything.

## 8. Testing strategy

The corpus is measurement apparatus, so most of it is verified by use rather than by unit tests.
What does get tested:

- `SwiftUIScreenOutcome` refactor: the existing 36 resolver tests must pass unchanged. New tests
  assert the outcome case for each situation those tests already cover, so every case is pinned.
- Counter plumbing: a test asserting nodes-visited is non-zero and below budget for a known
  fixture, and that a deliberately deep fixture reports hitting the ceiling.
- `corpus_report.py`: unit tests over a checked-in sample log, including the dedupe rule and the
  rate arithmetic in §7.
- `corpus_walk.py`: unit tests over recorded `pepper-ctl --json` snapshots for fingerprinting,
  element ordering, the avoid-list, and loop termination. The crawler is not tested against a
  live app in CI.

## 9. Sequencing

One app end to end before vendoring the rest. Every unknown lives in the first app — whether the
`+load` bootstrap starts cleanly, whether a failed connect matters, whether pepper coexists with
the agent in the same process, whether the crawler copes with a real app. Discovering those six
times over is the expensive way.

1. `SwiftUIScreenOutcome` refactor plus counters, existing tests green.
2. Log line and `NRCorpusBootstrap.m`, proven against `HomeSearch` — a known app where the
   expected outcomes are already understood, so a wrong log line is obvious.
3. Vendor app #1 (slot 1), `integrate_agent.rb`, build and launch.
4. `corpus_walk.py` against app #1.
5. `corpus_report.py`, first `REPORT.md`.
6. Vendor slots 2-6, refresh the report.
7. Write up findings; each defect found becomes its own issue.

## 10. Risks and open questions

- **O1.** Does a failing collector connect back the agent off, disable instrumentation, or make
  the log unusably noisy? If so, point `NRCorpusBootstrap` at a local stub on `localhost:8080`
  (the agent only disables TLS for that literal address). The stub would also cross-check that
  resolved names reach the wire as `MobileView` events.
- **O2.** Does pepper's injected dylib coexist with the agent in the same process? Expected yes;
  unverified.
- **O3.** Does SwiftUI ever reuse a `PresentationHostingController` or `TabHostingController` for
  different content? If so the positive result cached in `kNRSwiftUIScreenKey` goes stale and the
  second sheet reports the first one's name. The corpus may surface this; slot 4 is where to look.
- **O4.** Does a host that is `window.rootViewController` — no parent, no presenter — fail
  `isNavigationParticipating` and silently drop the app's first screen? Slot 7.
- **O5.** Vendored apps are snapshots; the corpus ages. Mitigated by `PROVENANCE.md` SHAs and
  accepted as a cost of §4.2.
- **O6.** Idiom slots can only enumerate idioms we know about. Partly mitigated by the apps being
  foreign, so their accidental structure is still outside our assumptions.
- **R1.** Legal sign-off on vendoring third-party source into a public New Relic repo is a
  blocking prerequisite for committing app #1.
