# Session-Start Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop two threads from running session start concurrently in the iOS agent, without adding any lock edge that would deadlock against the existing `BGFG → harvester` ordering.

**Architecture:** A single file-static atomic `bool` in `Agent/General/NewRelicAgentInternal.m` acts as a non-blocking gate. Callers test-and-set it: a winner runs session start, a loser returns immediately. Because nothing ever *waits* on the gate, the lock graph is unchanged and no inversion is possible. `-sessionStartInitialization` splits into an ungated core (`-performSessionStartInitialization`) plus a gated wrapper, so each of the four call sites claims the gate exactly once and the gate needs no owner tracking or depth count.

**Tech Stack:** Objective-C (`@try`/`@finally`, `stdatomic.h`), XCTest, OCMock, `xcodebuild`, the `xcodeproj` Ruby gem.

**Spec:** `docs/superpowers/specs/2026-08-10-session-start-gate-design.md`

## Global Constraints

- **Xcode 26.3 (release)**, which `xcode-select` already points at. `Agent_Tests` hits an OCMock link failure under the Xcode 27 beta — do not switch to `Xcode-beta.app`.
- There is **no `Agent_Tests` scheme**. `Agent_Tests` is the testable of the **`Agent-iOS`** scheme, whose `TestAction` also carries a `SkippedTests` entry, so always select tests with `-only-testing:`.
- Simulator for every test run: **iOS 26.3, iPhone 17 Pro, id `15135556-1BB1-445F-8AB2-E080E1F8B4BE`**.
- **`-only-testing:` takes class names, not filenames**, and a mismatch is silent: `xcodebuild` reports `Executed 0 tests` and `** TEST SUCCEEDED **`. Always confirm the executed-test count is what you expect before believing a pass. The 4-hour regression class is `NRMAHarvestControllerTest`, in a file named `NRHarvestControllerTest.m`.
- The canonical test command, used verbatim in every task:

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

- `DISABLE_NRMA_EXCEPTION_WRAPPER` is **never defined** in this project (only `DISABLE_NR_EXCEPTION_WRAPPER`, in three build configs), so plain unguarded `@try`/`@finally` always compiles in `NewRelicAgentInternal.m`. Do **not** wrap the new `@try`/`@finally` blocks in `#ifndef`.
- All new code goes in `Agent/General/NewRelicAgentInternal.m`. **No header changes.** `-sessionStartInitialization` keeps its `void` signature so `NewRelicAgentInternal.h` and existing callers are untouched.
- Never reformat or re-indent surrounding code. Every edit below is scoped to the exact lines shown.
- Commit message convention in this repo is a Jira key then a summary, e.g. `NR-586741 setUserId needs to stay synchronous (#820)`. The messages below omit a key; prefix each with the real ticket key if one exists for this work.
- Line numbers below refer to `Agent/General/NewRelicAgentInternal.m` **as of commit `3f12b967`** and will drift as you edit. Always locate code by the quoted text, never by line number alone.

---

### Task 1: The gate primitives, and a test target to prove them

Adds the two atomics and the two methods that manipulate them, plus the new test file wired into the project. Nothing calls the gate yet, so behaviour is unchanged — this task only has to compile and prove the primitive works.

**Files:**
- Modify: `Agent/General/NewRelicAgentInternal.m` (add `#include <stdatomic.h>`; add gate block after the `kNRMA_APPLICATION_WILL_TERMINATE` definition)
- Create: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`
- Modify: `Agent.xcodeproj/project.pbxproj` (via the Ruby script in Step 2 — do not hand-edit)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `static _Atomic bool __NRMASessionStartInFlight` — file-static in `NewRelicAgentInternal.m`.
  - `static _Atomic bool __NRMASessionStartDeferred` — file-static in `NewRelicAgentInternal.m`.
  - `- (BOOL) tryBeginSessionStart` — returns `YES` if the caller now owns the gate.
  - `- (void) endSessionStartDrainingDeferred` — releases the gate and re-dispatches a deferred session start.
  - Test file's category `NewRelicAgentInternal (SessionStartGateTests)`, which every later task's tests reuse.

- [ ] **Step 1: Create the test file**

Create `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`:

```objc
//
//  NRMASessionStartGateTests.m
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "NRAgentTestBase.h"
#import "NewRelicAgentInternal.h"
#import "NRMAAnalytics.h"
#import <NewRelic/NewRelic-Swift.h>
#include <stdatomic.h>

// The session-start gate and the funnel it guards are private to
// NewRelicAgentInternal.m. Declaring them here makes them visible to these tests and
// gives OCMock the method signatures it needs to stub them. Objective-C dispatches
// dynamically, so no production header change is required.
@interface NewRelicAgentInternal (SessionStartGateTests)
- (BOOL) tryBeginSessionStart;
- (void) endSessionStartDrainingDeferred;
- (void) performSessionStartInitialization;
// Defined at NewRelicAgentInternal.m:893 but declared in neither the header nor the class
// extension, so Task 3's tests cannot see it without this.
- (void) handle4HourSessionRestart;
@end

