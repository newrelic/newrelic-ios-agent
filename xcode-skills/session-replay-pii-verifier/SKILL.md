---
name: session-replay-pii-verifier
description: "Use when verifying New Relic Session Replay masking redacts PII in the serialized frame on disk of any iOS app driven by the device-interaction skill — checking masked content is absent from the replay stream, auditing replay frames for leaked text/images, scouring an entire app screen-by-screen for masking leaks and frame fidelity gaps, or validating masking after a Session Replay change."
---
# Session Replay PII-Leak Verifier

TRIGGER when: user asks to verify Session Replay masking, check that PII is redacted/masked in replay, confirm masking works, audit replay frames for leaked text/images, or validate masking after a Session Replay code change — in any iOS app that embeds the New Relic agent.
DO NOT TRIGGER when: user asks about non-replay features, unit tests only, build-only requests, or UI changes unrelated to Session Replay masking.

This skill is app-agnostic. It hardcodes nothing about a specific test app: build coordinates and the masked screen are **discovered per run** (steps 0 and 1). The New Relic agent writes frames to the same on-disk location regardless of which app embeds it, so the read/assert protocol is identical everywhere.

**REQUIRED SUB-SKILL:** drive the app with `device-interaction`
(`xcode-skills/device-interaction/SKILL.md`) — `DeviceInteractionStartSession`,
`DeviceInteractionInstallAndRun`, `DeviceEventSynthesize`,
`DeviceInteractionEndSession`. Read the on-disk frame with `xcrun simctl`. No
other UI-driver is used.

---

## What this proves

Session Replay masks content **in-memory before serialization**: masked text becomes asterisks, masked images become a `#CCCCCC` CSS placeholder — inside the RRWeb frame, not on screen. The masked output is therefore invisible to a human but is written to disk as plaintext JSON before gzip+upload at:

    Documents/SessionReplayFrames/{sessionId}/frame_N.json

This skill reads that file and asserts masked PII is redacted and absent, while unmasked content survives verbatim (control group). It is the highest-stakes Session Replay failure (PII silently flowing into replays) and the one no consumer can eyeball.

## The masked/unmasked oracle

A real pass requires **both** directions to hold on the same screen:

- **Masked content** (PII, or anything the app marks for masking) must be redacted in the frame.
- **Unmasked content** (a control element known to be safe) must survive verbatim.

If everything is redacted, masking is *blanket*, not *selective* — and a blanket-redact run cannot distinguish working masking from a broken serializer that drops all content. So the target screen must contain at least one masked element and one unmasked control. Identify masked vs unmasked content by, in order of preference:

1. **Explicit masking markers** — New Relic's `nr-mask` / `nr-unmask` accessibility identifiers on the views (visible in the device-interaction hierarchy capture).
2. **Source masking config** — the app's Session Replay masking rules in code (masked classes / masked view selectors).
3. **Known-PII heuristic** — fields that obviously hold PII (password, credit card, SSN, email) are expected masked; static chrome/labels are expected unmasked.

If a screen has masked content but **no** unmasked control, you can still assert masked-redacted + leak-absent, but the selective-vs-blanket verdict is INCONCLUSIVE — say so.

## Protocol

### 0. Discover build coordinates
- **Workspace/project**: the `.xcworkspace` (preferred) or `.xcodeproj` at the repo root — `ls *.xcworkspace *.xcodeproj`.
- **Scheme**: the runnable app target's shared scheme — `xcodebuild -list -workspace <ws>`, or list `*.xcscheme` under `xcshareddata/xcschemes/`. Pick the app scheme, not framework/test schemes.
- **Bundle id**: `xcodebuild -showBuildSettings -workspace <ws> -scheme <scheme> | grep PRODUCT_BUNDLE_IDENTIFIER` — needed to locate the app container in step 3.
- **Simulator**: a booted simulator UDID — `xcrun simctl list devices booted`. `DeviceInteractionStartSession` selects the device; note the UDID it targets.

### 1. Arrange
- `DeviceInteractionStartSession` early (runs in the background). Pass a device identifier, or a bogus value to list available targets.
- `DeviceInteractionInstallAndRun` with the discovered workspace + scheme (this builds, installs, and launches). Use `commandLineArguments` / `environmentVariables` to enable Session Replay recording for the run if the app needs a flag — prefer these over editing the scheme.
- Capture the UI hierarchy + screenshot via `DeviceEventSynthesize` (empty `interactionCommand`). Navigate to a screen that satisfies the masked/unmasked oracle by tapping element **center coordinates** from the hierarchy (`DeviceEventSynthesize interactionCommand="t <cx> <cy>"`). If you don't know which screen masks content, scan the hierarchy for `nr-mask`/`nr-unmask` identifiers or PII-form screens (login, payment, profile, claim).

