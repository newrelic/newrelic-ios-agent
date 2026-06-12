---
name: session-replay-masking-from-source
description: "Use when you need to find and mask PII in an iOS app's source before it can leak into New Relic Session Replay — scanning the whole codebase for credit card / SSN / password / email / phone / personal-message / chat / sensitive fields, building a masking ground-truth inventory of what should be masked, or applying New Relic Session Replay masking to UIKit and SwiftUI views that currently expose sensitive content."
---
# Session Replay Masking From Source

TRIGGER when: user asks to scan/audit an app's source for unmasked PII, build a masking ground truth from source code, detect sensitive fields (credit card, SSN, password, personal messages, chats, sensitive content), or apply Session Replay masking across an app — in any iOS app that embeds the New Relic agent.
DO NOT TRIGGER when: user asks to verify masking at runtime in serialized replay frames (use `session-replay-pii-verifier`), or for non-masking source work.

This skill is the **static, source-side** counterpart to `session-replay-pii-verifier` (`xcode-skills/session-replay-pii-verifier/SKILL.md`), which proves masking at runtime by reading on-disk frames. This skill builds the *ground truth of what must be masked* from source, then applies masking. Run the verifier afterward to confirm the applied masking actually redacts at runtime.

It is app-agnostic: it hardcodes no file list, screen, or field names. Every detection target is discovered by scanning the source tree of whatever app is in front of you.

## No compound shell commands

Run every shell command as its own invocation. **Never** chain with `&&`, `;`, `|` into-mutating, or `cd X && cmd`. Compound commands defeat per-command permissioning and cause errors. One command = one Bash call.

- Wrong: `cd Test\ Harness && grep -rn password .`
- Right: one Bash call `grep -rn "password" "Test Harness"` (pass the path as an argument; do not `cd`).

## The masking API surface (what you apply)

| Mechanism | Where | How |
|---|---|---|
| Built-in per-view id | UIKit view | `view.accessibilityIdentifier = "nr-mask"` (or `"nr-unmask"` for controls) |
| Custom masked id | UIKit view | give the view a custom id, then register `NewRelic.addSessionReplayMaskedAccessibilityIdentifier("private")` once at startup |
| Mask a whole class | UIKit | `NewRelic.addSessionReplayMaskViewClass("MyChatBubbleLabel")` at startup; pair with `addSessionReplayUnmaskViewClass(...)` to carve out exceptions |
| Already auto-masked | UIKit text entry | `isSecureTextEntry = true` is masked by the agent automatically — **note it, do not double-mask** |
| SwiftUI | SwiftUI subtree | wrap content in `NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllImages: true) { ... }` |

Prefer the **narrowest** mechanism that covers the leak: per-view id for one field, class registration only when every instance of a type is sensitive (e.g. a dedicated `ChatMessageLabel`).

## Detection signals (build ground truth)

Scan source for these. A hit is a *candidate*; confirm by reading the surrounding code before masking.

| PII category | Strong source signals |
|---|---|
| Password / secret | `isSecureTextEntry`, `textContentType = .password/.newPassword/.oneTimeCode`, identifiers/placeholders matching `password`, `passcode`, `pin`, `secret`, `otp` |
| Credit card | `textContentType = .creditCardNumber`, `keyboardType = .numberPad` near `card`/`cvv`/`expiry`, literals/identifiers matching `card`, `cvv`, `cvc`, `expir`, `cardNumber` |
| SSN / national id | identifiers/placeholders matching `ssn`, `social security`, `nationalId`, `taxId`; literals matching `\d{3}-\d{2}-\d{4}` |
| Email | `textContentType = .emailAddress`, `keyboardType = .emailAddress`, identifiers matching `email` |
| Phone | `textContentType = .telephoneNumber`, `keyboardType = .phonePad`, identifiers matching `phone`, `mobile`, `tel` |
| Address / postal | `textContentType` in `.fullStreetAddress/.postalCode/.addressCity...`, identifiers matching `address`, `zip`, `postal` |
| Name / DOB | `textContentType` in `.name/.givenName/.familyName`, identifiers matching `firstName`, `lastName`, `dob`, `birth` |
| Personal messages / chat | model/view types named `Message`, `ChatMessage`, `Conversation`, `Bubble`, `DM`; labels/text views bound to user-authored message bodies |
| Auth tokens / keys | identifiers matching `token`, `apiKey`, `bearer`, `authorization`, `jwt` rendered into any visible view |

