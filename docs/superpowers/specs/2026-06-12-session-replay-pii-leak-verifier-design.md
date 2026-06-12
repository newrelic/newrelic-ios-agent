# Session Replay PII-Leak Verifier — Design Spec

**Date:** 2026-06-12
**Context:** AI-First Acceleration 2026 hackathon, 1-day MVP (code freeze 3:55pt)
**Status:** Approved design, pre-implementation

## One-sentence pitch

A Claude skill that drives the NRTestApp with Pepper, reads the serialized
Session Replay frame off disk, and proves automatically that masked PII never
appears in the replay stream — something no human can verify by eye.

## Problem

Session Replay masking happens **in-memory before serialization**. Masked
content is replaced with asterisks (text) or a `#CCCCCC` CSS placeholder
(images) *inside the RRWeb frame*, not on screen. A consumer who enables
masking sees no on-screen difference and cannot confirm masking actually
worked. A regression that leaks unredacted PII into the frame is therefore
**silent** — it ships to New Relic invisibly. This is the highest-stakes
Session Replay failure (compliance incident) and the one least observable by a
human.

## Why this is observable (the unfair advantage)

The capture pipeline is:

```
view tree → mask in-memory → serialize to plaintext JSON on disk → gzip → POST to NR
```

Frames land at `Documents/SessionReplayFrames/{sessionId}/frame_N.json` as
**plaintext JSON before gzip/upload**. Pepper can read the app sandbox
directly (`state_tools sandbox`). So the masked output — invisible on screen —
is fully readable on disk. The verifier asserts against that file.

## Fixture (reused, no new app code)

`Test Harness/NRTestApp/NRTestApp/ViewControllers/TextMaskingViewController.swift`
already renders the ideal oracle:

- **Masked** and **Unmasked** sections side by side, both built from
  deterministic static text: `"Masked Fields UILabel 1..4"`,
  `"Unmasked Fields UILabel 1..4"`.
- Masking driven by accessibility identifiers `nr-mask` / `nr-unmask`.
- A Search & Credentials section with realistic PII placeholders (Password,
  Credit Card Number, CVV — `isSecureTextEntry` + `nr-mask`).

The masked/unmasked symmetry is a built-in control group: a pass requires
masked text to be redacted **and** unmasked text to survive verbatim, so the
check cannot trivially pass by redacting everything or nothing.

## Architecture

A single Claude skill (`.md` + verification protocol). **No agent or test-app
code changes.** The skill orchestrates Pepper tools in five steps.

### Step 1 — Arrange
- `app_build` the NRTestApp workspace onto a booted simulator and launch.
- Ensure Session Replay is recording (full mode) for the run.
- Navigate to the **Text Masking** screen via `nav_go` / `ui_tap`.

### Step 2 — Capture ground truth
- `app_look visual=true verbose=true` → screenshot + structured element list.
- `ui_query find predicate="visible == YES"` → accessibility tree with
  coordinates and types.
- Record the on-screen text for masked and unmasked labels.

### Step 3 — Read the serialized frame
- `state_tools sandbox` list `Documents/SessionReplayFrames/` → find the active
  session directory and latest `frame_N.json`.
- Read the frame JSON. Parse the type=2 (full snapshot) event. Extract:
  - text nodes (id + textContent, excluding `isStyle` nodes),
  - `<img>` tags and their inline `style`,
  - `<span>` overlays.
- If the frame was already pruned, force a fresh snapshot by navigating away
  and back, then re-read.

### Step 4 — Assert (core)
Three assertions against the disk frame:

1. **Masked content redacted.** Every "Masked Fields …" UILabel resolves in
   the frame to asterisks (length-matched). Masked image regions carry the
   `#CCCCCC` placeholder CSS, not base64 image data.
2. **Negative / leak check.** The literal masked source strings
   (`"Masked Fields UILabel 1"`, etc.) appear **nowhere** in the frame JSON
   (full-text search of the serialized file).
3. **Control passes.** The "Unmasked Fields …" UILabel strings appear
   **verbatim** in the frame — proving masking is selective and the check has
   teeth.

A pass requires all three. Assert against **UILabels** (known static text),
not text-field placeholders (which may not serialize).

### Step 5 — Report
Emit a pass/fail table (per the existing CLAUDE.md verification protocol):

| Element | On screen | In frame | Expected | Verdict |

Any leak (assertion 2 fails) is flagged loudly as a FAIL with the leaked string
and its frame node id.

## Failure mode caught

A regression where a masked label's text leaks unredacted into the frame —
invisible on screen, silently uploaded to New Relic. The skill converts that
into a red FAIL line with the offending string.

## Out of scope (explicitly cut for the MVP)

Listed in the skill as "next layers" so the roadmap is visible without being
built:

- Network-upload confirmation (idea #2: assert a gzipped blob POSTed).
- Recording-mode / `transitionToFullModeOnError` buffer-flush (idea #3).
- Touch / interaction fidelity (idea #4).
- SwiftUI masking-coverage regression guard (idea #5).

## Risks / mitigations

- **Frames pruned before read** → trigger a fresh snapshot (navigate away +
  back) then re-read.
- **Pepper `walkLayerTree` crash on complex layers** (EXC_BREAKPOINT noted on
  animation screens) → the Text Masking screen is plain UIKit; if it bites,
  fall back to `sim_raw` tap + simctl screenshot.
- **Empty text fields not serialized** → assert against UILabels with known
  static text, not placeholders.

## Success criteria

1. The skill runs end-to-end against a freshly built NRTestApp and produces a
   pass/fail report without manual intervention.
2. With masking working correctly, all three assertions pass.
3. When masking is broken (e.g., temporarily disable `nr-mask` handling, or
   point at the unmasked section as if it were masked), the negative check
   FAILS — demonstrating the skill detects a real leak.

## Deliverable

A reusable Claude skill committed to the repo that any engineer or CI run can
invoke to verify Session Replay masking on demand. Framed as AI-first
acceleration of QA / compliance verification work that is otherwise unautomated
and un-eyeballable.