### 2. Capture ground truth
- `DeviceEventSynthesize` with an empty `interactionCommand` → UI hierarchy file (element labels, frames, center coords) + screenshot. This is the "what the user sees" record.
- Record the on-screen masked elements and the unmasked control element(s), by their text/label, so you can match them in the frame.

### 3. Read the serialized frame
- Resolve the app's data container on the simulator:
  `xcrun simctl get_app_container <udid> <bundle-id> data` → `<container>`.
- `ls "<container>/Documents/SessionReplayFrames"` → find the active session directory; read the latest `frame_N.json` with the Read tool (read immediately — frames prune/upload quickly).
- Parse the `type: 2` (full snapshot) event. Extract text nodes (id + textContent, skip `isStyle`), `<img>` tags + inline `style`, `<span>` overlays.
- If no frame exists or it was pruned: navigate away and back (tap the back-button center coords, then re-enter the screen) to force a fresh snapshot via `DeviceEventSynthesize`, then re-resolve the container and re-read.

### 4. Assert (all three must hold)
1. **Masked redacted** — each masked element resolves in the frame to asterisks (length-matched, no real characters). Masked image regions carry `#CCCCCC`, no base64.
2. **Leak-absent (negative)** — full-text search the frame JSON for the literal masked strings (the actual on-screen text of each masked element). They must appear **nowhere**.
3. **Control verbatim** — the unmasked control strings appear in the frame verbatim. (If these are also redacted, masking is blanket, not selective — report as INCONCLUSIVE.)

### 5. Report
Emit a table:

| Element | On screen | In frame | Expected | Verdict |

Flag any assertion-2 failure loudly as **PII LEAK** with the leaked string and frame node id. End with PASS / FAIL / INCONCLUSIVE. Close the session with `DeviceInteractionEndSession`.

## Scour mode (full-app sweep)

To audit an entire app rather than one screen, run the single-screen protocol across every navigable screen — no screen list is hardcoded; discover them at runtime.

1. **Enumerate screens.** From the launch screen, capture the hierarchy (`DeviceEventSynthesize`, empty command) and treat every navigable row/button/tab/cell as an edge. Visit depth-first: tap a target's center coords, capture, recurse into newly revealed screens, then return (tap the back-button center coords) and continue. Scroll (`t 200 600 f 200 200 0.3`) to reveal off-screen targets. Track visited screens by title/identity to avoid loops.
2. **Classify each screen.** Does it carry masked or PII-shaped content — any `nr-mask` marker, or fields like password / credit card / SSN / email?
   - **Yes** → run the masked/unmasked oracle (step 4 assertions 1–3).
   - **No** → run the PRESENT / PARTIAL / MISSING coverage comparison instead (CLAUDE.md Frame Verification Protocol, steps 3–4).
3. **Force a fresh frame per screen** (navigate away and back, then re-resolve the container) before reading — frames prune fast.
4. **Report** per screen (verdict table + one-line PASS / FAIL / INCONCLUSIVE), then an overall summary ordered: every **PII LEAK** first (leaked string + frame node id), then masking gaps, then fidelity gaps. Stay factual; do not propose fixes unless asked. `DeviceInteractionEndSession` when done.

## Known pitfalls

- **Frame pruning** — frames upload/prune quickly; read immediately or force a fresh snapshot (step 3 fallback).
- **Container UUID changes** — the data-container path changes on reinstall; re-resolve it with `simctl get_app_container` each run rather than caching the path.
- **Empty text fields** — text-field placeholders may not serialize; assert against rendered labels with known static text, not placeholders.
- **No unmasked control on screen** — you lose the selective-vs-blanket signal; downgrade the verdict to INCONCLUSIVE rather than reporting PASS.

## Recording mode

Session Replay must be in a recording mode that produces frames. If no frames appear in the container after navigating the screen, confirm recording is on — pass the enabling launch argument/environment variable via `DeviceInteractionInstallAndRun`, or check the app's runtime logs — before concluding FAIL.

## Example: this repo (NRTestApp)

Concrete coordinates that satisfy the discovery steps in the New Relic iOS agent repo, as one worked example:

- Workspace `Agent.xcworkspace`, scheme `NRTestApp`.
- Fixture screen: `Test Harness/NRTestApp/NRTestApp/ViewControllers/TextMaskingViewController.swift` ("Text Masking"), which renders **Masked Fields** and **Unmasked Fields** sections (driven by `nr-mask` / `nr-unmask` identifiers) plus a Credentials section — a built-in masked/unmasked oracle. Navigate: from the main menu, scroll down (`DeviceEventSynthesize interactionCommand="t 200 600 f 200 200 0.3"`) and tap the "Text Masking" row at its hierarchy center coords.
