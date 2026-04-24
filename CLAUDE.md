# New Relic iOS Agent

## NRTestApp Screen Map (Session Replay Test Harness)

Entry point: `ViewController` (orange screen with "Hello, World" + action buttons)

**Main menu (scroll down from ViewController):**
- **SwiftUI** -> SwiftUI Elements list
  - Buttons, Text Fields, Diff Scroll View, Pickers, Toggles, Sliders, Steppers
  - Date Pickers, Progress Views, Segmented Controls, Lists, Scroll Views, Stacks
  - Geometry Reader, Grids, Shapes, Drawings, Infinite Images, Social Media Feed
  - Attributed Text, Tinted Symbols, NavigationStack, NavigationDestination (MSR)
  - Observation (@ObservedObject), @EnvironmentObject, @AppStorage/@SceneStorage
  - @FocusState, @GestureState, Combine Publishers, @Binding Deep Chain
  - Custom Binding, objectWillChange.send(), task(id:) Async State
  - @StateObject vs @ObservedObject Lifetime, **WindowGroup Elements**
  - @Bindable (iOS 17+), @Environment(Model.self), Nested @Observable
  - Animations & Transitions
- **Utilities** -> UtilitiesViewController
- **Text Masking** -> TextMaskingViewController
- **Collection View** -> ScrollableCollectionViewController
- **Diff Test View** -> DiffTestViewController
- **Infinite Images View** -> InfiniteImageCollectionViewController
- **Tinted Images View** -> TintedImagesViewController
- **Infinite Scroll View** -> InfiniteScrollViewController

**WindowGroup Elements** has sub-sections: Presentations, Text Input, Controls, and a tab bar with 3 tabs.

**SwiftUI/NewRelicSessionReplay** screens (realistic app flows): Chat, ClaimForm, Confirmation, ExpenseEntry, HomeProfileCard, ProviderSearch

**SwiftUI/UITabBarView** screens: Dashboard, Charts, Form, Settings

---

## Session Replay Frame Verification Protocol

After performing a test scenario on a given screen, verify the session replay
frame output against the actual simulator UI using this strategy:

### 1. Capture Ground Truth
- Run `app_look visual=true verbose=true` to get the screenshot + structured
  element list (text, buttons, fields, images, section headers, nav chrome).
- Run `ui_query find predicate="visible == YES"` to get the full accessibility
  tree with coordinates and types.
- These two sources together are the "ground truth" of what the user sees.

### 2. Extract the RRWeb Frame DOM
- List `Documents/SessionReplayFrames/` via `state_tools sandbox` to find the
  active session directory and latest frame file.
- Read the frame JSON immediately (frames get pruned/uploaded quickly).
- Parse the type=2 (full snapshot) event. Extract:
  a) Every text node (id + textContent, excluding isStyle nodes).
  b) Every `<img>` tag (by id).
  c) Every `<span>` tag (often overlays for text fields).
  d) The tag tree skeleton (parent-child div nesting).
- If the frame was already pruned, trigger a new snapshot by navigating away
  and back, or by toggling a UI element to force an incremental/full capture,
  then re-read.

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

---

## Verified Screen: Animations & Transitions

**Source:** `Test Harness/NRTestApp/NRTestApp/SwiftUI/AnimationTransitionDemoView.swift`
**Verified:** 2026-04-17 | Frame: `frame_0.json` (type=2 full snapshot)

### First Visible Portion — Element Catalog

