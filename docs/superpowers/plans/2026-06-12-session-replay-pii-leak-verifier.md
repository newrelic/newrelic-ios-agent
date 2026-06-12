# Session Replay PII-Leak Verifier — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a reusable Claude skill that drives NRTestApp with Pepper, reads the serialized Session Replay frame off disk, and proves masked PII is absent from the replay stream.

**Architecture:** A markdown skill (`xcode-skills/session-replay-pii-verifier/SKILL.md`) following the repo's existing `device-interaction` convention, but using Pepper tools (`app_build`, `app_look`, `ui_tap`, `nav_go`, `state_tools sandbox`) instead of the `DeviceInteraction*` family. The skill encodes a 5-step protocol: arrange → capture ground truth → read frame JSON → assert (redacted / leak-absent / control-verbatim) → report. No agent or test-app code changes; the existing `TextMaskingViewController` is the fixture.

**Tech Stack:** Pepper MCP (simulator automation), New Relic iOS agent Session Replay (RRWeb frames on disk), NRTestApp test harness, Xcode/`xcodebuild`.

**Build coordinates (verified 2026-06-12):**
- Workspace: `Agent.xcworkspace`
- Scheme: `NRTestApp`
- Simulator: iPhone 17 Pro Max — `AEE66BA5-E99F-487C-8A6C-F9BE8B6A7CE4` (booted)

**Note on "tests":** The deliverable is a skill, not library code, so there are no unit tests. Verification is the **live run** against NRTestApp (Task 3) — the same run the user wants to set up. A "passing test" = the skill runs end-to-end and its three assertions resolve correctly, including a deliberately seeded leak that the skill must FAIL on.

---

## File Structure

- Create: `xcode-skills/session-replay-pii-verifier/SKILL.md` — the verifier skill (sole deliverable).
- Create: `CLAUDE.md` (project root) — screen map + verification protocol + verified-screen references (preserved from the existing draft) + a pointer to the new skill.
- Already created: `docs/superpowers/specs/2026-06-12-session-replay-pii-leak-verifier-design.md` — the approved spec.

---

## Task 1: Create the verifier skill

**Files:**
- Create: `xcode-skills/session-replay-pii-verifier/SKILL.md`

- [ ] **Step 1: Write the skill file**

Frontmatter + TRIGGER block matching the `device-interaction` convention, then the 5-step protocol. Full content:

```markdown
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

This skill reads that file and asserts masked PII is redacted and absent, while unmasked content survives verbatim (control group).

## Fixture

`Test Harness/NRTestApp/NRTestApp/ViewControllers/TextMaskingViewController.swift` ("Text Masking" screen). It renders **Masked Fields** and **Unmasked Fields** sections from deterministic static text, driven by `nr-mask` / `nr-unmask` accessibility identifiers, plus a Credentials section (Password / Credit Card / CVV).

## Protocol

### 1. Arrange
- `app_build` workspace `Agent.xcworkspace`, scheme `NRTestApp`, onto the booted simulator. This replaces `DeviceInteractionInstallAndRun`.
- `app_look` to confirm launch. Navigate to **Text Masking**: from the main menu scroll down and `ui_tap text="Text Masking"` (or `nav_go` if a deeplink exists).

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
3. **Control verbatim** — `Unmasked Fields UILabel N` strings appear in the frame verbatim. (If these are also redacted, masking is blanket, not selective — report as inconclusive.)

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
```

- [ ] **Step 2: Verify the file is well-formed**

Run: `head -5 xcode-skills/session-replay-pii-verifier/SKILL.md`
Expected: YAML frontmatter with `name:` and `description:`.

- [ ] **Step 3: Commit**

```bash
git add xcode-skills/session-replay-pii-verifier/SKILL.md
git commit -m "Add Session Replay PII-leak verifier skill"
```

---

## Task 2: Create project CLAUDE.md preserving references

**Files:**
- Create: `CLAUDE.md` (project root)

- [ ] **Step 1: Write CLAUDE.md**

Preserve the existing draft's reference material verbatim — the NRTestApp screen map, the Session Replay Frame Verification Protocol, and both Verified Screen catalogs (Animations & Transitions, NavigationDestination MSR) including the Pepper compatibility note. Prepend a short pointer to the new skill:

```markdown
## Session Replay verification
For PII masking verification, use the `session-replay-pii-verifier` skill
(`xcode-skills/session-replay-pii-verifier/SKILL.md`). It drives NRTestApp with
Pepper and asserts masked content is redacted in the on-disk RRWeb frame.
```

(The full screen map, protocol, and verified-screen sections from the existing draft follow unchanged.)

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "Add CLAUDE.md: NRTestApp screen map, SR verification protocol, verifier skill pointer"
```

---

## Task 3: Live test run on NRTestApp (the verification)

This is executed in a fresh session via the paste-able prompt the main agent provides. It IS the test for Tasks 1-2.

- [ ] **Step 1: Happy path** — run the skill against a clean build. Expected: all three assertions PASS; report shows masked labels as asterisks, unmasked labels verbatim, no leak.

- [ ] **Step 2: Seeded-leak negative test** — point assertion 2 at the **Unmasked** section's strings as if they were supposed to be masked (no code change needed — it's a known-leaky control). Expected: the skill reports **PII LEAK** / FAIL, proving the check has teeth.

- [ ] **Step 3: Record the outcome** — capture the report table for the demo.

---

## Self-Review

**Spec coverage:** Arrange/capture/read/assert/report all map to Task 1 steps. Fixture, observability, out-of-scope cuts, and all three risks are encoded in the skill's "Known pitfalls" and "Recording mode" sections. Success criteria #1-#3 map to Task 3 steps 1-2. ✓

**Placeholder scan:** No TBD/TODO; skill content is complete and inline. ✓

**Type/name consistency:** Skill name `session-replay-pii-verifier`, path, masked-string literals (`Masked Fields UILabel N`), and identifiers (`nr-mask`/`nr-unmask`) are consistent across spec, skill, and CLAUDE.md pointer. ✓
