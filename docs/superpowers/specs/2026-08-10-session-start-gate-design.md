# Session-start gate: serializing `onSessionStart` without inverting the lock order

Date: 2026-08-10
Status: approved, not yet implemented
Area: `Agent/General/NewRelicAgentInternal.m`

## Problem

Starting a session does two destructive things: `-sessionStartInitialization` tears down
and rebuilds the entire harvest pipeline, and `-onSessionStart` reassigns the session
identifier and re-initializes analytics. Two threads doing that at once corrupt each
other's work.

Four call sites reach session start, from three different lock contexts:

| Call site | Line | Locks held on entry |
| --- | --- | --- |
| `-init` | `:285` | none |
| `-applicationWillEnterForeground` | `:839` | `kNRMA_BGFG_MUTEX`, `kNRMA_APPLICATION_WILL_TERMINATE` |
| `-startNewSessionForUserId:` | `:882` | `kNRMA_BGFG_MUTEX` |
| `-handle4HourSessionRestart` | `:914` | `@synchronized(harvester)`, from `-[NRMAHarvester execute]` |

`kNRMA_BGFG_MUTEX` serializes the two middle rows against each other and against the
background harvests. It does not cover `-init` or the 4-hour restart.

A field crash (NR-603379 / NR-603422) surfaced this as a libmalloc abort inside the
crash-metadata store, reached from two concurrent `-onSessionStart` calls. That
memory-safety consequence has since been fixed at the storage layer, but the concurrent
session starts themselves still race harvester restart and session attributes.

### Why the obvious fix is wrong

Wrapping `-handle4HourSessionRestart` in `@synchronized(kNRMA_BGFG_MUTEX)` deadlocks.

Four sites already establish **BGFG before the harvester lock**: the foreground
`harvestNow` (`:808`), `setUserId`'s `harvestNow` (`:881`), and the two background
harvests that call `[harvester execute]` while holding BGFG (`:1024`, `:1102`).
`-[NRMAHarvester execute]` takes `@synchronized(self)` (`NRMAHarvester.mm:746`).

The 4-hour restart arrives from the opposite direction. It is called at
`NRMAHarvester.mm:763`, *inside* that same `@synchronized(self)`. Any mutex it acquires
is therefore ordered **after** the harvester lock. Sharing one mutex across both
orderings is a textbook AB-BA inversion: it trades a fixed crash for a hang.

A related inversion already exists and is **not** addressed here: `+[NRMAHarvestController
start]` takes `@synchronized(controller)` then `[harvester execute]` (`:230`-`:244`),
while the 4-hour path holds the harvester lock and then reaches for
`NRMAHarvestControllerInitializationLock` and `@synchronized(controller)` via
`stop`/`initialize:`.

## Design

A **non-blocking gate**. Not a mutex: a single-word atomic test-and-set. A thread either
claims it and runs, or loses and returns immediately. No thread ever waits on another,
so **no edge is added to the lock graph** and the inversion cannot arise. That property
is the whole point of the design and is what makes it reviewable without a full
lock-ordering audit.

### Mechanism

File-static in `NewRelicAgentInternal.m`, matching the `stdatomic.h` idiom already used
in `Agent/CrashHandler/ExceptionDataInterface/NRMAExceptionMetaDataStore.m:12`:

```objc
#include <stdatomic.h>

static _Atomic bool __NRMASessionStartInFlight = false;

// Set by a loser whose session start still needs to happen. Whoever releases the gate
// re-dispatches it.
static _Atomic bool __NRMASessionStartDeferred = false;
```

Two instance methods (instance rather than static C functions so tests can reach them
through a category declaration, with no production header change):

```objc
// YES means the caller owns the gate and must release it with
// -endSessionStartDrainingDeferred.
- (BOOL) tryBeginSessionStart {
    return !atomic_exchange_explicit(&__NRMASessionStartInFlight, true, memory_order_acq_rel);
}

// Releases the gate, then re-runs any session start deferred while we held it. The
// re-run is dispatched asynchronously on purpose: this can be called from the harvest
// thread while it still holds @synchronized(harvester), and running session start there
// would nest a second harvest inside the first.
- (void) endSessionStartDrainingDeferred {
    atomic_store_explicit(&__NRMASessionStartInFlight, false, memory_order_release);

    if (!atomic_exchange_explicit(&__NRMASessionStartDeferred, false, memory_order_acq_rel)) {
        return;
    }
    NRLOG_AGENT_VERBOSE(@"Session start: running deferred session start");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_isShutdown) { return; }
        [self sessionStartInitialization];
    });
}
```