| # | Element | Type | DOM Status | DOM ID(s) | Notes |
|---|---------|------|------------|-----------|-------|
| 1 | Back chevron | Nav image | PRESENT | img id=1000314 | 16x23px base64 PNG at top=73, left=34 |
| 2 | "Animations & Transitions" | Nav title | PRESENT | text id=1308 | depth=24 |
| 3 | "1 · .animation(\_:value:) — curve picker" | Section header | PRESENT | text id=1309 | depth=20 |
| 4 | ".animation(selectedCurve, value: viewModel.showCard)" | Code caption | PRESENT | text id=1310 | depth=20, monospaced |
| 5 | Curve picker wheel | Wheel Picker | PARTIAL | text ids=1322-1327 | Picker option texts (.easeInOut x3, .easeInOut(duration:0.6) x2, .easeIn x1) present as flat text nodes at depth=33. Wheel chrome, selection indicator lines, clip mask, and rotation perspective all missing. |
| 6 | "Toggle Card A" button | Button | PRESENT | text id=1311, SVG id=3000915 | Blue fill #0048FFFF via SVG path at top=409, 132x34px |
| 7 | "Toggle Main Tab" button | Button | PRESENT | text id=1312, SVG id=3000917 | Gray bordered fill #30303751 via SVG path at top=409, 148x34px |
| 8 | Animation box (Section 1) | Container | PARTIAL | SVG id=3000919 | 376x88px at top=455. Fill #45454A19 too transparent vs visually opaque dark gray |
| 9 | "2 · .transition(edgeTransition)" | Section header | PRESENT | text id=1313 | depth=20 |
| 10 | "var edgeTransition: AnyTransition = .opacity" | Code caption | PRESENT | text id=1314 | depth=20 |
| 11 | Transition picker wheel | Wheel Picker | PARTIAL | text ids=1316-1321 | Same issue as #5. Texts: .opacity x3, .slide x2, .move(edge:.leading) x1 |
| 12 | "Toggle" button | Button | PRESENT | text id=1315, SVG id=3000924 | Blue fill #0048FFFF via SVG at top=776, 75x34px |
| 13 | Animation box (Section 2) | Container | PARTIAL | SVG id=3000926 | 376x88px at top=822. Same transparency issue as #8 |
| 14 | Section card backgrounds | Container styling | MISSING | — | Dark rounded-rectangle card backgrounds wrapping each section not represented. All div backgrounds are #00000000. |
| 15 | Status bar | System UI | MISSING (expected) | — | System UI excluded from session replay |

### Known DOM Gaps

**MISSING:**
- **Section card backgrounds** — SwiftUI `.background()` modifiers using `Material` or grouped-style containers are not serialized. All `div` elements have `background: #00000000`.

**PARTIAL:**
- **Picker wheels (both)** — `UIPickerView` internal subviews (selection indicator lines, perspective transform, gradient masks) are not serialized. Only text labels extracted. Replay shows flat text list instead of wheel.
- **Animation boxes (both)** — Container dimensions correct but fill color `#45454A19` is far more transparent than the visually rendered dark gray. Likely reads pre-composited alpha from `CALayer` rather than final dark-mode appearance.

### Pepper Compatibility Note

Pepper's `ElementDiscoveryBridge.walkLayerTree` crashes (EXC_BREAKPOINT in
`isDuplicate(frame:view:)`) on this screen due to complex animation layers.
Use `sim_raw cmd=tap params={"text":"...", "skip_look": true}` + simctl
screenshots instead of `app_look`/`ui_query`/`ui_tap` to avoid the crash.

---

## Verified Screen: NavigationDestination (MSR)

**Source:** `Test Harness/NRTestApp/NRTestApp/SwiftUI/NavigationDestinationDemoView.swift`
**Verified:** 2026-04-17 | Frame: `frame_0.json` (type=2 full snapshot, 53KB)

### DOM Structure Summary

Critical finding: **0 of 159 divs have any style attribute**. Only 3 elements
(all `<img>`) carry position/size. The entire list content is rendered as
unstyled text inside a deep chain of plain `<div>` wrappers. No SVGs, no
backgrounds, no colors anywhere in the DOM.

### First Visible Portion — Element Catalog