@interface NRMASessionStartGateTests : NRMAAgentTestBase
@property (nonatomic, strong) NewRelicAgentInternal* agent;
@property (nonatomic, strong) id sharedInstanceMock;
@end

@implementation NRMASessionStartGateTests

- (void) setUp {
    [super setUp];

    // There is no custom -init on NewRelicAgentInternal, so this is NSObject's and runs
    // none of the agent start path -- exactly what we want. Stubbing +sharedInstance
    // follows Analytics-Tests/PersistentStoreTests.m:86-89.
    self.sharedInstanceMock = [OCMockObject mockForClass:[NewRelicAgentInternal class]];
    self.agent = [[NewRelicAgentInternal alloc] init];
    self.agent.analyticsController = [[NRMAAnalytics alloc] initWithSessionStartTimeMS:0.0];
    [[[[self.sharedInstanceMock stub] classMethod] andReturn:self.agent] sharedInstance];
}

- (void) tearDown {
    // The gate is a file static and survives between tests. Release it unconditionally
    // so one failing test cannot strand it and cascade into every later test.
    [self.agent endSessionStartDrainingDeferred];

    [self.sharedInstanceMock stopMocking];
    self.sharedInstanceMock = nil;
    self.agent = nil;

    [super tearDown];
}

#pragma mark - Gate primitive

- (void) test_gate_secondClaimFailsUntilReleased {
    XCTAssertTrue([self.agent tryBeginSessionStart], @"first claim should win the gate");
    XCTAssertFalse([self.agent tryBeginSessionStart], @"second claim should lose while held");

    [self.agent endSessionStartDrainingDeferred];

    XCTAssertTrue([self.agent tryBeginSessionStart], @"claim should win again after release");
    [self.agent endSessionStartDrainingDeferred];
}

