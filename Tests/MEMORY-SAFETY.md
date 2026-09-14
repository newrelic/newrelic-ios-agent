# Memory-safety tests

A use-after-free in Objective-C usually does not crash where the bug is. The freed memory
is still mapped and often still holds plausible bytes, so the bad read succeeds for weeks
and then one day `objc_msgSend` lands on a recycled `isa` pointer and the process dies
somewhere unrelated. In a crash report that looks like a mystery segfault in `libobjc`.

This suite makes those bugs deterministic. It runs the existing unit tests with the
malloc and Objective-C runtime diagnostics enabled, so a stale pointer traps at the moment
it is used, with the type of the freed object named in the message.

## Running it

```bash
scripts/run_memory_safety_tests.sh
```

That builds and runs the curated suite (below) with zombies and scribble on, then prints a
summary and exits non-zero if anything tripped.

```bash
# one class or one test
scripts/run_memory_safety_tests.sh --only NRMAHarvesterConfigurationLifetimeTests
scripts/run_memory_safety_tests.sh --only NRMAHarvesterTest/testHarvestConfiguration

# the whole Agent_Tests target, not just the curated suite
scripts/run_memory_safety_tests.sh --all

# AddressSanitizer instead of zombies (slower, but reports who freed the memory)
scripts/run_memory_safety_tests.sh --asan

# reuse the previous build, pick a simulator, list the suite
scripts/run_memory_safety_tests.sh --no-build
scripts/run_memory_safety_tests.sh --simulator 'iPhone 16 Pro'
scripts/run_memory_safety_tests.sh --list
```

Logs land in `build/memory-safety/` (gitignored).

### From Xcode

Enable the diagnostics on the **Agent-iOS** scheme by hand:
*Product → Scheme → Edit Scheme → Test → Diagnostics*, then check **Zombie Objects**
and **Malloc Scribble**. Run tests with `⌘U`. Turn them back off afterwards — zombies
never free anything, so leaving them on makes every subsequent test run leak and slow down.

Do not try to commit those checkboxes as a shared scheme. They are not serialized in a form
that `xcodebuild build-for-testing` bakes into the `.xctestrun`, so a scheme that looks
correct in the Xcode UI can still run with the diagnostics inert — which is worse than not
having them, because the suite then reports success without checking anything. That is
exactly why the script injects the environment variables into the `.xctestrun` instead, and
why it independently greps the log rather than trusting the pass/fail summary.

### From CI

The script is self-contained and returns a meaningful exit code, so a job is just:

```yaml
- name: Memory-safety tests
  run: scripts/run_memory_safety_tests.sh
```

This is not currently wired into `.github/workflows/main.yml`. It is worth adding — the
bug this suite was written for shipped through five releases precisely because nothing in
CI would have caught it.

## How it is wired

```
scripts/run_memory_safety_tests.sh   the runner: builds, injects diagnostics, runs, judges
scripts/lib_patch_xctestrun.py       injects env vars into every test target in the .xctestrun
Tests/.../NRMAHarvesterConfigurationLifetimeTests.m   the lifetime regression tests
```

`xcodebuild build-for-testing` emits an `.xctestrun`, which is the complete launch spec for
the test bundle — including the environment the test process runs in. The runner patches
`EnvironmentVariables` in that file and then calls `test-without-building -xctestrun`, so the
diagnostics are guaranteed to be present. `lib_patch_xctestrun.py` handles both the legacy
layout (target names as top-level keys) and the newer `TestConfigurations` layout.

### Checking that the harness still works

A memory-safety suite that has quietly stopped enabling its diagnostics passes everything
forever. If you change the plumbing, verify it end to end by reintroducing the original bug
and confirming the suite fails:

```bash
# make one property unsafe again
sed -i '' 's/@property(nonatomic,copy) NSDictionary\* request_header_map;/@property(nonatomic,assign) NSDictionary* request_header_map;/' \
  Agent/Harvester/DataStore/NRMAHarvesterConfiguration.h

scripts/run_memory_safety_tests.sh --only NRMAHarvesterConfigurationLifetimeTests
# expected: "zombie messages (use-after-free): 1" or more, and RESULT: FAIL

git checkout -- Agent/Harvester/DataStore/NRMAHarvesterConfiguration.h
```

If that comes back `RESULT: PASS`, the harness is broken, not the code.

## What the diagnostics do

| Setting | Env var | What it catches |
|---|---|---|
| Zombie Objects | `NSZombieEnabled` | A deallocated object is replaced by a zombie that logs `message sent to deallocated instance` and traps, instead of being freed and reused. This is the one that catches the classic dangling-`assign`-property bug. |
| Malloc Scribble | `MallocScribble` | Freed memory is overwritten with `0x55`, so a surviving pointer reads obvious garbage rather than stale-but-plausible data. Catches non-object buffers that zombies do not cover. |
| Malloc Guard Edges | `MallocGuardEdges` | Guard pages around large allocations, so overruns fault immediately. |
| Malloc Pre-Scribble | `MallocPreScribble` | Fills *new* allocations with `0xAA`, catching reads of uninitialized memory. |
| Freed-object autorelease check | `NSAutoreleaseFreedObjectCheckEnabled` | Catches autoreleasing an object that was already freed. |
| AddressSanitizer | (`--asan`) | Full redzone/quarantine instrumentation. Reports the allocation stack *and* the free stack. Needs its own instrumented build. |