`memory_order_acq_rel` on the read-modify-write pairs with `memory_order_release` on the
store, so a thread that claims the gate sees everything the previous owner published.

### Funnel split

The gate must be claimed exactly once per path, so it needs no owner tracking and no
depth count. `-sessionStartInitialization` splits into an ungated core plus a gated
wrapper:

```objc
// The session start itself. Callers must own the session-start gate.
- (void) performSessionStartInitialization { /* current :858-874 body, verbatim */ }

- (void) sessionStartInitialization {
    if (![self tryBeginSessionStart]) {
        NRLOG_AGENT_VERBOSE(@"Session start already in flight; deferring this one.");
        atomic_store_explicit(&__NRMASessionStartDeferred, true, memory_order_release);

        // Belt and braces for the case this gate exists to protect. On a background
        // agent start, -initialize skips +[NRMAHarvestController start] (:376), so this
        // handler is what starts the harvester; if the deferred re-run were ever lost,
        // the session would report nothing at all. +start is safe to call again -- the
        // timer no-ops when already running and the harvester only executes from
        // UNINITIALIZED/DISCONNECTED.
        [NRMAHarvestController start];
        return;
    }
    @try { [self performSessionStartInitialization]; }
    @finally { [self endSessionStartDrainingDeferred]; }
}
```

`sessionStartInitialization` keeps its `void` signature, so `NewRelicAgentInternal.h`
does not change and existing callers and tests keep compiling.

### Call-site policy

| Site | Policy |
| --- | --- |
| `-init` `:232` | Claims **before** the lifecycle observers at `:243`-`:250` exist, because `-applicationWillEnterForeground` can fire the moment they do and its session start would tear down the pipeline `init` is still building. `@try`/`@finally` around `:284`-`:285` only. A failed claim logs an error and proceeds anyway — init must never be skipped — and the `@finally` releases unconditionally either way. That is deliberate: init is by construction the first session start, so a set flag here can only be stale state from a prior test-mode instance, and clearing it is the recovery. |
| `-applicationWillEnterForeground` `:839` | **Unchanged.** The gate lives inside `sessionStartInitialization`, so the handler still sets `didFireEnterForeground`, does the Return Harvest, clears `didFireEnterBackground`, and records the AppLaunch action whether or not the session restarts. |
| `-startNewSessionForUserId:` `:878` | Claims **before** `newSession`/`sessionReplayEndSession`/`harvestNow`, so a loser never ends the session and leaves it without a replacement. A loser applies the user id and returns: the gate owner is itself starting a new session, so the id lands on a fresh one regardless of who created it. Stays synchronous, per commit `fc42be19` ("setUserId needs to stay synchronous"). The set/remove pair moves to `-applyUserId:` to avoid duplication. |
| `-handle4HourSessionRestart` `:893` | Claims before **any** side effect; on failure logs and returns. It is the one caller that can simply give up, because `-checkAndHandleSessionTimeout` runs again on the next harvest tick. `:914` becomes `performSessionStartInitialization`. |

### Behavior change: drop the premature clock update

`-checkAndHandleSessionTimeout` loses its `updateSessionStartTime:[NSDate date]`
(`:691`). That line was added by commit `9b79ddc9` to break an infinite loop, and the
gate now does that job correctly.

```objc
- (void) checkAndHandleSessionTimeout {
    if ([[NRMASessionDurationManager shared] hasSessionExceeded]) {
        NRLOG_AGENT_INFO(@"HarvestTimer: Session duration reached limit ...");
        // The clock is no longer poked here. -performSessionStartInitialization updates
        // it (:873) only when the restart actually runs, so a restart that loses the
        // gate is retried on the next harvest instead of silently buying another full
        // session. Recursion -- this method is re-entered by the nested -execute in
        // -handle4HourSessionRestart -- is now prevented by the gate itself.
        [self handle4HourSessionRestart];
    }
}
```

Recursion trace: `handle4HourSessionRestart` holds the gate, calls
`[harvester execute]` (`:909`), which re-enters `@synchronized(self)` recursively on the
same thread, reaches `checkAndHandleSessionTimeout`, finds `hasSessionExceeded` still
`YES` (the clock has not advanced yet), calls `handle4HourSessionRestart`, fails to
claim the gate this thread still holds, logs, and returns.

Metric spam is impossible: `enqueue4HourSessionRestartMetric` (`:906`) sits inside the
claimed section, so only a winning attempt emits it, and a winning attempt always
advances the clock via `performSessionStartInitialization`.

**Net effect:** a 4-hour restart that yields is retried in roughly one harvest period
(default 60s) instead of silently granting another full session.

