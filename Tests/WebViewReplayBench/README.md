# WebView session replay bench

Compares the two WebView session replay approaches on the same workloads:

| | `webview-msr-poc` (graft) | `two-streams-webview-msr` (plugin) |
|---|---|---|
| Recorder in the page | standalone rrweb 2.1.6 (`evaluateJavaScript`) | browser agent in observation mode (`<script>` from js-agent.newrelic.com) |
| Pages with their own NR agent | recorded | skipped |
| Bridge cadence | 1s, documents immediately | agent harvest, 5s |
| Native ingest | parse, remap every node ID, re-serialize | parse, strip `__*`, re-serialize |
| Player | stock rrweb | `nr-webview-replay` plugin (nested Replayer) |

## Offline bench (native cost)

```sh
./build.sh                      # one binary per branch, from committed sources via `git show`
./run.sh                        # ingest, harvest, peak memory -> results/<date>-<poc rev>-<two rev>/
./report-phase0.py results/<run> > results/<run>/REPORT.md
```

- `build.sh` reads `Agent/SessionReplay/WebView/*` and the agent's gzip from each branch tip, so it
  runs from any checkout and local edits never leak in. Pin with `POC_REF=<rev>` / `TWO_REF=<rev>`.
- Every result record carries `variant`, `branch` and `rev`.
- Fixtures are synthetic (`Fixtures.swift`), in both bridge payload shapes: `agent` (each event
  carries the browser agent's `__serialized` copy) and `rrweb` (bare events).
- Timings are from whatever Mac runs it; a low-end iPhone is several times slower.

## On-device scenario (`app/`)

`app/scenario.sh <out-dir>` drives NRTestApp (launched with `-NRCaptureMode`) through the WebView
screens with `pepper-ctl`, sampling app and WebContent CPU/RSS and collecting the uploaded chunks
from `Documents/NRCapture/`. `UDID=` picks the simulator (default: the booted one).
`app/compare.py <run-dir>...` tabulates runs side by side. Put run output in `app/runs/` (ignored).

## Status

- [x] **Phase 0 -- baseline.** `results/20261006-1407-bacb86a9-ac0f1978/REPORT.md`. Findings:
  - The browser agent aborts session replay for the rest of the session (`TOO_BIG`, persisted to
    session storage) once a harvest gzips past `MAX_PAYLOAD_SIZE = 1e6`. In the experimental build
    the check runs after `beforeHarvest`, so native gets that one oversized payload and nothing after.
    Two-streams therefore stops recording pages whose snapshot gzips past 1 MB (about a 5.2 MB
    snapshot at the synthetic fixtures' ratio). The standalone recorder has no such cap.
  - The POC's remap costs about 2.3x the CPU and 2x the peak memory per document of two-streams'
    envelope wrap (large page, M3 Max: 89 ms / +23 MB vs 39 ms / +11 MB).
  - Chunk building and encoding are close; both hit the 1 MB chunk cap at the same native activity.
  - Iframe moves: the POC re-attaches the document at each one, two-streams ignores them. Whether
    two-streams then shows a blank WebView is a Phase 4 question.
- [ ] **Phase 1 -- realistic corpus.** ~12 real multi-MB pages recorded with mitmproxy and replayed
  deterministically; plus SingleFile static snapshots for 5-20 MB documents.
- [ ] **Phase 2 -- real fixtures.** Capture each branch's real bridge payloads from those pages
  (Playwright WebKit with a stubbed `window.webkit.messageHandlers`) and feed them to this bench;
  run the same code as XCTest `measure` tests on a low-end iPhone.
- [ ] **Phase 3 -- end-to-end on device.** Launch-argument-driven bench screen, identical signposts
  in both branches, app/WebContent/in-page/bridge/upload metrics against no-agent baselines.
- [ ] **Phase 4 -- replay fidelity.** `WKWebView.takeSnapshot` ground truth vs headless replay of
  the uploaded chunks (SSIM), plus orphaned-event and blank-time counts.
  - **TODO:** the `nr-webview-replay` player plugin, needed to replay two-streams chunks, is still
    to be supplied.
- [ ] **Phase 5 -- large-page stress.** Documents over the chunk cap, buffer overflow on a stalled
  harvest, several heavy WebViews, SPA route churn, memory pressure.