- (void) test_gate_onlyOneClaimSucceedsUnderContention {
    const NSUInteger threadCount = 32;

    // Heap-allocated so the blocks below capture a pointer by value. A plain local would
    // be const-copied into each block, and __block plus _Atomic is needlessly subtle.
    _Atomic int32_t* winners = calloc(1, sizeof(_Atomic int32_t));

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger i = 0; i < threadCount; i++) {
        dispatch_group_async(group, queue, ^{
            if ([self.agent tryBeginSessionStart]) {
                atomic_fetch_add_explicit(winners, 1, memory_order_acq_rel);
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    XCTAssertEqual(atomic_load_explicit(winners, memory_order_acquire), 1,
                   @"exactly one of %lu concurrent claims may win the gate",
                   (unsigned long)threadCount);

    free(winners);
    [self.agent endSessionStartDrainingDeferred];
}

@end
```

Two notes on this fixture, both of which apply to every later task's tests:

- The tests use OCMock to stub `-performSessionStartInitialization` rather than the
  `appSessionStartDate` observable the spec proposed. Stubbing tests the *policy* — did
  the gate let session start run — without depending on the real funnel body (which stops
  and rebuilds the harvest pipeline) surviving on a bare, unconfigured instance. No
  existing test exercises that body on a bare instance, so this avoids being the first.
- When `-sessionStartInitialization` yields it also calls `+[NRMAHarvestController start]`
  as a safety net. In these tests that is a no-op: `+start` dispatches to its own queue
  and returns immediately when the controller is nil.

- [ ] **Step 2: Add the test file to the same targets as its sibling**

Run this from the repo root. It mirrors `NRHarvestControllerTest.m`'s target membership rather than guessing, and prints what it did so you can verify.

```bash
ruby -e '
require "xcodeproj"

project      = Xcodeproj::Project.open("Agent.xcodeproj")
sibling_name = "NRHarvestControllerTest.m"
new_name     = "NRMASessionStartGateTests.m"

sibling_ref = project.files.find { |f| f.path == sibling_name }
raise "sibling #{sibling_name} not found" if sibling_ref.nil?

if project.files.any? { |f| f.path == new_name }
  puts "#{new_name} is already in the project; nothing to do"
  exit 0
end

group   = sibling_ref.parent
new_ref = group.new_file(new_name)

targets = project.targets.select do |t|
  t.source_build_phase.files.any? { |bf| bf.file_ref == sibling_ref }
end
raise "no targets build #{sibling_name}" if targets.empty?
targets.each { |t| t.add_file_references([new_ref]) }

project.save
puts "resolved path: #{new_ref.real_path}"
puts "added #{new_name} to: #{targets.map(&:name).join(", ")}"
'
```

Expected output: a `resolved path` ending in `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`, and `added NRMASessionStartGateTests.m to: Agent_Tests, Agent_tvos_Tests, Agent-watchos-Tests`.

If `resolved path` does not match the file you created in Step 1, `git checkout Agent.xcodeproj/project.pbxproj` and rerun with `group.new_file(File.expand_path("Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/#{new_name}"))` instead.

- [ ] **Step 3: Run the tests to verify they fail**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: both tests FAIL at runtime with `-[NewRelicAgentInternal tryBeginSessionStart]: unrecognized selector sent to instance`. It compiles and links cleanly — the category declares the selector, and Objective-C methods are dispatched dynamically rather than resolved as link symbols — so a runtime failure is the correct signal that the gate does not exist yet. If you instead get a *compile* error, the test file is not in the `Agent_Tests` target and Step 2 did not take effect.

- [ ] **Step 4: Add the stdatomic include**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
#import <mach/mach_time.h>
```

Replace with:

```objc
#import <mach/mach_time.h>
#include <stdatomic.h>
```

- [ ] **Step 5: Add the gate block**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
static const NSString *kNRMA_BGFG_MUTEX = @"com.newrelic.bgfg.mutex";
static const NSString *kNRMA_APPLICATION_WILL_TERMINATE =
@"com.newrelic.appWillTerm";
```

Replace with:

```objc
static const NSString *kNRMA_BGFG_MUTEX = @"com.newrelic.bgfg.mutex";
static const NSString *kNRMA_APPLICATION_WILL_TERMINATE =
@"com.newrelic.appWillTerm";

#pragma mark - Session start gate

// Starting a session tears down and rebuilds the harvest pipeline
// (-performSessionStartInitialization) and reassigns the session id (-onSessionStart).
// Two threads doing that at once corrupt each other, and four call sites reach it from
// three different lock contexts:
//
//   -init                            no locks held
//   -applicationWillEnterForeground  kNRMA_BGFG_MUTEX
//   -startNewSessionForUserId        kNRMA_BGFG_MUTEX
//   -handle4HourSessionRestart       @synchronized(harvester), from -[NRMAHarvester execute]
//
// A mutex cannot serialize those. The foreground and background harvests take
// kNRMA_BGFG_MUTEX and then call -[NRMAHarvester execute], which takes
// @synchronized(self) -- ordering BGFG before the harvester lock. The 4-hour restart
// arrives already holding the harvester lock, because NRMAHarvester.mm calls
// -checkAndHandleSessionTimeout from inside -execute, so any mutex it takes here is
// ordered after it. One mutex shared by both orderings is a lock-order inversion: it
// would trade a fixed crash for a hang.
//
// So this gate never waits. It is a test-and-set: a thread either claims it and runs, or
// loses and returns immediately. Nothing blocks on anything, so no edge is added to the
// lock graph and the inversion cannot arise.
static _Atomic bool __NRMASessionStartInFlight = false;

// Set by a caller that lost the gate but whose session start still needs to happen.
// Whoever releases the gate re-dispatches it.
static _Atomic bool __NRMASessionStartDeferred = false;

// YES means the caller now owns the gate and must release it with
// -endSessionStartDrainingDeferred.
- (BOOL) tryBeginSessionStart {
    return !atomic_exchange_explicit(&__NRMASessionStartInFlight, true, memory_order_acq_rel);
}

// Releases the gate, then re-runs any session start that was deferred while we held it.
// The re-run is dispatched asynchronously on purpose: this can be called from the harvest
// thread while it still holds @synchronized(harvester), and running session start there
// would nest a second harvest inside the first.
- (void) endSessionStartDrainingDeferred {
    atomic_store_explicit(&__NRMASessionStartInFlight, false, memory_order_release);

    if (!atomic_exchange_explicit(&__NRMASessionStartDeferred, false, memory_order_acq_rel)) {
        return;
    }

    NRLOG_AGENT_VERBOSE(@"Session start: running deferred session start");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_isShutdown) {
            return;
        }
        [self sessionStartInitialization];
    });
}
```

- [ ] **Step 6: Run the tests to verify they pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`, 2 tests executed.

- [ ] **Step 7: Commit**

```bash
git add Agent/General/NewRelicAgentInternal.m \
        Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m \
        Agent.xcodeproj/project.pbxproj
git commit -m "Add a non-blocking session-start gate

A test-and-set atomic, not a mutex: the 4-hour restart reaches session start
from inside -[NRMAHarvester execute]'s @synchronized(self), while the
foreground and background harvests take kNRMA_BGFG_MUTEX before that same
lock, so any mutex ordered after the harvester here would invert against
them. Nothing waits on this gate, so the lock graph is unchanged.

No caller uses it yet."
```

---

### Task 2: Split the funnel and make the foreground path yield

Splits `-sessionStartInitialization` into an ungated core plus a gated wrapper. This is what makes `-applicationWillEnterForeground` yield — that method itself is **not edited**, because the gate lives inside the funnel it already calls, so it keeps setting `didFireEnterForeground`, doing the Return Harvest, clearing `didFireEnterBackground`, and recording the AppLaunch action whether or not the session restarts.

