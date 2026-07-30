# NewRelic.h/.m → Swift pilot conversion

## Context

Long-term goal: convert the iOS agent's implementation to Swift, both so the team can
write Swift going forward and so customers browsing the open-source repo see/use a Swift
implementation directly (not just Swift-consumable ObjC).

That goal spans the whole `Agent/` tree — 391 ObjC files (`.m`/`.mm`/`.h`, ~36.5k lines)
across 14 subsystems (`Harvester` 37 files, `Measurements` 28, `CrashHandler` 21,
`Instrumentation` 21, `Analytics` 19, `ActivityTracing` 9, `Public` 15, etc.) vs. 74 Swift
files (~11k lines) — but 69 of those 74 Swift files are entirely `Agent/SessionReplay/`,
a subsystem written in Swift from scratch. That's a data point for "greenfield Swift
subsystem," not "migrate existing ObjC," which is a different and generally harder problem:
behavior-preservation risk, existing ObjC-shaped test suites, and — as this investigation
found — an undocumented cross-platform API contract.

Rather than design the full multi-subsystem migration up front, this spec scopes a single
**pilot**: convert `Agent/Public/NewRelic.h`/`.m` (the actual customer-facing API class) to
Swift. It's chosen as the pilot specifically because it carries the hardest version of the
problem in the smallest unit: it's the file every consumer (direct ObjC customers, direct
Swift customers, and six hybrid-framework SDKs) depends on, so it's the best place to learn
"what does a real conversion actually cost" before deciding how to sequence the other 13
subsystems.

### Hybrid SDK dependency audit

New Relic ships six separate SDKs that wrap this agent for other platforms, each with its
own native iOS bridge calling directly into the `NewRelic` ObjC class:

| Agent | Language | Bridge file | How it calls the hidden `setPlatformVersion:` selector |
|---|---|---|---|
| React Native | ObjC++ | `ios/bridge/NRMModularAgent.mm` | compile-time `@interface NewRelic (Private)` category |
| Cordova | ObjC | `src/ios/NewRelicCordovaPlugin.m` | compile-time `@interface NewRelic (Private)` category |
| Unity | ObjC | `com.newrelic.agent/Scripts/Native/NewRelicUnityPlugin.m` | compile-time `@interface NewRelic (Development)` category |
| Flutter | Swift | `ios/newrelic_mobile/Sources/newrelic_mobile/NewrelicMobilePlugin.swift` | runtime `NSSelectorFromString` + `.perform(with:)` |
| Capacitor | Swift | `ios/Plugin/NewRelicCapacitorPluginPlugin.swift` | runtime `NSSelectorFromString` + `.perform(with:)` |
| MAUI | C# binding (`ApiDefinition.cs`) | `NewRelic.MAUI.iOS.Binding/` | declared directly in the `[Export]` interface (btouch needs no category) |

All six depend on `setPlatformVersion:`, which is real (implemented in `NewRelic.m` marked
`//hidden API`, forwarding to `NRMAAgentConfiguration setPlatformVersion:`) but **absent
from the public `NewRelic.h`** — nobody documented this as a contract, but every hybrid SDK
treats it as one. The ObjC consumers (RN, Cordova, Unity) get compile-time protection if
this selector ever moved or was renamed; the Swift consumers (Flutter, Capacitor) get none
— a missing/renamed selector there compiles fine and only surfaces as
`unrecognized selector sent to class` at runtime, in a real user's app, for an SDK whose job
is reporting exactly that kind of crash.

A second selector, `isAgentStarted:`, was suspected (declared in RN's private category) but
turned out to be dead code — RN's own `isAgentStarted` JS-bridge method never actually calls
it; it just resolves `true` unconditionally. No implementation of it exists anywhere in this
repo. It is **not** a real dependency and does not need preserving.

MAUI's binding also confirms the shipped `.xcframework` already contains `NewRelic-Swift.h`
and a `.swiftmodule` alongside the ObjC headers — the binary distributed to all six
ecosystems today is already a mixed ObjC/Swift artifact, and nothing about that has broken
any of them.

## Scope

Convert `Agent/Public/NewRelic.h` (925 lines) + `Agent/Public/NewRelic.m` (922 lines) to a
single `Agent/Public/NewRelic.swift`, preserving the existing ObjC-compatible public
contract exactly. This is a same-behavior, different-implementation-language change —
no new Swift-idiomatic ergonomics (enums, `async`/`throws`, real optionals-as-API) yet.
That's deliberately deferred: this pilot answers "what does conversion cost," not "what
should the API look like once we're free to redesign it."

## Out of scope

- The ~9 header-only files in `Agent/Public/` (`NRConstants.h`, `NewRelicFeatureFlags.h`,
  `NRLogger.h`, `NRTimer.h`, `NewRelicCustomInteractionInterface.h`, `NRGCDOverride.h`,
  `NRCustomMetrics.h`, `NRMAAgentVersion.h`, `NRURLSessionTaskDelegateBase.h`,
  `NRWKNavigationDelegateBase.h`, `Agent.h`). These are `NS_ENUM`/`NS_OPTIONS`/protocol
  declarations with no `.m` — they already bridge into Swift automatically and stay ObjC.
- `NRMATaskQueue.h`/`.m` and `NRMAExceptionHandlerStartupManager.h`/`.m`. These happen to
  live in the `Public/` folder but are internal implementation details with no external
  callers and no hybrid-SDK dependency — converting them wouldn't teach us anything about
  the hard problem this pilot exists to de-risk.
- Any decision about the other 13 subsystems or an overall migration roadmap — deferred
  until this pilot's outcome is known.
- New Swift-idiomatic public API surface (see Scope above).

## Approaches considered

- **(A) Big-bang single-file rewrite — chosen.** Rewrite `NewRelic.h`/`.m` as one
  `NewRelic.swift` in one pass, verify via the existing test suite plus a selector audit.
  Smallest unit here (~1,850 lines, one file pair), so the added review/rollback risk of a
  single large diff is acceptable, and doing it directly gives the most honest signal on
  true conversion cost — which is the point of the pilot.
- **(B) Incremental, method-group by method-group.** Keep the ObjC shell in place, move
  logic to an internal Swift "core" a section at a time, flip the type declaration itself
  last. Safer for something big, but the added design overhead (temporary two-phase state)
  isn't worth it yet for one file. Revisit for the larger subsystems (`Harvester` 37 files,
  `Measurements` 28) if/when this pilot leads to a full roadmap.
