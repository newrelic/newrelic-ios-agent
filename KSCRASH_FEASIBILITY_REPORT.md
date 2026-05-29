# Feasibility Report: Migrating the New Relic iOS Agent Crash Handler from PLCrashReporter to KSCrash

**Date:** 2026-05-29
**Author:** Investigation for New Relic iOS Agent
**Scope:** Replace PLCrashReporter (Microsoft fork, vendored as the `modular-crash-reporter-ios` submodule) with [KSCrash](https://github.com/kstenerud/KSCrash), with a focus on **on-device (offline) symbolicated crashes that are automatically uploaded to New Relic.**

---

## 1. Executive Summary

The New Relic iOS agent today uses PLCrashReporter to **capture** crashes and deliberately **does not symbolicate on device** (`PLCrashReporterSymbolicationStrategyNone`). All symbolication happens **server-side** at New Relic, against dSYM/"map" files uploaded at build time by `dsym-upload-tools/run-symbol-tool`. Crashes are already stored offline and uploaded on next launch / reachability.

KSCrash is a **functional superset** of PLCrashReporter and is the battle-tested core behind Sentry and Bugsnag. Its single most relevant feature for this initiative is **in-process (offline) symbolication** via an async-safe `dladdr` replacement, while still preserving the binary-image UUID + load address + slide needed for **offline re-symbolication** server-side. It is MIT-licensed (same class as PLCR), supports iOS/tvOS/**watchOS**/macOS, and is actively maintained (≈one release every 4–8 weeks through 2025–2026; current stable 2.5.1, 2.6.0 in beta).

**Key finding on the ask:** "Offline symbolicated crashes auto-sent to NR" is achievable, but on-device symbolication has hard limits worth understanding up front:
- **Your own app's frames only symbolicate on device if the app is built with Strip Style = "Debugging Symbols"** (not "All Symbols"), at a ~5% binary-size cost. Most App Store builds strip symbols, so app frames would otherwise resolve to `<redacted>`/nearest-export.
- **System library frames** only expose *exported* symbols on device; the OS redacts most.
- **Swift symbols come out mangled** and need KSCrash's `DemangleFilter` (or server demangling).

Therefore the realistic, highest-value model is **hybrid**: keep New Relic's server-side dSYM symbolication as the source of truth (KSCrash preserves everything needed for it), and add on-device symbolication as a **best-effort enhancement** that improves triage when dSYMs are missing/late, covers system/third-party frames, and gives partial readable traces with zero backend dependency.

**Recommendation:** Pursue a **time-boxed migration spike** (Option B below) behind a feature flag. The principal costs are (1) a crash-report **schema/parser rewrite** in the agent, (2) **re-validation of backtrace unwinding fidelity** (PLCR uses DWARF/compact-unwind; KSCrash uses frame-pointer walking), (3) **coexistence/namespacing hardening** for SDK embedding, and (4) a **binary-xcframework → from-source build** change. None are blockers.

---

## 2. Current State — How the Agent Does Crash Reporting Today

### 2.1 Components (`Agent/CrashHandler/`)

| File | Role |
|------|------|
| `NRMAExceptionHandlerManager.m` | Configures & installs `PLCrashReporter`; processes pending reports on launch; orchestrates upload; detects hijacked handlers; wires session-replay `hasReplay` attribute. |
| `NRMAUncaughtExceptionHandler.m` | Starts the reporter; guards against debugger / handler replacement; watchOS uses `NSSetUncaughtExceptionHandler` only. |
| `NRMACrashReportFileManager.m` | Loads pending `.plcrash` data, parses to `PLCrashReport`, reads NR metadata sidecar, invokes the writer. |
| `NRMACrashDataWriter.m` | **Converts `PLCrashReport` → New Relic's own JSON** (`NRMACrashReport`); writes to temp dir for upload. |
| `CrashReport/NRMACrashReport*.{h,m}` | New Relic's destination crash model (deviceInfo, appInfo, exception, threads, libraries w/ UUIDs, activityHistory, sessionAttributes, analyticsEvents). |
| `NRMACrashDataUploader.m` | Uploads JSON reports to the crash collector (`mobile-crash`); retry tracking via `NSUserDefaults`; 1 MB payload cap; stale-report eviction. |
| `ExceptionDataInterface/NRMAExceptionMetaDataStore.m` | **Async-signal-safe** `NRMA_writeNRMeta` callback that writes NR metadata at crash time using raw POSIX `open`/`write`/`close`. |

### 2.2 Configuration (the deliberate design choices)

From `NRMAExceptionHandlerManager.m`:
```objc
PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeBSD; // BSD in prod, MACH only for dev
PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc]
    initWithSignalHandlerType:signalHandlerType
        symbolicationStrategy:PLCrashReporterSymbolicationStrategyNone]; // NO on-device symbolication
callback.handleSignal = NRMA_writeNRMeta; // async-safe sidecar metadata writer
```
Two explicit decisions, with the original rationale captured in code comments:
1. **BSD signal handler** (not Mach) — "tried and true vs MACH … recommended to use BSD in production."
2. **No runtime symbolication** — "We don't want to attempt to symbolicate at runtime due to the possibility of stack corruption as well as it being inaccurate. Let's save it for the server where we have the dsym files!"

### 2.3 Lifecycle / data flow (today)

```
                          ┌─────────────────────────── CRASH TIME (async-safe) ──────────┐
  app running ──► crash ──► PLCrashReporter BSD handler writes .plcrash protobuf          │
                          │ NRMA_writeNRMeta() writes metadata.nr.crash (POSIX open/write)│
                          └──────────────────────────────────────────────────────────────┘
                                          │ (process dies)
                          ┌──────────────── NEXT LAUNCH ─────────────────────────────────┐
  startHandler... ──► hasPendingCrashReport? ──► load .plcrash ──► PLCrashReport          │
                          │ read metadata.nr.crash ──► NRMACrashDataWriter                │
                          │   convert → NRMACrashReport JSON (addrs + UUIDs, NOT symbols) │
                          │   write JSON to NSTemporaryDirectory()/.../*.crash            │
                          └───────────────────────────────────────────────────────────────┘
                                          │ reachability OK?
  NRMACrashDataUploader ──► POST JSON to mobile-crash collector ──► remove local file
                                          │
  (build-time, separate)  run-symbol-tool ──► upload dSYM/map to mobile-symbol-upload.newrelic.com
                                          │
  NR backend: match report library UUID + load addr ──► symbolicate against stored dSYM/map ──► readable stack
```

### 2.4 What "offline" already means today, and the actual gap

- **Offline storage:** Already solved. Reports persist to disk and upload when reachable; there's retry tracking and stale eviction. The recent `NR-548419` work added offline storage for Mobile Session Replay, and crash handling already checks reachability before upload.
- **Offline *symbolication*:** **Not done on device.** The agent ships *unsymbolicated* reports (addresses + image UUIDs) and relies on NR's backend + uploaded dSYMs. This is correct and accurate, but means:
  - If a dSYM/map was never uploaded (or is delayed), the stack stays unsymbolicated.
  - No human-readable frame is ever available client-side (e.g., for local debugging or on-device display).
  - System/third-party frames depend entirely on what the backend can resolve.

**This is exactly the gap KSCrash's on-device symbolication addresses.**

### 2.5 Packaging

- PLCrashReporter is a **git submodule** (`modular-crash-reporter-ios` → `github.com/microsoft/plcrashreporter`), built from source into the agent. (Note: it is a build dependency of the agent; the *distributed* NewRelic.xcframework is a binary — see `Package.swift` / `NewRelicAgent.podspec`.)
- watchOS does **not** link PLCrashReporter — it degrades to `NSSetUncaughtExceptionHandler` (NSException only; no signal/Mach crashes captured).

---

## 3. KSCrash Overview

| Dimension | PLCrashReporter 1.12.0 (current) | KSCrash 2.5.1 |
|---|---|---|
| License | MIT | MIT |
| Distribution | Source submodule (SPM/CocoaPods/Carthage; also prebuilt xcframework) | Source via SPM / CocoaPods (no Carthage) |
| Platforms / min | iOS 12, tvOS 12, macOS 11.5 | iOS 12, tvOS 12, **watchOS 5**, macOS 10.14 |
| Report format | Protobuf (`.plcrash`) | **JSON-native** (+ optional Apple `.crash` text via filter) |
| Stack unwinding | **DWARF + Apple Compact Unwind** (most accurate) | Frame-pointer / `KSStackCursor`-based |
| On-device symbolication | No (by design) | **Yes** (async-safe `ksdl_dladdr`) |
| Re-symbolication offline (server) | Yes (UUID + addr) | **Yes** (UUID + image_addr + image_vmaddr + slide) |
| C++ exception cause | No | **Yes** (typed name/reason/throw site) |
| NSException name/reason/userInfo | Limited | **Yes** |
| Zombie / deadlock / OOM hints | No | Yes (deadlock experimental; OOM hint-based) |
| Swift demangling | Not built-in | **Yes** (`DemangleFilter`) |
| Custom in-crash data | Limited | Rich JSON writer + `userInfo` |
| SDK embedding / symbol namespacing | n/a | **First-class** (`KSCrashNamespace.h`) |
| Maintainer | Microsoft App Center (retired product) | Community (active), original-author bus-factor caveat |

### 3.1 Module structure (SPM)
`Recording` (async-safe C capture) → `Reporting` = `Filters` + `Sinks` + `Installations` (turnkey) → optional `DemangleFilter` (C++ **and Swift**), `DiscSpaceMonitor`, `BootTimeMonitor`. Internal cores: `KSCrashRecordingCore`, `KSCrashReportingCore` (links libz), `KSCrashCore`.

### 3.2 Detection coverage (monitors, bit-flagged)
Mach exceptions (incl. **stack overflow** via guard-page handling), POSIX signals, **C++ exceptions with recovered type/message**, **NSException with name/reason/userInfo**, main-thread deadlock (experimental, off by default), user-reported/custom, zombie access, **OOM/memory-termination hints**, plus system/app-state context. Convenience sets: `Fatal`, `AsyncSafe` (Mach+Signal), `ProductionSafe`, `DebuggerSafe`.

### 3.3 Async-signal safety (the hard part)
- Recording layer is **pure async-safe C** (no malloc, no ObjC, no locks in the crash path; from-scratch JSON writer; custom memory-readability probing).
- **Mach exceptions handled on dedicated handler threads** (two: Primary + Secondary), not inside a signal handler. The secondary handler catches a crash-while-handling-a-crash, producing a nested `recrash_report`.
- **Handler chaining:** saves prior exception ports and restores/forwards, designed to coexist with other handlers.

### 3.4 Maintenance & adoption
Steady cadence (2.0.0 Mar 2025 → 2.5.1 Jan 2026, 2.6.0-beta May 2026). ~4.5k stars; recent releases cut by maintainer `naftaly`. KSCrash is the **ancestor of Sentry-cocoa and Bugsnag's iOS reporters** — strong validation. Caveat: original author's "call for help" notice remains; bus-factor is a real but improving risk.

---

## 4. The Core Question — On-Device (Offline) Symbolication

### 4.1 How KSCrash does it
KSCrash ships its own async-safe `ksdl_dladdr()` (in `KSDynamicLinker.c`) because the system `dladdr` is **not** async-signal-safe. At crash time, for each instruction address it:
1. Walks a cached list of loaded Mach-O images to find the containing image.
2. Computes the VM slide from the `__TEXT` segment and `LINKEDIT` base.
3. Walks the image's `LC_SYMTAB` symbol table (skipping `N_STAB` debug entries) to find the nearest preceding symbol and reads its name.

Crucially, every binary-image record also stores **`image_addr`, `image_vmaddr`, `image_size`, `uuid`, cpu type/subtype** — i.e. everything required for **offline re-symbolication** against dSYMs server-side. So on-device symbols and server-side symbolication are **not mutually exclusive**; KSCrash gives both.

### 4.2 The limits you must design around
| Limitation | Impact | Mitigation |
|---|---|---|
| App's own symbols are stripped in release | Your app frames resolve to nearest export / `<redacted>` on device | Either (a) ask customers to set **Strip Style = Debugging Symbols** (~5% size), or (b) keep server-side dSYM symbolication as primary and treat on-device as best-effort. **(b) is recommended for an embedded SDK.** |
| System libs expose only exported symbols; OS redacts most | Partial system frames on device | Server-side symbolication via NR's symbol service / Apple symbol sets remains better for system frames |
| Swift names are mangled | `$s…` gibberish in raw on-device output | Run KSCrash `DemangleFilter`, or demangle server-side |
| Frame-pointer unwinder vs PLCR DWARF/compact-unwind | Slightly less accurate traces in heavily optimized / no-frame-pointer code | Validate on a real crash corpus; arm64 with frame pointers is usually fine |

### 4.3 What this unlocks for New Relic
- **Resilience when dSYMs are missing/late:** partial readable traces even before/without dSYM upload.
- **System & third-party frames** that the backend may not resolve.
- **Faster triage** and the option to display readable traces client-side.
- **watchOS crash capture** (currently absent) comes along for free.
- No regression to the existing accurate path — server symbolication still works because UUID/addr/slide are preserved.

---

## 5. Migration Options

### Option A — Drop-in replacement, server-side symbolication only (lowest risk)
Replace PLCR with KSCrash but keep `monitors = [.machException, .signal]` and **do not** enable on-device symbolication. Map KSCrash JSON → existing `NRMACrashReport` JSON. Net effect: same data shape as today, broader detection (NSException/C++ cause, OOM hints, watchOS), JSON-native.
- **Pros:** Smallest backend impact; no Strip-Style ask of customers; immediate detection gains.
- **Cons:** Doesn't deliver the headline "offline symbolicated crashes" ask.

### Option B — Hybrid: server symbolication primary + on-device best-effort (recommended)
Option A **plus** enable on-device symbolication and ship symbol names *when present* alongside raw addresses + UUIDs. Backend prefers dSYM symbolication; falls back to / augments with client symbols. Add `DemangleFilter` for Swift.
- **Pros:** Delivers the ask; graceful degradation; no customer build change *required* (better results if they enable Debugging Symbols strip style); watchOS coverage.
- **Cons:** Backend ingestion must accept optional client symbols; two code paths to test.

### Option C — Full on-device symbolication, reduce server dependency (highest ambition)
Push for customers to build with Debugging Symbols strip style and treat client symbols as primary, server as fallback.
- **Pros:** Maximal offline capability; least backend coupling.
- **Cons:** Requires customer build-config change + docs; size cost; weakest for system frames. Not recommended as the default.

---

## 6. Migration Work Breakdown (Option B)

### 6.1 Packaging / build
- Add KSCrash as a submodule or SPM dependency; **namespace symbols** via `KSCrashNamespace.h` (e.g., `NewRelic` prefix) to avoid collisions with host apps that also embed KSCrash (Sentry/Bugsnag) — **mandatory for an embedded SDK**.
- Remove `modular-crash-reporter-ios` submodule and `.gitmodules` entry once parity is proven.
- Verify static-lib / xcframework packaging still links (KSCrash is mixed C/ObjC/C++/Swift, `gnu++11`, links libz).

### 6.2 Code changes (file-by-file)
| Current | Change |
|---|---|
| `NRMAExceptionHandlerManager.m` | Replace `PLCrashReporter`/`PLCrashReporterConfig` with `KSCrash` install + `KSCrashConfiguration.monitors`. Keep the pending-report-on-launch flow, hijack detection, session-replay `hasReplay` wiring, reachability gating. |
| `NRMAUncaughtExceptionHandler.m` | Replace PLCR enable/handler-validation. Decide whether to keep debugger-attached guard (KSCrash has `DebuggerSafe` sets). watchOS can now use real KSCrash instead of NSException-only. |
| `NRMACrashReportFileManager.m` | Replace `.plcrash` load/parse with reading KSCrash JSON report store. |
| `NRMACrashDataWriter.m` | **Largest change:** map KSCrash JSON schema (`crash.threads[].backtrace[]`, `crash.error.{mach,signal,cpp_exception,nsexception}`, `binary_images[]` w/ `image_addr`/`image_vmaddr`/`uuid`, `system`, `app_memory`) → `NRMACrashReport`. Carry optional `symbol_name` when present. |
| `NRMA_writeNRMeta` (metadata store) | KSCrash exposes a crash-time `KSCrashReportWriter` C API and `userInfo`. **Prefer migrating NR metadata into the KSCrash report via the writer/`userInfo`** rather than a separate sidecar — simplifies the pipeline and removes the bespoke async-safe file writer. (Keep async-safety constraints in mind.) |
| `NRMACrashDataUploader.m` | Largely unchanged — still uploads NR JSON to `mobile-crash`. |
| `NRMACrashReport*` model | Unchanged shape if we keep the NR wire format stable; optionally extend with symbol fields. |

### 6.3 Backend / pipeline
- Confirm `mobile-crash` ingestion still accepts the (unchanged) NR JSON wire format; that minimizes backend work.
- For Option B, allow optional client-provided `symbol_name` per frame; ensure server symbolication still overrides/augments via UUID + addr.
- `dsym-upload-tools/run-symbol-tool` is **unaffected** — KSCrash preserves UUID/addr/vmaddr, so existing dSYM/map upload + server symbolication keeps working.

### 6.4 Testing
- Port/replace `NRMACrashReportTest.m` and `NRUncaughtExceptionhandlerTests.m`.
- Crash corpus on device + simulator across signal types (SIGSEGV/SIGABRT/SIGBUS/SIGILL/SIGTRAP), NSException, C++ throw, stack overflow, OOM.
- **Unwinding fidelity A/B** vs PLCR on identical crashes (this is the key risk to retire).
- Coexistence test: install alongside Sentry/Bugsnag/Crashlytics; verify handler chaining + namespacing; confirm the existing "exception handler hijacked" metric still fires correctly.
- watchOS crash capture (new capability).

---

## 7. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Backtrace fidelity regression (frame-pointer vs DWARF/compact-unwind) | **High** | A/B on real crash corpus before cutover; gate behind feature flag; keep PLCR path available during ramp. |
| Report-schema rewrite bugs (mis-mapped frames/images) | High | Keep NR wire format stable; golden-file tests comparing PLCR-derived vs KSCrash-derived NR JSON. |
| Multiple crash reporters in one process (handler contention) | Medium | Symbol namespacing + verify KSCrash handler chaining; test with common 3rd-party reporters; preserve hijack-detection metric. |
| On-device symbols misleading when app is stripped | Medium | Default to Option B (server primary); document Strip-Style guidance; never present nearest-export as authoritative. |
| Async-safety violation via writer callbacks (ObjC/alloc in crash path) | Medium | Honor KSCrash plan-aware callback `asyncSafety`; keep crash-path code pure C. |
| Build/packaging churn (from-source mixed C/C++/Swift, libz) | Medium | Spike the SPM + xcframework build early; CI matrix iOS/tvOS/watchOS/macOS. |
| Maintainer bus-factor | Low-Med | MIT license → can vendor/fork; broad downstream adoption reduces risk. |
| Customer App Store builds strip symbols | Low | Expected; server-side symbolication remains primary. |

---

## 8. Effort & Phasing (rough)

1. **Spike (1–2 wks):** Embed namespaced KSCrash; capture a crash; produce KSCrash JSON; build on all 4 platforms. Validate unwinding A/B on a small corpus. *Go/no-go on fidelity.*
2. **Pipeline (2–3 wks):** Rewrite `NRMACrashDataWriter` mapping + file manager; migrate NR metadata into KSCrash report; keep wire format stable; port tests.
3. **On-device symbolication (1–2 wks):** Enable symbolication + `DemangleFilter`; thread optional symbol fields through; backend accepts/augments.
4. **Hardening (2 wks):** Coexistence, watchOS, offline/reachability paths, retry/stale logic, payload caps, supportability metrics.
5. **Rollout:** Feature-flagged; ramp with PLCR fallback; monitor crash-volume + symbolication-rate parity dashboards before full cutover.

**Order-of-magnitude:** ~8–10 engineering weeks to confident cutover, dominated by the writer/mapping rewrite and fidelity validation.

---

## 9. Open Questions (need answers before committing)

1. **Backend contract:** Can `mobile-crash` ingestion stay on the current NR JSON wire format (minimizing backend work), and can it accept optional client-supplied symbol names for Option B?
2. **Unwinding fidelity bar:** What regression (if any) in symbolicated-frame accuracy is acceptable vs PLCR's DWARF/compact-unwind?
3. **Strip-Style guidance:** Are we willing to document/recommend Debugging-Symbols strip style to customers to improve on-device symbol coverage, or keep server symbolication strictly primary?
4. **watchOS:** Is real crash capture on watchOS in scope (KSCrash enables it; today it's NSException-only)?
5. **OOM:** Do we want KSCrash's hint-based OOM/memory-termination reporting surfaced as a new NR event type?
6. **Coexistence policy:** Official stance when a host app also bundles Sentry/Bugsnag/Crashlytics (last-installer-wins vs chaining)?

---

## 10. Bottom Line

KSCrash is a **viable, license-compatible, actively-maintained, broadly-validated** replacement that is a superset of PLCrashReporter's detection and — uniquely for this initiative — provides **on-device symbolication that still preserves offline server-side re-symbolication.** The recommended path is **Option B (hybrid)** behind a feature flag: keep New Relic's accurate server-side dSYM symbolication as the source of truth, add on-device symbols as a resilience/triage enhancement, and pick up watchOS + richer exception detection along the way.

The migration is **feasible**. The real work is a crash-report **schema/parser rewrite**, **unwinding-fidelity validation**, **namespacing/coexistence hardening**, and a **from-source build** change — all manageable and best de-risked with an upfront fidelity spike.