**Files:**
- Modify: `Agent/General/NewRelicAgentInternal.m` (`-sessionStartInitialization`)
- Modify: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`

**Interfaces:**
- Consumes: `-tryBeginSessionStart`, `-endSessionStartDrainingDeferred`, `__NRMASessionStartDeferred` (Task 1).
- Produces: `- (void) performSessionStartInitialization` — the ungated session start. **Callers must own the gate.** Tasks 3 and 4 call this instead of `-sessionStartInitialization`.

- [ ] **Step 1: Write the failing tests**

Append to `NRMASessionStartGateTests.m`, immediately before the final `@end`:

```objc
#pragma mark - Funnel

- (void) test_sessionStartInitialization_yieldsWhenGateHeld {
    id agentMock = [OCMockObject partialMockForObject:self.agent];
    // The real body tears down and rebuilds the whole harvest pipeline. We only care
    // whether the gate let it run, so stub it out and assert on the call.
    [[agentMock reject] performSessionStartInitialization];

    XCTAssertTrue([self.agent tryBeginSessionStart]);
    [self.agent sessionStartInitialization];

    [agentMock verify];
    [agentMock stopMocking];
    [self.agent endSessionStartDrainingDeferred];
}

- (void) test_deferredSessionStart_runsOnRelease {
    id agentMock = [OCMockObject partialMockForObject:self.agent];

    XCTestExpectation* ranDeferred =
        [self expectationWithDescription:@"deferred session start runs after release"];
    [[[agentMock stub] andDo:^(NSInvocation* invocation) {
        [ranDeferred fulfill];
    }] performSessionStartInitialization];

    XCTAssertTrue([self.agent tryBeginSessionStart]);
    [self.agent sessionStartInitialization];   // loses, registers the deferral
    [self.agent endSessionStartDrainingDeferred];   // releases, drains, re-dispatches

    [self waitForExpectations:@[ranDeferred] timeout:5.0];

    [agentMock stopMocking];
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: both new tests FAIL. `test_sessionStartInitialization_yieldsWhenGateHeld` fails because `-sessionStartInitialization` still ignores the gate and does the work inline (so the rejected `performSessionStartInitialization` is never called but the real teardown runs — OCMock will report the unimplemented selector or the test will hang on the real body). `test_deferredSessionStart_runsOnRelease` fails on the 5s expectation timeout.

- [ ] **Step 3: Split the funnel**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
- (void) sessionStartInitialization {

    [self makeSampleSeeds];
```

Replace with:

```objc
- (void) sessionStartInitialization {
    if (![self tryBeginSessionStart]) {
        NRLOG_AGENT_VERBOSE(@"Session start already in flight; deferring this one.");
        atomic_store_explicit(&__NRMASessionStartDeferred, true, memory_order_release);

        // Belt and braces for the case this gate exists to protect. On a background agent
        // start -initialize skips +[NRMAHarvestController start], so this path is what
        // starts the harvester; if the deferred re-run were ever lost, the session would
        // report nothing at all. +start is safe to call again -- the timer no-ops when
        // already running and the harvester only executes from UNINITIALIZED/DISCONNECTED.
        [NRMAHarvestController start];
        return;
    }

    @try {
        [self performSessionStartInitialization];
    } @finally {
        [self endSessionStartDrainingDeferred];
    }
}

// The session start itself. Callers must own the session-start gate.
- (void) performSessionStartInitialization {

    [self makeSampleSeeds];
```

The remainder of the original method body (from `self.appSessionStartDate = [NSDate date];` through `[self onSessionStart];` and its closing brace) is now the body of `-performSessionStartInitialization` and needs no edit.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`, 4 tests executed.

- [ ] **Step 5: Commit**

```bash
git add Agent/General/NewRelicAgentInternal.m \
        Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m
git commit -m "Gate sessionStartInitialization and defer losers

Splits the funnel into an ungated -performSessionStartInitialization plus a
gated wrapper, so each call site claims the gate exactly once and the gate
needs no owner tracking. A loser registers a deferral that whoever releases
the gate re-dispatches, so the foreground handler's session start is
postponed rather than dropped -- which matters because on a background agent
start -initialize skips +[NRMAHarvestController start], making that handler
the thing that starts the harvester.

-applicationWillEnterForeground is deliberately unchanged: the gate is inside
the funnel it already calls, so it still records the AppLaunch action and
does the Return Harvest either way."
```

---

### Task 3: The 4-hour restart claims the gate, and the premature clock poke goes

The restart is the one caller that can simply give up, because `-checkAndHandleSessionTimeout` runs again on the next harvest tick. Claiming the gate also becomes a *correct* recursion guard, which lets the clock poke added by commit `9b79ddc9` be deleted — so a restart that yields is retried in about a harvest period instead of silently buying another full session.

**Files:**
- Modify: `Agent/General/NewRelicAgentInternal.m` (`-checkAndHandleSessionTimeout`, `-handle4HourSessionRestart`)
- Modify: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`

**Interfaces:**
- Consumes: `-tryBeginSessionStart`, `-endSessionStartDrainingDeferred` (Task 1); `-performSessionStartInitialization` (Task 2).
- Produces: no new symbols. `-handle4HourSessionRestart` and `-checkAndHandleSessionTimeout` keep their existing `void` signatures and header declarations.

- [ ] **Step 1: Write the failing tests**

Append to `NRMASessionStartGateTests.m`, immediately before the final `@end`:

```objc
#pragma mark - 4-hour restart

- (void) test_handle4HourSessionRestart_bailsWhenGateHeld {
    id agentMock = [OCMockObject partialMockForObject:self.agent];
    [[agentMock reject] performSessionStartInitialization];

    XCTAssertTrue([self.agent tryBeginSessionStart]);
    XCTAssertNoThrow([self.agent handle4HourSessionRestart]);

    [agentMock verify];
    [agentMock stopMocking];
    [self.agent endSessionStartDrainingDeferred];
}

- (void) test_skippedRestart_leavesClockUnadvanced {
    NRMASessionDurationManager* manager = [NRMASessionDurationManager shared];
    NSTimeInterval originalMax = manager.maxSessionDuration;

    [manager setMaxSessionDuration:2.0];
    [manager updateSessionStartTime:[NSDate dateWithTimeIntervalSinceNow:-5.0]];
    XCTAssertTrue([manager hasSessionExceeded], @"precondition: session must be over the limit");

    // Hold the gate so the restart has to yield.
    XCTAssertTrue([self.agent tryBeginSessionStart]);
    XCTAssertNoThrow([self.agent checkAndHandleSessionTimeout]);

    XCTAssertTrue([manager hasSessionExceeded],
                  @"a restart that yielded must leave the clock alone so the next harvest retries");

    [self.agent endSessionStartDrainingDeferred];
    [manager setMaxSessionDuration:originalMax];
    [manager updateSessionStartTime:[NSDate date]];
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: both new tests FAIL. `test_handle4HourSessionRestart_bailsWhenGateHeld` fails because the restart ignores the gate and still calls the funnel. `test_skippedRestart_leavesClockUnadvanced` fails on the final assertion, because `-checkAndHandleSessionTimeout` currently pokes the clock to `now` before calling the restart.

- [ ] **Step 3: Drop the clock poke from -checkAndHandleSessionTimeout**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
        NRLOG_AGENT_INFO(@"HarvestTimer: Session duration reached limit (%.0f seconds / %.0f max). Triggering session restart.", elapsed, maxDuration);
        [[NRMASessionDurationManager shared] updateSessionStartTime:[NSDate date]];
        [self handle4HourSessionRestart];
```

Replace with:

```objc
        NRLOG_AGENT_INFO(@"HarvestTimer: Session duration reached limit (%.0f seconds / %.0f max). Triggering session restart.", elapsed, maxDuration);
        // The session clock is deliberately not poked here.
        // -performSessionStartInitialization updates it only when the restart actually
        // runs, so a restart that loses the session-start gate is retried on the next
        // harvest instead of silently buying another full session. The gate also prevents
        // the recursion this poke used to guard against -- see -handle4HourSessionRestart.
        [self handle4HourSessionRestart];
```

- [ ] **Step 4: Make the restart claim the gate**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
- (void) handle4HourSessionRestart {
    NRLOG_AGENT_DEBUG(@"Executing 4-hour automatic session restart");
```

Replace with:

```objc
- (void) handle4HourSessionRestart {
    // Claim the gate before any side effect. This runs on the harvest thread from inside
    // -[NRMAHarvester execute], so it can collide with a foreground return, a setUserId,
    // or agent start -- and it is the one caller that can simply give up, because
    // -checkAndHandleSessionTimeout runs again on the next harvest tick.
    //
    // This is also what stops the recursion that used to be broken by poking the session
    // clock in -checkAndHandleSessionTimeout: the -execute below re-enters that method,
    // whose -handle4HourSessionRestart then fails to claim the gate this thread is still
    // holding, and returns.
    if (![self tryBeginSessionStart]) {
        NRLOG_AGENT_DEBUG(@"Skipping 4-hour session restart: a session start is already in flight. Retrying on the next harvest.");
        return;
    }

    @try {
    NRLOG_AGENT_DEBUG(@"Executing 4-hour automatic session restart");
```

Then find the tail of the same method:

```objc
    // Restart session: new session ID, new sample seeds, restart harvest
    [self sessionStartInitialization];

    // Restart session replay if enabled
    #if !TARGET_OS_TV && !TARGET_OS_WATCH
    if (@available(iOS 13.0, *)) {
        if ([self isSessionReplayEnabled] && [self isSessionReplaySampled]) {
            [self sessionReplayStart];
        }
    }
    #endif
}
```

Replace with:

```objc
    // Restart session: new session ID, new sample seeds, restart harvest.
    // Ungated: we already own the gate, so calling the wrapper would fail its own claim.
    [self performSessionStartInitialization];

    // Restart session replay if enabled
    #if !TARGET_OS_TV && !TARGET_OS_WATCH
    if (@available(iOS 13.0, *)) {
        if ([self isSessionReplayEnabled] && [self isSessionReplaySampled]) {
            [self sessionReplayStart];
        }
    }
    #endif
    } @finally {
        [self endSessionStartDrainingDeferred];
    }
}
```

The body between those two hunks is left exactly as it is — including its original indentation, which is now one level shallower than the `@try` that encloses it. That is deliberate: it keeps the diff to the two ends of the method instead of re-indenting 25 unchanged lines. Do not reformat it.

- [ ] **Step 5: Run the tests to verify they pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`, 6 tests executed.

- [ ] **Step 6: Verify the existing 4-hour tests still pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMAHarvestControllerTest \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`. These tests call `[timer tick]` and assert `XCTAssertNoThrow`, then restore the clock by hand, so none of them depends on the poke you just deleted.

- [ ] **Step 7: Commit**

```bash
git add Agent/General/NewRelicAgentInternal.m \
        Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m
git commit -m "Make the 4-hour session restart yield instead of racing

The restart arrives on the harvest thread already holding
@synchronized(harvester), so it cannot take a mutex to serialize against the
foreground and setUserId paths without inverting. It now claims the
non-blocking gate before any side effect and gives up if it loses -- safe,
because checkAndHandleSessionTimeout runs again on the next tick.

Claiming the gate is also a correct recursion guard for the nested -execute,
so the clock poke that 9b79ddc9 added for that purpose is gone. A restart
that yields now retries within a harvest period instead of silently
granting another full session."
```

---

### Task 4: setUserId claims the gate before ending the session

`-startNewSessionForUserId:` must claim **before** `-newSession`, or a loser would end the current session and leave it without a replacement. A loser still applies the user id: the thread that owns the gate is itself starting a new session, so the id lands on a fresh one regardless of who created it. The method stays synchronous, per commit `fc42be19`.

**Files:**
- Modify: `Agent/General/NewRelicAgentInternal.m` (`-startNewSessionForUserId:`)
- Modify: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`

**Interfaces:**
- Consumes: `-tryBeginSessionStart`, `-endSessionStartDrainingDeferred` (Task 1); `-performSessionStartInitialization` (Task 2).
- Produces: `- (void) applyUserId:(NSString* _Nullable)userId` — sets or removes `kNRMA_Attrib_userId`, extracted so both the winning and losing paths share it. Not used outside this method.

- [ ] **Step 1: Write the failing test**

Append to `NRMASessionStartGateTests.m`, immediately before the final `@end`:

```objc
#pragma mark - setUserId

- (void) test_startNewSessionForUserId_appliesUserIdWhenGateHeld {
    id agentMock = [OCMockObject partialMockForObject:self.agent];
    [[agentMock reject] performSessionStartInitialization];

    XCTAssertTrue([self.agent tryBeginSessionStart]);
    XCTAssertNoThrow([self.agent startNewSessionForUserId:@"gate-test-user"]);

    [agentMock verify];

    NSString* attributes = [self.agent.analyticsController sessionAttributeJSONString];
    XCTAssertNotNil(attributes, @"session attributes should be readable");
    XCTAssertTrue([attributes containsString:@"gate-test-user"],
                  @"the user id must be applied even when the session restart yields, got: %@",
                  attributes);

    [agentMock stopMocking];
    [self.agent endSessionStartDrainingDeferred];
}
```

If the `containsString:` assertion fails because the attribute was rejected rather than
because the gate misbehaved, the analytics instance needs a permissive attribute
validator. Add one the way `Analytics-Tests/PersistentStoreTests.m` does, using
`BlockAttributeValidator` with name, value, and event-type validators that all return
`YES`. Verify which it is by asserting on `sessionAttributeJSONString` *before* the
`startNewSessionForUserId:` call: if `setSessionAttribute:` never works on this fixture,
the validator is the cause, not the gate.

- [ ] **Step 2: Run the test to verify it fails**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests/test_startNewSessionForUserId_appliesUserIdWhenGateHeld \
  2>&1 | tail -40
```

Expected: FAIL. `-startNewSessionForUserId:` ignores the gate, so the rejected `performSessionStartInitialization` is reached via the ungated call it makes today.

- [ ] **Step 3: Make setUserId claim the gate**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
- (void) startNewSessionForUserId:(NSString* _Nullable)userId {
    @synchronized(kNRMA_BGFG_MUTEX) {
        [self.analyticsController newSession];
        [self sessionReplayEndSession];
        [NewRelicAgentInternal harvestNow];
        [self sessionStartInitialization];
        if (userId) {
            [self.analyticsController setSessionAttribute:kNRMA_Attrib_userId
                                                    value:userId
                                               persistent:YES];
        } else {
            [self.analyticsController removeSessionAttributeNamed:kNRMA_Attrib_userId];
        }
    }
}
```

Replace with:

```objc
- (void) startNewSessionForUserId:(NSString* _Nullable)userId {
    @synchronized(kNRMA_BGFG_MUTEX) {
        // Claim the gate before ending the current session. If another thread is already
        // restarting the session we must not end this one and leave it without a
        // replacement -- but the user id is applied either way, because the thread that
        // owns the gate is itself starting a new session, so the id lands on a fresh one
        // regardless of who created it.
        if (![self tryBeginSessionStart]) {
            NRLOG_AGENT_VERBOSE(@"setUserId: session start already in flight; applying the user id to it.");
            [self applyUserId:userId];
            return;
        }

        @try {
            [self.analyticsController newSession];
            [self sessionReplayEndSession];
            [NewRelicAgentInternal harvestNow];
            // Ungated: we already own the gate.
            [self performSessionStartInitialization];
            [self applyUserId:userId];
        } @finally {
            [self endSessionStartDrainingDeferred];
        }
    }
}

- (void) applyUserId:(NSString* _Nullable)userId {
    if (userId) {
        [self.analyticsController setSessionAttribute:kNRMA_Attrib_userId
                                                value:userId
                                           persistent:YES];
    } else {
        [self.analyticsController removeSessionAttributeNamed:kNRMA_Attrib_userId];
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`, 7 tests executed.

- [ ] **Step 5: Commit**

```bash
git add Agent/General/NewRelicAgentInternal.m \
        Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m
git commit -m "Claim the session-start gate before setUserId ends the session

The claim has to happen before -newSession, or a loser would end the current
session and leave it with no replacement. A loser still applies the user id:
the gate owner is itself starting a new session, so the id lands on a fresh
one either way. The set/remove pair moves to -applyUserId: so both paths
share it. Still synchronous, per fc42be19."
```

---

### Task 5: Agent start holds the gate across initialization

`-init` registers the lifecycle observers before it runs session start, so `-applicationWillEnterForeground` can fire and tear down the harvest pipeline `init` is still building. Claiming the gate before the observers exist closes that window.

**Files:**
- Modify: `Agent/General/NewRelicAgentInternal.m` (`-initWithCollectorAddress:crashCollectorAddress:andApplicationToken:`)
- Modify: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m`

**Interfaces:**
- Consumes: `-tryBeginSessionStart`, `-endSessionStartDrainingDeferred` (Task 1).
- Produces: no new symbols. This is the last task; nothing depends on it.

- [ ] **Step 1: Write the failing test**

Append to `NRMASessionStartGateTests.m`, immediately before the final `@end`:

```objc
#pragma mark - Concurrency smoke

- (void) test_concurrentSessionStarts_doNotCrash {
    id agentMock = [OCMockObject partialMockForObject:self.agent];

    // Track how many session starts are running at once, and the high-water mark.
    // Heap-allocated so the stub block captures pointers by value.
    _Atomic int32_t* concurrent    = calloc(1, sizeof(_Atomic int32_t));
    _Atomic int32_t* maxConcurrent = calloc(1, sizeof(_Atomic int32_t));

    [[[agentMock stub] andDo:^(NSInvocation* invocation) {
        int32_t now = atomic_fetch_add_explicit(concurrent, 1, memory_order_acq_rel) + 1;

        int32_t seen = atomic_load_explicit(maxConcurrent, memory_order_acquire);
        while (now > seen &&
               !atomic_compare_exchange_weak_explicit(maxConcurrent, &seen, now,
                                                      memory_order_acq_rel,
                                                      memory_order_acquire)) {
            // A failed exchange reloads `seen`, so the loop re-tests against the new value.
        }

        atomic_fetch_sub_explicit(concurrent, 1, memory_order_acq_rel);
    }] performSessionStartInitialization];

    const NSUInteger threadCount = 16;
    const NSUInteger iterations  = 50;

    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    for (NSUInteger t = 0; t < threadCount; t++) {
        dispatch_group_async(group, queue, ^{
            for (NSUInteger i = 0; i < iterations; i++) {
                [self.agent sessionStartInitialization];
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);

    int32_t peak = atomic_load_explicit(maxConcurrent, memory_order_acquire);
    XCTAssertLessThanOrEqual(peak, 1,
                             @"the gate must never let two session starts overlap, saw %d", peak);
    XCTAssertGreaterThan(peak, 0, @"sanity: at least one session start should have run");

    free(concurrent);
    free(maxConcurrent);
    [agentMock stopMocking];
}
```

- [ ] **Step 2: Run the test to verify it passes**

This test is written against behaviour Tasks 1-2 already deliver, so unlike the other tasks it should pass immediately. Run it to confirm the gate holds under real contention rather than only in the two-call case:

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests/test_concurrentSessionStarts_doNotCrash \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`. If `maxConcurrent` comes back above 1, stop — the gate is broken and Tasks 1-2 need revisiting before continuing.

- [ ] **Step 3: Claim the gate at the top of the enabled branch**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
        self->_isShutdown = false;
        self->_enabled = ![self isDisabled];
        if (self->_enabled) {
#if TARGET_OS_WATCH
```

Replace with:

```objc
        self->_isShutdown = false;
        self->_enabled = ![self isDisabled];
        if (self->_enabled) {
            // Claim the session-start gate before the lifecycle observers below exist:
            // -applicationWillEnterForeground can fire the moment they do, and its session
            // start would tear down the harvest pipeline this initializer is still
            // building. Holding the gate makes that handler defer instead.
            //
            // A failed claim is not a reason to skip agent start. Init is by construction
            // the first session start, so a set flag here can only be stale state from a
            // previous test-mode instance, and the release below clears it.
            if (![self tryBeginSessionStart]) {
                NRLOG_AGENT_ERROR(@"Agent start: a session start was already in flight; taking the session-start gate anyway.");
            }
#if TARGET_OS_WATCH
```

- [ ] **Step 4: Release the gate after session start**

In `Agent/General/NewRelicAgentInternal.m`, find:

```objc
            [self initialize];
            [self onSessionStart];

            if ([NRMAFlags shouldEnableCrashReporting]) {
                NRMACrashReporterRecorder* crashReportRecorder = [[NRMACrashReporterRecorder alloc] init];
```

Replace with:

```objc
            @try {
                [self initialize];
                [self onSessionStart];
            } @finally {
                [self endSessionStartDrainingDeferred];
            }

            if ([NRMAFlags shouldEnableCrashReporting]) {
                NRMACrashReporterRecorder* crashReportRecorder = [[NRMACrashReporterRecorder alloc] init];
```

- [ ] **Step 5: Run the gate tests to verify they still pass**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -40
```

Expected: `TEST SUCCEEDED`, 8 tests executed.

- [ ] **Step 6: Run the full Agent_Tests suite**

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  2>&1 | tail -60
```

Expected: the only failures are the 5 `NRMASessionExclusivityWithDelegateTests` upload tests, which fail on a clean tree because they depend on live `imgur.com`. If you see any *other* failure, first confirm it is pre-existing by stashing your work (`git stash`), rerunning, and comparing — then unstash.

- [ ] **Step 7: Commit**

```bash
git add Agent/General/NewRelicAgentInternal.m \
        Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRMASessionStartGateTests.m
git commit -m "Hold the session-start gate across agent initialization

-init registers the lifecycle observers before it runs session start, so
-applicationWillEnterForeground could fire and tear down the harvest pipeline
init was still building. Claiming the gate before the observers exist closes
that window; the foreground handler defers instead and its session start is
re-dispatched once init releases.

A failed claim still proceeds -- init is by construction the first session
start, so a set flag can only be stale test-mode state, and the @finally
release clears it."
```

- [ ] **Step 8: Run the gate tests once under the Thread Sanitizer**

The smoke test in Step 2 proves the gate serializes the funnel; TSan is what catches data races the gate does not cover.

```bash
xcodebuild test \
  -project Agent.xcodeproj \
  -scheme Agent-iOS \
  -destination 'platform=iOS Simulator,id=15135556-1BB1-445F-8AB2-E080E1F8B4BE' \
  -enableThreadSanitizer YES \
  -only-testing:Agent_Tests/NRMASessionStartGateTests \
  2>&1 | tail -60
```

Expected: `TEST SUCCEEDED` with no `WARNING: ThreadSanitizer: data race` in the output. If TSan reports a race, record the report in the PR description — do not silence it and do not treat it as a blocker for this change unless it names the gate atomics themselves, since the surrounding session-start code has known pre-existing races (see the out-of-scope list in the spec).

---

## Out of scope

These were found while tracing the lock graph. None is made worse by this change; all are worth separate tickets. Do **not** fix them in this plan.

1. `controller → harvester` in `+[NRMAHarvestController start]` versus `harvester → InitializationLock → controller` on the 4-hour path — a second AB-BA pair the gate does not remove.
2. The nested `[harvester execute]` in `-handle4HourSessionRestart` runs a full second harvest inside the outer `-execute`.
3. `-makeSampleSeeds` is reachable only from the session-start funnel, so all three sample seeds are `0` (always sampled in) after a cold launch.
4. `-[NRMAHarvestTimer updateTimer]` can restart an invalidated timer against a stale harvester after a session restart, when `data_report_period` differs from the current period.
5. `didFireEnterForeground` is `NO` at cold launch, so the first `-applicationDidEnterBackground` early-returns and skips its harvest.
