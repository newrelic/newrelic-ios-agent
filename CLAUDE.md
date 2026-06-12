# New Relic iOS Agent

## Session Replay PII masking verification

For PII masking verification, use the `session-replay-pii-verifier` skill
(`xcode-skills/session-replay-pii-verifier/SKILL.md`). It drives any iOS app
that embeds the New Relic agent with the `device-interaction` skill and asserts
masked content is redacted in the on-disk RRWeb frame
(`Documents/SessionReplayFrames/{sessionId}/frame_N.json`) while unmasked
content survives verbatim. The skill discovers build coordinates and the
masked screen per run — it hardcodes no specific app. Spec:
`docs/superpowers/specs/2026-06-12-session-replay-pii-leak-verifier-design.md`.

---

## Session Replay Frame Verification Protocol

This protocol is app-agnostic: it works against whatever iOS app embeds the
New Relic agent. Drive the app with the `device-interaction` skill
(`DeviceInteractionStartSession` → `DeviceInteractionInstallAndRun` →
`DeviceEventSynthesize` → `DeviceInteractionEndSession`) and read the app
sandbox with `xcrun simctl`. After performing a test scenario on a given
screen, verify the session replay frame output against the actual simulator UI
using this strategy.

### 0. Establish build coordinates
- Workspace/project: the `.xcworkspace` (preferred) or `.xcodeproj` at the repo
  root — `ls *.xcworkspace *.xcodeproj`.
- Scheme: the runnable app target's shared scheme — `xcodebuild -list`, or the
  `*.xcscheme` files under `xcshareddata/xcschemes/`. Pick the app scheme, not
  framework/test schemes.
- Bundle id: `xcodebuild -showBuildSettings -scheme <scheme> | grep
  PRODUCT_BUNDLE_IDENTIFIER` — needed to locate the app container in step 2.
- Simulator: a booted simulator UDID — `xcrun simctl list devices booted`.
  `DeviceInteractionStartSession` selects the device; note the UDID it targets.

### 1. Capture Ground Truth
- Install and launch via `DeviceInteractionInstallAndRun` (builds + installs +
  runs). Use its `commandLineArguments` / `environmentVariables` to set any
  launch flags for the run rather than editing the scheme.
- Capture the UI hierarchy + screenshot via `DeviceEventSynthesize` with an
  empty `interactionCommand`. The hierarchy lists text, buttons, fields,
  images, section headers, nav chrome with element frames and center coords.
- Navigate by tapping element **center coordinates** from the hierarchy
  (`DeviceEventSynthesize interactionCommand="t <cx> <cy>"`); swipe to scroll
  (`"t 200 600 f 200 200 0.3"`).
- The hierarchy + screenshot together are the "ground truth" of what the user
  sees.

### 2. Extract the RRWeb Frame DOM
- Resolve the app's data container on the simulator:
  `xcrun simctl get_app_container <udid> <bundle-id> data` → `<container>`.
- `ls "<container>/Documents/SessionReplayFrames"` to find the active session
  directory and latest frame file.
- Read the frame JSON immediately with the Read tool (frames get
  pruned/uploaded quickly).
- Parse the type=2 (full snapshot) event. Extract:
  a) Every text node (id + textContent, excluding isStyle nodes).
  b) Every `<img>` tag (by id).
  c) Every `<span>` tag (often overlays for text fields).
  d) The tag tree skeleton (parent-child div nesting).
- If the frame was already pruned, trigger a new snapshot by navigating away
  and back (tap the back-button center coords, then re-enter), or by toggling a
  UI element to force an incremental/full capture, then re-resolve the
  container and re-read.

### 3. Compare: Build a Coverage Table
For each visible element from step 1, check for a matching node in the DOM
from step 2. Classify each as:
- **PRESENT**: text or image node exists with matching content.
- **PARTIAL**: node exists but is incomplete (e.g., image with no label, only
  one instance of a duplicated element).
- **MISSING**: no corresponding node in the DOM at all.

Focus comparison on the region specified by the user (e.g., "first visible
portion" = above the fold, no scrolling). Ignore offscreen/scrolled content
unless told otherwise.

### 4. Categorize Gaps
Group missing/partial elements by UI region:
- Navigation bar chrome (back buttons, titles, toolbar items)
- Tab bar (icons, labels)
- Section headers / list group styling
- Content area (buttons, text, fields, pickers, toggles)
- System/ephemeral UI (scroll indicators, status bar) -- expected missing

### 5. Report
Produce a markdown table with columns:

| Element | Type | Visible | In DOM | Status | Notes |

Then list the MISSING and PARTIAL items separately with brief root-cause
hypotheses (e.g., "navigation bar internal views not traversed",
"tab bar labels are SwiftUI-rendered without accessibility text nodes").

Keep the report factual and concise. Do not speculate about fixes unless asked.
Close the session with `DeviceInteractionEndSession` when done.

### Full-app scour
To audit a whole app rather than one screen, run steps 1–5 across every
navigable screen — discover them at runtime, hardcode no screen list:
- **Enumerate.** From the launch screen, treat every navigable
  row/button/tab/cell in the hierarchy as an edge. Visit depth-first (tap
  center coords → capture → recurse → tap back-button center coords to
  return); scroll (`t 200 600 f 200 200 0.3`) to reveal off-screen targets;
  track visited screens by title/identity to avoid loops.
- **Classify each screen.** If it carries masked or PII-shaped content (any
  `nr-mask` marker, or fields like password / credit card / SSN / email), run
  the masked/unmasked oracle from the `session-replay-pii-verifier` skill (each
  masked string redacted to length-matched asterisks / masked images `#CCCCCC`
  with no base64; the literal on-screen string appears nowhere in the frame —
  flag any hit as **PII LEAK** with string + node id; unmasked controls survive
  verbatim, else INCONCLUSIVE). Otherwise run the PRESENT/PARTIAL/MISSING
  coverage comparison above.
- **Report ordering.** Per screen: a verdict table + one-line
  PASS / FAIL / INCONCLUSIVE. Overall summary lists every **PII LEAK** first,
  then masking gaps, then fidelity gaps.
