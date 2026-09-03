# Handled-exception OOM-resilience tests

Recording a handled error must never be able to kill the app that is being watched.
Everything under `-[NRMAHandledExceptions recordError:attributes:]` is C++ that
allocates — the report object, the attribute maps, and the flatbuffer serialization
inside `HexStore::store()`. One `recordError` call makes **112–304 heap allocations**.
When a device is low on memory any one of them can throw `std::bad_alloc`, and for a
long time nothing on that path caught it: the throw unwound straight out through the
Objective-C frame with no handler above it, hit `std::terminate`, and the host app died
with `__cxa_call_terminate` in the trace.

That is [issue #884](https://github.com/newrelic/newrelic-ios-agent/issues/884) /
NR-614312. It was reported as a single crash from a single user, because it only needs
one unlucky allocation during one serialization.

This suite makes that failure deterministic. It replaces global `operator new` so a
chosen fraction of allocations fail on demand, then hammers the handled-exception path
and asserts the process is still alive and every persisted report is well-formed.

## Running it

```bash
scripts/run_oom_resilience_tests.sh
```

That runs both stages and prints a summary:

```
============== OOM resilience summary ==============
native harness (store path survives):  PASS
stored reports well-formed:            PASS
app end-to-end (crash boundary holds): PASS
RESULT: PASS
```

```bash
# just the fast native harness — no simulator, a few seconds
scripts/run_oom_resilience_tests.sh --harness-only

# just the end-to-end app test, with the pressure turned up
scripts/run_oom_resilience_tests.sh --app-only --fail-one-in 500

# pick a simulator, reuse the previous app build
scripts/run_oom_resilience_tests.sh --simulator 'iPhone 17 Pro' --no-build
```

Logs and binaries land in `build/oom-resilience/` (gitignored).

The injector reads three env vars, forwarded by the script but overridable:
`NR_OOM_ONE_IN` (failure rate), `NR_OOM_DELAY` (seconds before arming), and
`NR_OOM_THREAD` (thread name to target, or `*` for process-wide).

### Confirming the test is not vacuous

A resilience test that passes because it never provoked anything is worse than no test.
To check it still detects the original bug, revert the fix and assert the crash:

```bash
git stash push -- Agent/HandledException/NRMAHandledExceptions.mm \
                  libMobileAgent/src/Hex/src/HexStore.cxx \
                  libMobileAgent/src/Hex/src/report/exception/HandledException.cxx

scripts/run_oom_resilience_tests.sh --app-only --expect-crash
# expect: PASS (crashed as expected with --expect-crash)

git stash pop
```

Without the fix the app dies within the first couple of thousand calls with
`libc++abi: terminating due to uncaught exception of type std::bad_alloc`.

## The two stages

### `harness` — the store path, natively

`Tests/OOM-Resilience/hex_oom_harness.cxx` compiles the agent's own Hex C++ into a
standalone binary and calls `HexStore::store()` — what `HexController::submit()` calls
— in a loop, wrapping each iteration in a `try`/`catch` that mirrors the Objective-C
crash boundary. It catches two regressions:

- **An exception escaping the store path.** Exit 70, with a demangled backtrace.
- **A nested `FlatBufferBuilder`.** Exit 71. See below.

`Tests/OOM-Resilience/verify_reports.cxx` then runs the flatbuffers verifier over every
`.fbad` the loop wrote. Surviving is only half the contract; the other half is that no
half-written report reaches disk and therefore the collector.

### `app` — the crash boundary, end to end

`Tests/OOM-Resilience/oom_injector.cxx` builds a dylib that replaces global
`operator new` and is loaded with `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`, so **no agent
or app code has to change to run the test**. Two things keep it targeted:

- It arms a few seconds after load, so app and agent startup happen on a healthy heap.
- It only fails allocations on the thread named `nr-oom-loop`, which the driver names
  before it starts looping. Process-wide injection also takes down the agent's harvest
  and upload threads — a real exposure, but a different one from #884, and it made this
  test flaky. Set `NR_OOM_THREAD=*` to explore that instead (see below).

The loop itself is `-[AppDelegate runHexOOMReproIfRequested]` in NRTestApp, driven by
launch arguments:

```bash
xcrun simctl launch --console <sim> com.newrelic.NRApp.bitcode \
    -RunHexOOMRepro -HexOOMIterations 20000 -HexOOMStartDelay 16
```

Pass looks like many `Dropped handled error report … std::bad_alloc` lines followed by
`HexOOMRepro: DONE — survived 20000 recordError calls`.

Note that on a passing run the app is still alive at the end — it is a UI app and does
not exit. `simctl launch --console` would therefore block forever, so the script watches
the log for a verdict and then terminates the app itself (`--timeout`, default 600s). If
you drive the launch by hand, remember to `simctl terminate` afterwards.

## Why `FLATBUFFERS_ASSERT` is the detector

`Library::serialize` and `Thread::serialize` write into the `FlatBufferBuilder` through
`CreateLibrary`/`CreateThread`, which open a table. Swallowing an exception thrown
part-way through leaves the builder with `nested_ == true`. The next
`CreateString`/`CreateVector` then trips `FLATBUFFERS_ASSERT(!nested)`.

This is exactly what the `catch (...)` blocks inside `buildLibraries()` used to do, and
it is why they are gone. `HandledException.cxx` now guards only the parts that touch no
flatbuffer state — copying the library snapshot, and reading the app image UUID — and
lets a throw from any builder write propagate so the whole report is abandoned.

**Both stages must be built without `NDEBUG`.** `FLATBUFFERS_ASSERT` is plain `assert`,
so a release build (`ENABLE_NS_ASSERTIONS = NO`) compiles it out; a nested builder then
silently emits a malformed buffer instead of aborting. The runner script hard-codes
`-O0` with no `-DNDEBUG` for this reason — do not "optimize" that away.

## Reading the output

| Symptom | What it means |
|---|---|
| harness exit 70, `PROCESS KILLED by an uncaught C++ exception` | Something on the store path throws and nothing catches it. The backtrace names the frame. |
| harness exit 71, `FLATBUFFERS_ASSERT(!nested)` | A `catch` swallowed an exception mid-table and left the builder nested. Look for a new `try`/`catch` around a builder write. |
| `verify_reports` reports invalid or 0-byte reports | A partially serialized report reached disk. Check that `HexStore::store()` still serializes *before* it opens the file. |
| app stage: `libc++abi: terminating` | The Objective-C crash boundary is gone or a new unguarded entry point was added. |
| app stage: `INCONCLUSIVE (nothing was dropped)` | The injector never armed — usually a `DYLD_INSERT_LIBRARIES` path problem, or `--fail-one-in` set too high. |

## Tuning the failure rate

`--fail-one-in 1000` is the default and is aggressive enough to kill unfixed code within
a couple of thousand calls. Turning it up is fine, with one caveat: **below roughly
1-in-100 the app's own startup and UIKit allocations start failing** in code that has
nothing to do with the agent. A crash there is a false positive, not an agent bug.

The reporter's device had ~175 MiB free of ~6.8 GiB in use, which is a *transient*
condition — most allocations succeed and the occasional one fails. That is what a
1-in-N rate models, and it is a better approximation than a hard allocation ceiling.

## What is deliberately not covered

- **Real device memory pressure.** A simulator app is a macOS process with the host's
  RAM and swap behind it, so `malloc` never actually fails; iOS jetsams a real device
  instead of returning null. Injection is the only way to make this deterministic. A
  tight `recordError` loop with *no* injection survives 20,000 calls and proves nothing.
- **The agent's other threads.** Injecting process-wide (`NR_OOM_THREAD=*`) kills the
  app from the harvest and upload threads instead — they do unguarded C++ allocation
  too, and on a device at 175 MiB free they are exposed the same way `recordError` was.
  Nothing here fixes or tests that; it is a strictly larger piece of work than #884 and
  is called out so it is not mistaken for covered ground. If you want to see it:
  `NR_OOM_THREAD='*' scripts/run_oom_resilience_tests.sh --app-only`.

- **The upload path.** `NRMAHexUploader` has its own failure modes (see #745 and the
  invalidated-`NSURLSession` fix in 7.7.6). This suite stops at the report on disk.
- **`_keyContext->insert()` ordering.** `HexController::submit()` stores to disk before
  inserting into the in-memory context, so a throw from `insert` leaves a report that
  will upload but is missing from the in-memory mirror. The crash boundary catches it
  and the app survives; the ordering itself is untouched and untested.