## Failure handling

- Every claim pairs with a `@finally` release, so a throwing body cannot strand the
  gate. `DISABLE_NRMA_EXCEPTION_WRAPPER` is never defined in this project (only
  `DISABLE_NR_EXCEPTION_WRAPPER`, in three build configs), so plain `@try`/`@finally`
  always compiles in this file.
- The one unguarded window is `init` between the claim (`:232`) and the `@try` (`:284`):
  notification registration and C setters, which do not throw. If they did, the agent is
  unusable regardless.
- Test-mode re-instantiation (`_NRMAAgentTestModeEnabled`): a stale set flag makes
  `init` log an error, proceed, and release, so it self-heals.
- The deferred re-dispatch checks `_isShutdown`, so it cannot resurrect a shut-down
  agent.
- Known narrow window: a loser's `deferred` store can land just after the owner's
  drain-exchange, stranding that one deferral until the next release. The
  `[NRMAHarvestController start]` safety net covers the only severe consequence — a
  session that reports nothing — and the rest (fresh session id, sample seeds) is
  best-effort.

## Testing

Added to `Tests/Unit-Tests/NewRelicAgentTests/Uncategorized/NewRelicAgentTests.m`, which
already drives `[NewRelicAgentInternal sharedInstance]` with a `destroyAgent` teardown,
so no `.pbxproj` edit is required. The test file declares the gate primitives via
`@interface NewRelicAgentInternal (Testing)`.

| Test | Asserts |
| --- | --- |
| `test_gate_onlyOneClaimSucceeds` | N threads call `-tryBeginSessionStart`; exactly one gets `YES` |
| `test_sessionStartInitialization_yieldsWhenGateHeld` | Claim, then `sessionStartInitialization`; session id unchanged |
| `test_deferredSessionStart_runsOnRelease` | Claim, `sessionStartInitialization`, release; session id changes asynchronously |
| `test_handle4HourSessionRestart_bailsWhenGateHeld` | Claim, then `handle4HourSessionRestart`; session id unchanged and no `Session/Duration` metric queued |
| `test_skippedRestart_leavesClockUnadvanced` | Short `maxSessionDuration`; claim, `checkAndHandleSessionTimeout`, assert `hasSessionExceeded` still `YES`; release, call again, session id changes |
| `test_startNewSessionForUserId_appliesUserIdWhenGateHeld` | Claim, then `startNewSessionForUserId:@"u1"`; userId attribute present, session id unchanged |
| `test_concurrentSessionStarts_doNotCrash` | N x M threads on `sessionStartInitialization`; smoke only, real coverage from one Thread Sanitizer run |

Regression suites: `Tests/Unit-Tests/NewRelicAgentTests/Harvester-Tests/NRHarvestControllerTest.m`
(the 4-hour tests at `:150`-`:284`) and `NRMASessionDurationManagerTests.swift`. None of
them assert on the deleted `:691` behavior; they call `[timer tick]`, assert
`XCTAssertNoThrow`, and restore the clock manually. The comment at
`NRHarvestControllerTest.m:237` remains accurate.

Two environment constraints carried over from earlier sessions:

- Build and run with **Xcode 26.3 (release)**. `Agent_Tests` hits an OCMock link failure
  under the Xcode 27 beta.
- Baseline before blaming the diff: 5 `NRMASessionExclusivityWithDelegateTests` upload
  tests fail on a clean tree because they depend on live `imgur.com`.

## Explicitly out of scope

Pre-existing issues found while tracing the lock graph. None are made worse by this
change; all are worth filing separately.

1. `controller -> harvester` in `+[NRMAHarvestController start]` (`:230`-`:244`) versus
   `harvester -> InitializationLock -> controller` on the 4-hour path: a second
   inversion the gate does not remove.
2. The nested `[harvester execute]` at `:909` runs a full second harvest inside the
   outer `execute`.
3. `makeSampleSeeds` is reachable only from `sessionStartInitialization`, so all three
   sample seeds are `0` (always sampled in) after a cold launch.
4. `-[NRMAHarvestTimer updateTimer]` can restart an invalidated timer against a stale
   harvester after a session restart, when `data_report_period` differs from the current
   period.
5. `didFireEnterForeground` is `NO` at cold launch, so the first
   `-applicationDidEnterBackground` early-returns at `:937` and skips its harvest.

## What this fixes and what it does not

Fixes: concurrent session starts between all four call sites, with no new lock edge, and
a 4-hour restart that yields now retries within a harvest period.

Does not fix: the `+start` inversion (item 1 above), and does not attempt the full
lock-ordering audit that consolidating these locks would require.
