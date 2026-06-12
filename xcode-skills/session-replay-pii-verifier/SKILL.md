---
name: session-replay-pii-verifier
description: "Verify New Relic Session Replay masking redacts PII in the serialized frame on disk, using Pepper to drive NRTestApp. Proves masked content never leaks into the replay stream."
---
# Session Replay PII-Leak Verifier

TRIGGER when: user asks to verify Session Replay masking, check that PII is redacted/masked in replay, confirm masking works, audit replay frames for leaked text/images, or validate masking after a Session Replay code change.
DO NOT TRIGGER when: user asks about non-replay features, unit tests only, build-only requests, or UI changes unrelated to Session Replay masking.

---

## What this proves

Session Replay masks content **in-memory before serialization**: masked text becomes asterisks, masked images become a `#CCCCCC` CSS placeholder — inside the RRWeb frame, not on screen. The masked output is therefore invisible to a human but is written to disk as plaintext JSON before gzip+upload at:

    Documents/SessionReplayFrames/{sessionId}/frame_N.json

This skill reads that file and asserts masked PII is redacted and absent, while unmasked content survives verbatim (control group). It is the highest-stakes Session Replay failure (PII silently flowing into replays) and the one no consumer can eyeball.

## Build coordinates (verified 2026-06-12)

- Workspace: `Agent.xcworkspace`
- Scheme: `NRTestApp`
- Simulator: iPhone 17 Pro Max — `AEE66BA5-E99F-487C-8A6C-F9BE8B6A7CE4`

## Fixture

`Test Harness/NRTestApp/NRTestApp/ViewControllers/TextMaskingViewController.swift` ("Text Masking" screen). It renders **Masked Fields** and **Unmasked Fields** sections from deterministic static text, driven by `nr-mask` / `nr-unmask` accessibility identifiers, plus a Credentials section (Password / Credit Card / CVV). The masked/unmasked symmetry is a built-in oracle: a real pass requires masked text redacted AND unmasked text intact.

## Protocol

### 1. Arrange
- `app_build` workspace `Agent.xcworkspace`, scheme `NRTestApp`, onto the booted simulator. This replaces `DeviceInteractionInstallAndRun`.
- `app_look` to confirm launch. Navigate to **Text Masking**: from the main menu scroll down and `ui_tap text="Text Masking"`.

### 2. Capture ground truth
- `app_look visual=true verbose=true` — screenshot + structured element list.
- `ui_query find predicate="visible == YES"` — accessibility tree with coordinates/types.
- Record the on-screen masked labels (`Masked Fields UILabel 1..4`) and unmasked labels (`Unmasked Fields UILabel 1..4`).

### 3. Read the serialized frame
- `state_tools sandbox action=list path="Documents/SessionReplayFrames"` → find the active session directory.
- List that directory, read the latest `frame_N.json` (`state_tools sandbox action=read`).
- Parse the `type: 2` (full snapshot) event. Extract text nodes (id + textContent, skip `isStyle`), `<img>` tags + inline `style`, `<span>` overlays.
- If no frame exists or it was pruned: navigate away (`nav_back`) and back to the screen to force a fresh snapshot, then re-read.

### 4. Assert (all three must hold)
1. **Masked redacted** — each `Masked Fields UILabel N` resolves in the frame to asterisks (length-matched, no real characters). Masked image regions carry `#CCCCCC`, no base64.
2. **Leak-absent (negative)** — full-text search the frame JSON for the literal masked strings (`"Masked Fields UILabel 1"`, etc.). They must appear **nowhere**.
3. **Control verbatim** — `Unmasked Fields UILabel N` strings appear in the frame verbatim. (If these are also redacted, masking is blanket, not selective — report as INCONCLUSIVE.)

### 5. Report
Emit a table:

| Element | On screen | In frame | Expected | Verdict |

Flag any assertion-2 failure loudly as **PII LEAK** with the leaked string and frame node id. End with PASS / FAIL / INCONCLUSIVE.

## Known pitfalls (this codebase)

- **Frame pruning** — frames upload/prune quickly; read immediately or force a fresh snapshot (step 3 fallback).
- **Empty text fields** — text-field placeholders may not serialize; assert against the UILabels (known static text), not placeholders.
- **Pepper layer-walk crash** — `ElementDiscoveryBridge.walkLayerTree` can EXC_BREAKPOINT on complex animation layers. The Text Masking screen is plain UIKit and is safe; if a crash occurs, fall back to `sim_raw cmd=tap params={"text":"...","skip_look":true}` + simctl screenshots.

## Recording mode

Session Replay must be in a recording mode that produces frames. If no frames appear in the sandbox after navigating the screen, confirm recording is on (check `state_vars` for the Session Replay manager mode, or app launch args) before concluding FAIL.
