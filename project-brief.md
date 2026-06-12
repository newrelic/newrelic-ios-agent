# AFA 2026 — Project Brief

## Project Name
MaskSmith — Session Replay PII Masking

## One-line description
A Claude skill that finds PII in an iOS app's source, applies New Relic Session Replay masking, and proves redaction at runtime.

## What problem are you solving?
New Relic Session Replay redacts PII in-memory before the replay frame is serialized and uploaded. That leaves a developer blind twice. First, they must know *what* in their app is PII and hand-wire masking on each view — miss one field and it leaks. Second, they can't confirm masking worked by eye, because redaction happens in the uploaded RRWeb frame, not on screen. One missed card number, SSN, or chat message silently flows into observability data — a compliance incident. Today this is manual, per-view, easy to get wrong, and impossible to verify without reading serialized frames by hand. SwiftUI masking is the most fragile path and breaks quietly across OS/SwiftUI versions.

## Why should we do this?
PII leaking into a session replay is the highest-stakes failure of the feature — a privacy/compliance incident for both New Relic and the customer — and it's the one thing a consumer literally cannot catch by eye. Masking setup is also the biggest friction to adopting Session Replay: it's manual, per-view, and easy to under- or over-do. If a developer can point Claude at their app and get the right masking applied and proven, adoption rises and privacy-support escalations fall. The same skill doubles as a regression gate: SwiftUI masking silently breaks across OS/SwiftUI versions, so an automated source-to-frame check can guard every release.

## What are we building?
A Claude Code plugin centered on a new skill, `session-replay-masking-from-source`. Pointed at any iOS app that embeds the New Relic agent, it scans the source tree, reasons about which views render PII (credit card, SSN, password, email, phone, address, names, personal messages/chat, tokens), and builds a ground-truth inventory of what must be masked. It confirms the list with the developer, then applies the narrowest New Relic masking mechanism per case — `nr-mask`/`nr-unmask` identifiers, `addSessionReplayMaskViewClass`, or `NRConditionalMaskView` for SwiftUI — while deliberately leaving a safe control element unmasked. The existing `session-replay-pii-verifier` POC then drives the running app, reads the on-disk RRWeb frame, and proves masked PII is redacted (asterisks / `#CCCCCC`, leak-absent) while the control survives verbatim. Source intent in, runtime proof out.

## Scale and scope
In scope: the new `session-replay-masking-from-source` skill end-to-end — detection across the source tree, semantic confirmation by reading code (not just regex), a ground-truth PII inventory, and applying the narrowest masking mechanism per row while keeping one control element unmasked. We demo it on `Test Harness/SampleApp`, a fresh unseen SwiftUI app (Login, Cards/AddCard, Messages, Profile) full of currently-unmasked PII with test credentials baked in. Runtime proof reuses the existing `session-replay-pii-verifier` POC over the Xcode DeviceInteraction* driver, reading frames on disk. Out of scope (nice-to-haves cut): the other four verifier ideas (upload-liveness, recording-mode, touch-fidelity, standalone SwiftUI-coverage); Pepper as the driver this round; auth-walled third-party apps and credential automation beyond the baked-in login; and any auto-mask of high-blast-radius rows without developer sign-off.

## How does AI fit in?
Detecting PII in arbitrary source isn't a regex problem — it needs semantic judgment. A property named `cardLabel` might render a product card, not a credit card; a `Message` type might be system toasts or private chats. Claude reads the surrounding code and decides, generalizing to an app it has never seen with no hardcoded file, screen, or field list. It then picks the *narrowest* masking mechanism (per-view id vs class-wide registration vs SwiftUI wrapper) by reasoning about blast radius, and asks before high-impact edits. Finally it drives the running app from the UI hierarchy — depth-first, unscripted — and closes the loop by checking the serialized frame against the source-derived intent. A static analyzer can flag patterns; only an agent can judge intent, choose the mechanism, navigate an unknown UI, and confirm redaction at runtime.

## AI tools and technologies
- **Claude Code + Skills** — packaged as the `session-replay-masking` plugin (in the `newrelic-ios-agent` marketplace) bundling three skills: `session-replay-masking-from-source` (hero), `session-replay-pii-verifier` (supporting POC), and `device-interaction` (driver dependency).
- **Claude (Opus)** as the reasoning agent doing semantic PII detection, masking-mechanism selection, and autonomous app navigation.
- **Xcode 27 DeviceInteraction\* tools** via the `xcrun mcpbridge` tool service (registered as the `xcode-tools` MCP server): `DeviceInteractionStartSession` → `InstallAndRun` → `DeviceEventSynthesize` → `EndSession`.
- **`xcrun simctl`** to resolve the app data container and read on-disk RRWeb frames at `Documents/SessionReplayFrames/{sessionId}/frame_N.json`.
- **New Relic iOS agent — Session Replay** (RRWeb-format frame serialization).
- **Masking API surface:** `nr-mask` / `nr-unmask` accessibility identifiers, `addSessionReplayMaskedAccessibilityIdentifier`, `addSessionReplayMaskViewClass` / `addSessionReplayUnmaskViewClass`, `NRConditionalMaskView` (SwiftUI), and auto-masked `SecureField` / `isSecureTextEntry`.
- **Demo target:** `Test Harness/SampleApp` (SwiftUI), with the repo's `NRTestApp` `TextMaskingViewController` available as a secondary oracle.

## How will we judge success?
"It worked" = a before/after delta on a planted leak, proven by reading the serialized frame rather than by eye. Concretely, on `Test Harness/SampleApp` (which the skill has never seen):

1. **Discovery.** The skill produces a ground-truth inventory that correctly flags the app's PII — SSN/phone/email (Profile), card number/CVV/cardholder (AddCard/Cards), the chat bubbles that carry a card number and an SSN (Messages) — and notes the `SecureField` password as already auto-masked. It does *not* blanket-mask: it names a control element (e.g. a nav title) to leave verbatim. Measure: known sensitive fields caught with no obvious miss.
2. **Before (red).** Run the verifier first: the on-screen PII appears verbatim in the frame and at least one field is flagged as a **PII LEAK** with its frame node id.
3. **Apply.** The skill applies the narrowest masking (SwiftUI `NRConditionalMaskView`, etc.) to the confirmed rows.
4. **After (green).** Re-run the verifier: the same strings are now redacted to length-matched asterisks (images to `#CCCCCC`, no base64), the literal strings appear **nowhere** in the frame, and the unmasked control still survives verbatim → verdict **PASS**.

The winning moment is the side-by-side: same field, **LEAK → redacted**, control intact, all read out of the on-disk frame.

## Dependencies and potential blockers
This requires Claude and uses lots of tokens. Verifier still requires manual approval for xcode-tools integrations.