Zombies and ASan overlap but are not redundant: zombies are cheap and pinpoint the bad
*send*; ASan is expensive and pinpoints the bad *free*. Reach for zombies first, then ASan
once you know a UAF exists and need to find who released the object.

`MallocStackLogging` is off by default because it is slow. Pass `--stacks` when you need
`malloc_history` to resolve a specific zombie address to its allocation stack.

## Reading the output

A clean run:

```
================ memory safety summary ================
zombie messages (use-after-free): 0
AddressSanitizer reports:         0
unexpected process exits:         0
xcodebuild exit code:             0
RESULT: PASS
```

A detected use-after-free:

```
--- use-after-free detected ---
  *** -[__NSDictionaryI retain]: message sent to deallocated instance 0x10656f2c0
RESULT: FAIL
```

**A zombie trap kills the test process.** XCTest cannot report a normal failure for a
process that no longer exists, so `xcodebuild` may say `Executed 0 tests, with 0 failures`
for the very run that found the bug. Never read the summary line on its own — that is why
the script greps the log independently and treats any zombie message as a failure. If you
run `xcodebuild` by hand, do the same.

The class in the message is the type of the **freed** object, not the object that was
messaged incorrectly. `-[__NSDictionaryI retain]` means something held an unowned pointer
to an immutable dictionary that had already been released.

## The suite

`scripts/run_memory_safety_tests.sh --list` is the source of truth; the list lives in the
script. Today it is the harvester configuration and harvest-cycle classes, because that is
where the agent keeps parsed collector state alive across autorelease-pool and
harvest-cycle boundaries:

- `NRMAHarvesterConfigurationLifetimeTests` — written for this; see below
- `NRMAHarvesterTest`, `NRMAHarvestControllerTest`, `NRMAHarvesterStateTest`
- `NRMAConnectionTest`
- `SessionReplayTest`

`NRMAHarvesterConnectionTests` is deliberately **not** in the suite: its `testSendData`
issues a real, unmocked request to `mobile-collector.newrelic.com` and asserts a `403`, so
it reports `statusCode 0` and fails whenever the network is unavailable. This suite is a
deterministic gate on memory safety and must not go red over a live HTTP call. Run it
explicitly with `--only NRMAHarvesterConnectionTests` when you want it.

## Writing a test that can actually fail

Under zombies a lifetime test only proves something if the object under test would
genuinely have been deallocated. Two ways to write a test that always passes by accident:

**1. String and dictionary literals are never freed.** `@"custom"` is a compile-time
`NSConstantString` in the binary; a dangling pointer to one stays readable forever. Build
values dynamically — parse them out of JSON, or construct them with `stringWithFormat:` —
so they are heap allocated and reference counted.

**2. The pool has to actually drain.** Parse inside an explicit `@autoreleasepool` and read
only after the closing brace. Without that, the autoreleased graph is still alive for the
rest of the test method and the bug stays hidden.

`NRMAHarvesterConfigurationLifetimeTests` follows this shape:

```objc
NRMAHarvesterConfiguration *configuration = nil;
@autoreleasepool {
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    configuration = [[NRMAHarvesterConfiguration alloc] initWithDictionary:parsed];
}
// `parsed` and everything it owned is gone. Reads below must still be valid.
XCTAssertEqualObjects(configuration.request_header_map[@"X-Trace-Id"], @"abc123");
```

Add new classes to `SUITE` in the script and to the list above.

## Background: the bug this was written for

`NRMAHarvesterConfiguration` declared eight object-typed properties as `assign`. Under ARC
that means `unsafe_unretained` — the setter stores a raw pointer with no retain.
`initWithDictionary:` pointed them into the autoreleased dictionary it was parsing (the
`NRMAJSON` graph from the collector, or the `NSUserDefaults` graph for stored config),
while the configuration object itself lives in a strong ivar that far outlives that pool.
Every later read was a use-after-free, and it surfaced as `SIGSEGV` in `objc_msgSend` from
`-[NRMAHarvester transitionToConnected:]`.

The lesson worth keeping: the first attempt to fix it added an `isKindOfClass:` check
wrapped in `@try/@catch`. That cannot work. The type check is itself an `objc_msgSend` on
the dangling pointer, and `@catch` does not catch `SIGSEGV` — a segfault is a signal, not
an `NSException`. Defensive checks cannot rescue a pointer that is already invalid; only
ownership can. Under this suite that distinction is immediate: the guarded version traps,
the `copy` version passes.