- **(C) Parallel/differential build-and-verify.** Write the Swift version untouched
  alongside the old ObjC one, run both against the same inputs, cut over atomically once
  proven equivalent. Most rigorous, but building an actual differential harness is heavy
  machinery for a pilot whose job is mainly to surface friction. The six hybrid SDKs' own
  test suites (see Testing below) already provide most of this rigor without extra harness
  work.

## Design

### Architecture / file changes

- `Agent/Public/NewRelic.m` — deleted.
- `Agent/Public/NewRelic.h` — collapsed to a thin stub: `#import <NewRelic/NewRelic-Swift.h>`
  plus its existing re-exports of `NRConstants.h`, `NewRelicFeatureFlags.h`, etc., unchanged.
  This keeps `#import <NewRelic/NewRelic.h>` compiling identically for every ObjC consumer.
- New `Agent/Public/NewRelic.swift` — `@objcMembers public class NewRelic: NSObject`, one
  Swift method per existing ObjC method, each with an explicit `@objc(exactSelectorName:)`
  pin rather than relying on Swift's auto-derived selector naming.
- Enable library evolution mode (`BUILD_LIBRARY_FOR_DISTRIBUTION`) on the framework target
  for ABI stability across Xcode/Swift versions in XCFramework distribution — consistent
  with the `.swiftmodule` already present in the shipped binary today.

### Compatibility contract — the selector audit

Before writing `NewRelic.swift`: produce a complete inventory of every selector currently
implemented in `NewRelic.m`, public *and* hidden. `setPlatformVersion:` was found by chasing
two specific names a category declaration happened to expose — there may be others. Diff
the full set of `+ (...)` implementations in `NewRelic.m` against every `[NewRelic ...]`/
`NewRelic.`-style call across all six hybrid repos (not just the two already known), so
nothing currently in use is missed. Every selector on the combined list gets an explicit
`@objc(...)` pin in the rewrite, matching exactly.

### Migration mechanics

- No default-parameter flattening needed — ObjC has no default args, so every existing
  method already has fully-specified parameters; nothing to split into overloads.
- Preserve nullability semantics 1:1 (`__nullable` → `Optional`, `_Nonnull` → non-optional).
- `+ (void) methodName` → `public static func methodName` — `NewRelic` is a stateless
  utility type, not designed for subclassing, so `static func` is sufficient (no need for
  overridable `class func` dispatch).

### Testing & verification

- Existing `Tests/Unit-Tests/NewRelicAgentTests/API-Tests/` suite (`NewRelicTests.m` — 620
  lines, ~20+ `XCTestCase` methods covering `crashNow`, `enableCrashReporting`,
  `setPlatform`, network notices, interactions, metrics, attributes, user ID, etc. —
  `NewRelicAPITest.m` and siblings, ~1,482 lines total) must pass unchanged against the
  Swift rewrite.
- Build each of the six hybrid repos against a local/pre-release build of the new binary and
  run their own test/CI suites, with specific attention to Flutter's and Capacitor's
  `NSSelectorFromString("setPlatformVersion:")` call — the one spot that fails at runtime,
  not compile time, if the rewrite gets a selector wrong.
- Smoke-test via `Test Harness/NRTestApp` for a real end-to-end sanity check (startup, crash
  reporting, logging) beyond what unit tests cover.

### Success criteria

- Every selector currently in `NewRelic.m` exists in the new binary with an identical
  signature (verified via a saved selector manifest, diffed before/after).
- Existing unit test suite passes with zero modifications.
- All six hybrid SDKs build and pass their own tests against the new binary with zero
  source changes on their side.
- `#import <NewRelic/NewRelic.h>` and `import NewRelic` both continue to work unchanged.

## Not doing

- Not redesigning the public API surface to be more Swift-idiomatic (real enums, `async`/
  `throws`, etc.) — same behavior, different implementation language, full stop.
- Not converting the header-only declaration files or `NRMATaskQueue`/
  `NRMAExceptionHandlerStartupManager` in this pass.
- Not deciding the sequencing or approach for the other 13 subsystems yet — that's a
  follow-on spec once this pilot's outcome (actual cost/friction) is known.
- Not building a differential/parallel-verification harness (approach C) — the existing
  unit tests plus the six hybrid repos' own test suites are treated as sufficient rigor for
  a pilot of this size.