Useful one-shot greps (each its own Bash call, paths as arguments — no `cd`, no chaining):

- `grep -rni "password\|passcode\|cvv\|ssn\|creditcard\|cardnumber\|social security" <source-root> --include=*.swift --include=*.m`
- `grep -rn "isSecureTextEntry" <source-root>`
- `grep -rn "textContentType" <source-root>`
- `grep -rni "accessibilityIdentifier" <source-root>` (find existing `nr-mask`/`nr-unmask` coverage)
- `grep -rni "message\|chat\|conversation\|bubble" <source-root> --include=*.swift -l`

Note: if `--include` errors in zsh ("no matches found"), it is shell glob expansion — quote the pattern or drop `--include` and filter results, still in a single command.

## Protocol

### 1. Scope the source tree
Find the app's own source (exclude the agent/SDK, Pods, SPM checkouts, generated files): `find <repo> -name "*.swift" -not -path "*/Agent/*" -not -path "*/.build/*" -not -path "*/Pods/*"`. Confirm with the user which directory is the app under audit if ambiguous.

### 2. Detect and build the ground-truth inventory
Run the detection greps. For every candidate, read the surrounding code and record one row:

| File:line | View / type | UIKit/SwiftUI | PII category | Signal | Currently masked? | Recommended mechanism |

"Currently masked?" = does it already carry `nr-mask` / a registered masked id / `isSecureTextEntry` / sit inside an `NRConditionalMaskView`? If yes, mark COVERED and skip in step 4.

### 3. Confirm with the user before mutating source
Present the inventory. Masking changes app behavior in replay and can over-redact. Get the user's confirmation on which rows to mask before editing — especially class-wide registrations and chat/message models (high blast radius). Do not edit source until confirmed.

### 4. Apply masking (narrowest mechanism per row)
- One UIKit field → set its `accessibilityIdentifier = "nr-mask"` at the point it is configured.
- Every instance of a dedicated sensitive type → `NewRelic.addSessionReplayMaskViewClass("TypeName")` once at agent-start; do not also tag each instance.
- SwiftUI subtree → wrap in `NRConditionalMaskView(...)` with the relevant `mask*` flags.
- `isSecureTextEntry = true` already present → leave it; record as auto-masked.
- Leave clearly non-sensitive controls (nav titles, static chrome, buttons) **unmasked** so selective masking stays provable.

### 5. Preserve a control + report
Do **not** blanket-mask the app. Selective masking (some masked, some verbatim) is what the runtime verifier needs to distinguish working masking from a broken serializer that drops everything. Keep at least one known-safe element unmasked per screen.

Report: the ground-truth table, the rows changed with their mechanism, rows left as auto-masked/COVERED, and rows intentionally left unmasked (with why). Then recommend running `session-replay-pii-verifier` to confirm redaction at runtime.

## Common mistakes

| Mistake | Fix |
|---|---|
| Masking every view to "be safe" | Destroys the selective-vs-blanket signal; mask only confirmed PII, keep controls verbatim |
| Tagging each instance AND registering the class | Pick one — class registration covers all instances |
| Double-masking `isSecureTextEntry` fields | Already auto-masked; just record it |
| Masking on a name match without reading code | A var named `cardLabel` may render a product card, not a credit card — confirm before editing |
| Editing source before user confirms | High-blast-radius rows (class-wide, chat models) need sign-off first |
| Compound shell commands | One command per Bash call; pass paths as arguments, never `cd X && ...` |

## Worked example (this repo)

`Test Harness/NRTestApp/NRTestApp/ViewControllers/TextMaskingViewController.swift` is a ready oracle: `createSearchAndCredentialsSection()` builds a password field (`isSecureTextEntry` → auto-masked), a credit-card field and search bar tagged `nr-mask`, a CVV field (`isSecureTextEntry`), and a username field tagged `nr-unmask` (the deliberate control). A correct ground-truth pass marks the card/CVV/password/search rows as masked-or-covered and the username row as intentionally unmasked.