| # | Element | Type | DOM Status | DOM ID(s) | Notes |
|---|---------|------|------------|-----------|-------|
| 1 | Back chevron (outer) | Nav image | PRESENT | img id=1000314 | 16x23px base64 PNG at top=73, left=34 |
| 2 | Back chevron (inner) | Nav image | PRESENT | img id=1003389 | 16x23px base64 PNG at top=137, left=34 |
| 3 | Nav bar background | Image | PRESENT | img id=1003356 | 440x114px at top=116, opacity=0.01 (nearly invisible) |
| 4 | "Nav Destination Demo" | Nav title (large) | MISSING | — | Not in DOM. UILabel in view hierarchy has empty text. Title not propagated in nested NavigationStack context. |
| 5 | "Push typed destinations" | Section header | PRESENT | text id=3534 | Text only — no color, no position, no font styling |
| 6 | "Detail A" | Button (list row) | PARTIAL | text id=3541 | Text present but: no blue color, no position, no tap target styling |
| 7 | "Detail B" | Button (list row) | PARTIAL | text id=3540 | Same — text only, no color/position |
| 8 | "Detail C" | Button (list row) | PARTIAL | text id=3539 | Same — text only, no color/position |
| 9 | "Nested (push C → B)" | Button (list row) | PARTIAL | text id=3538 | Same — text only, no color/position |
| 10 | "Programmatic" | Section header | PRESENT | text id=3533 | Text only — no styling |
| 11 | "Push B then C (deep link)" | Button (list row) | PARTIAL | text id=3537 | Text present, blue color on screen not captured |
| 12 | "Pop to root" | Button (list row) | PARTIAL | text id=3536 | Text present, **red** color on screen not captured |
| 13 | "Path state" | Section header | PRESENT | text id=3532 | Text only — no styling |
| 14 | "Depth: 0" | State text | PRESENT | text id=3535 | Text only — no secondary color styling |
| 15 | Section card backgrounds | Container styling | MISSING | — | Dark rounded-rectangle grouped-list backgrounds absent. Zero backgrounds in entire DOM. |
| 16 | List row separators | Dividers | MISSING | — | Thin separator lines between rows not represented |
| 17 | Text colors (blue/red/gray) | Styling | MISSING | — | Zero `color` properties on any element. Blue buttons, red "Pop to root", gray headers all render as unstyled text |
| 18 | Element positioning | Layout | MISSING | — | Zero divs have position/top/left. Only 3 images are positioned. Text nodes have no spatial data. |
| 19 | Status bar | System UI | MISSING (expected) | — | System UI excluded |

### Known DOM Gaps

**MISSING (5 categories):**
- **Navigation title** — "Nav Destination Demo" absent from DOM entirely. Likely lost in nested NavigationStack context.
- **Section card backgrounds** — grouped-style List backgrounds not serialized. Zero background properties in DOM.
- **List row separators** — the thin divider lines between rows are not represented.
- **All text colors** — blue (buttons), red ("Pop to root"), gray (section headers), secondary (depth) — zero color properties anywhere.
- **All element positioning** — 159 divs, none with position/top/left/width/height styles. Layout is completely absent.

**PARTIAL (5 elements):**
- **Detail A, B, C, Nested, Push B then C, Pop to root** — text content captured but rendered as flat unstyled text nodes. No color, no position, no tap-target styling, no disclosure indicators.

### Accessibility Note

Pepper's accessibility tree also shows the list cells as **unlabeled** (`""`)
— the text content is visible via OCR but not exposed through the
accessibility framework. This is a SwiftUI `Button` inside a `List` issue
where accessibility labels are not automatically derived from the button text.

### Severity Assessment

This screen has **significantly worse** DOM fidelity than the Animations &
Transitions screen. While that screen had partial styling (SVG fills, some
positioning), this screen has essentially **zero visual metadata** — the replay
would show only a flat list of unstyled text and two small chevron images. The
structural rendering of `NavigationStack` + `List` + `Button` content appears
to bypass the view-tree serializer's style extraction almost entirely.
