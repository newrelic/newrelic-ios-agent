# SwiftUI Compatibility — New Relic Mobile Session Replay

This document covers which SwiftUI components and patterns are captured, masked, and tracked by the New Relic Mobile Session Replay (MSR) system, based on the test harness and agent source code.

---

## Requirements

| Requirement | Details |
|---|---|
| Minimum iOS for Session Replay | iOS 16+ (full SwiftUI support) |
| iOS 15 behavior | SwiftUI views rendered but `NRConditionalMaskView` masking is **inactive** — content appears unmasked |
| Framework | `NewRelic` module, SwiftUI integration via `UIHostingView` introspection |
| Screen tracking modifier | `.NRTrackView(name:)` |
| Masking API | `NRConditionalMaskView(...)` wrapper |

---

## How SwiftUI Capture Works

The agent captures SwiftUI views by detecting `UIHostingView` instances in the UIKit view hierarchy. From there, `UIHostingViewRecordOrchestrator` extracts the SwiftUI view tree via the XRAY subsystem, separates background layers from content layers, and merges them into the RRWeb snapshot format.

SwiftUI-specific captors operate alongside UIKit captors:
- `SwiftUIViewAttributes` — captures frame, color, border, corner radius, alpha, masking flags
- `SwiftUIDrawingThingy` — captures `Canvas` drawings
- `SwiftUIShapeThingy` — captures shape primitives
- `StyledTextSwiftUIView` / `SwiftUIStyledTextRes` — captures styled and attributed text
- `SwiftUIGraphicsImage` / `SwiftUIImageRepresentable` — captures images rendered in SwiftUI

`ControllerTypeDetector` distinguishes `UIHostingController` from `NavigationStackHostingController` (iOS 16+) to enable correct navigation depth tracking.

---

## Component Compatibility

### Text & Input

| Component | Captured | Masked by Default | Masking API | Notes |
|---|---|---|---|---|
| `Text` | ✅ | No | `NRConditionalMaskView(maskApplicationText: true)` | Captured as styled text node with font/color/alignment |
| `TextField` | ✅ | No | `NRConditionalMaskView(maskUserInputText: true)` | Input text replaced with `*` when masked |
| `SecureField` | ✅ | Yes (auto) | Always masked | Detected as secure; text is always replaced with `*` |
| `TextEditor` | ✅ | No | `NRConditionalMaskView(maskUserInputText: true)` | Captured via `UITextViewThingy` bridge |
| `AttributedText` / `AttributedString` | ✅ | No | `NRConditionalMaskView(maskApplicationText: true)` | `AttributedTextView.swift` test; font runs captured |

### Controls

| Component | Captured | Notes |
|---|---|---|
| `Button` | ✅ | Captured as tappable UIView node; touch events tracked if `maskAllUserTouches` is false |
| `Toggle` (default style) | ✅ | Renders via `UISwitch` bridge; `isOn` state, `onTintColor`, `thumbTintColor` captured |
| `Toggle` (custom style: `PillToggleStyle`, `SquareToggleStyle`, `ColorfulToggleStyle`) | ⚠️ | Custom styles render as generic SwiftUI views — visual shape approximated, state may not be captured semantically |
| `Slider` | ⚠️ | Captured as generic UIView; thumb position not semantically captured |
| `Stepper` | ⚠️ | Captured as generic UIView; current value not semantically captured |

### Pickers & Date Inputs

| Component | Captured | Masked by Default | Notes |
|---|---|---|---|
| `Picker` (segmented style) | ✅ | No | Rendered via `UISegmentedControl` bridge |
| `Picker` (menu/wheel style) | ⚠️ | No | Rendered as system overlay; partial capture |
| `DatePicker` (graphical style) | ✅ | No | Captured via `UIDatePickerThingy`; respects `maskUserInputText` |
| `DatePicker` (wheel style) | ✅ | No | Captured via `UIDatePickerThingy`; aggressive clipping skipped for wheel mode |
| `SegmentedControl` (SwiftUI) | ✅ | No | Rendered via `UISegmentedControl`; selection state captured |

### Navigation

| Component | Captured | Notes |
|---|---|---|
| `NavigationStack` (iOS 16+) | ✅ | Fully supported; `ControllerTypeDetector` identifies `NavigationStackHostingController`; push/pop depth tracked via `layoutContainerCount` and `navigationStackDepth` on each frame |
| `NavigationView` (iOS 15, deprecated) | ⚠️ | Basic capture; navigation depth tracking limited |
| `NavigationLink` | ✅ | Destination push captured; masking inherited from parent `NRConditionalMaskView` if present |
| `TabView` / `UITabBar` integration | ✅ | `SwiftUITabBar.swift` uses `UITabBarController` bridge; tab switches recorded via `NewRelic.recordCustomEvent` |

### Layout & Containers

| Component | Captured | Notes |
|---|---|---|
| `VStack` / `HStack` / `ZStack` | ✅ | Layout containers captured as transparent view nodes; children captured recursively |
| `LazyVStack` / `LazyHStack` | ✅ | Visible cells captured; off-screen cells not in snapshot (by design) |
| `LazyVGrid` / `LazyHGrid` | ✅ | Visible grid items captured; tested with 2-column and 3-column layouts |
| `List` | ✅ | Rendered via `UITableView` bridge; rows captured as UIKit cells |
| `ScrollView` | ✅ | Captured; scroll position not encoded in frame data |
| `Form` | ✅ | Rendered via `UITableView` bridge; section headers/footers captured |
| `Group` | ✅ | Transparent container; children captured normally |
| `GeometryReader` | ✅ | Captured as layout frame; does not affect capture fidelity |

### Visuals & Media

| Component | Captured | Masked by Default | Notes |
|---|---|---|---|
| `Image` (system SF Symbol) | ✅ | No | Captured via `SwiftUIImageRepresentable` |
| `Image` (asset / URL) | ✅ | No | `maskAllImages: true` replaces with placeholder |
| `AsyncImage` | ⚠️ | No | Loading state captured as placeholder; loaded image captured when in-tree |
| `Canvas` | ✅ | No | Captured via `SwiftUIDrawingThingy`; rendered as bitmap node |
| `Shape` (Circle, Rectangle, RoundedRectangle, etc.) | ✅ | No | Captured via `SwiftUIShapeThingy`; fill/stroke approximated |
| `Color` (background fill) | ✅ | No | `SwiftUIColor` captures RGBA values for background rendering |
| `ProgressView` (linear) | ✅ | No | Rendered via `UIProgressView` bridge |
| `ProgressView` (circular / spinner) | ✅ | No | Rendered via `UIActivityIndicatorView` bridge |
| `UIVisualEffectView` (blur) | ✅ | No | Captured via `UIVisualEffectViewThingy`; effect type noted in DOM node |

---

## Masking & Privacy API

### `NRConditionalMaskView`

The primary masking wrapper for SwiftUI. Wraps content in a `NRMaskedViewRepresentable` bridge on iOS 16+.

```swift
NRConditionalMaskView(
    maskApplicationText: Bool,     // Mask Text/Label static content
    maskUserInputText: Bool,       // Mask TextField/TextEditor/SecureField input
    maskAllImages: Bool,           // Replace Image views with placeholder
    maskAllUserTouches: Bool,      // Suppress touch recording in this subtree
    blockView: Bool,               // Black out entire subtree in replay
    sessionReplayIdentifier: String?, // Stable ID for this node in replay
    activated: Bool                // Defaults true; set false to disable at runtime
) {
    // your content
}
```

**Minimum iOS:** 16.0 — on iOS 15 the wrapper renders content without any masking applied.

### `.NRTrackView(name:)` Modifier

Registers a SwiftUI view as a named screen in session replay and interaction tracking.

```swift
MyView()
    .NRTrackView(name: "ClaimForm")
```

### Masking Inheritance Rules

Masking settings propagate **down** the view hierarchy unless explicitly overridden by a child `NRConditionalMaskView`:

| Scenario | Behavior |
|---|---|
| Parent `maskApplicationText: true`, no child override | All descendant `Text` nodes masked |
| Parent `maskApplicationText: true`, child `maskApplicationText: false` | Child subtree unmasked |
| Child masked inside unmasked parent | Child subtree masked; siblings unmasked |
| `blockView: true` on parent | Entire subtree replaced with opaque black block |
| `sessionReplayIdentifier` set | Provides a stable node ID across sessions for that element |

### Masking Test Coverage (MaskingView.swift)

The `MaskingView` test file verifies all permutations:

1. **Direct elements** — single Text/TextField masked or unmasked
2. **Parent-to-child inheritance** — children adopt parent masking
3. **Child override in masked parent** — child `NRConditionalMaskView` with `maskApplicationText: false` clears masking for that subtree
4. **Child masked in unmasked parent** — child `NRConditionalMaskView` with `maskApplicationText: true` masks only that subtree
5. **Deep nesting (4+ levels)** — mixed masking across hierarchy levels
6. **Sibling mixing** — sibling views with different masking, each with explicit `sessionReplayIdentifier`
7. **Reusable components** — `MaskableRow` with masking passed as parameter
8. **NavigationLink within masked parent** — destination inherits masking

---

## Pause / Resume Recording (Confidential Screens)

SwiftUI equivalent of `ConfidentialViewController` pattern:

```swift
struct ConfidentialView: View {
    var body: some View {
        Text("Sensitive Data")
            .onAppear { NewRelic.pauseReplay() }
            .onDisappear { NewRelic.recordReplay() }
    }
}
```

---

## Known Limitations & Notes

| Limitation | Details |
|---|---|
| iOS 15 masking inactive | `NRConditionalMaskView` renders content without masking on iOS 15 |
| Custom `ToggleStyle` | Non-standard toggle styles are captured as generic views; semantic state not guaranteed |
| Slider / Stepper value | Current numeric value not captured semantically in replay |
| Picker (menu/sheet style) | System overlay presentation may not be captured |
| `AsyncImage` loading state | Intermediate loading skeleton may not be captured if not yet in the UIKit tree |
| `Canvas` is bitmapped | Canvas drawings are captured as a bitmap snapshot, not as structured nodes |
| Off-screen lazy cells | `LazyVStack`/`LazyVGrid` off-screen items do not appear in snapshots |
| WKWebView content | Web content inside `UIViewRepresentable`-wrapped `WKWebView` is not replayed as DOM |

---

## Test Harness Files

| File | Purpose |
|---|---|
| `SwiftUI/ContentView.swift` | Navigation hub for all SwiftUI component demos |
| `SwiftUI/ButtonsView.swift` | Button variants (default, toggle, styled, with image) |
| `SwiftUI/TextFieldsView.swift` | TextField, TextEditor, SecureField with validation |
| `SwiftUI/TogglesView.swift` | Toggle variants (default + 4 custom styles) |
| `SwiftUI/SlidersView.swift` | Continuous and stepped sliders |
| `SwiftUI/SteppersView.swift` | Stepper with range (0–100) |
| `SwiftUI/PickersView.swift` | Segmented, date, and menu pickers |
| `SwiftUI/DatePickersView.swift` | Graphical and wheel date/time pickers |
| `SwiftUI/SegmentedControlsView.swift` | Segmented control selection |
| `SwiftUI/ListsView.swift` | Basic List with conditional row styling |
| `SwiftUI/GridsView.swift` | LazyVGrid with 3-column flexible layout |
| `SwiftUI/ProgressViewsView.swift` | Linear and circular progress indicators |
| `SwiftUI/ScrollViewsView.swift` | Vertical ScrollView with 50 items |
| `SwiftUI/StacksView.swift` | VStack, HStack, ZStack layouts |
| `SwiftUI/ShapesView.swift` | Shape primitives (circle, rectangle, rounded rect) |
| `SwiftUI/DrawingsView.swift` | Canvas drawings |
| `SwiftUI/SocialMediaFeedView.swift` | Infinite scroll LazyVStack with async images and pagination |
| `SwiftUI/InfiniteImageCollectionView.swift` | Infinite image grid (LazyVGrid, 2 columns, async loading) |
| `SwiftUI/AttributedTextView.swift` | Attributed text with custom formatting runs |
| `SwiftUI/TintedSymbolsView.swift` | SF Symbol tinting |
| `SwiftUI/NavigationStackView.swift` | iOS 16+ NavigationStack with typed path, programmatic nav, search |
| `SwiftUI/MaskingView.swift` | All masking permutations (7 scenarios) |
| `SwiftUI/UITabBarView/SwiftUITabBar.swift` | Multi-tab layout (Dashboard, Form, Charts, Alerts, Profile, Media, Settings) |
| `SwiftUI/UITabBarView/FormView.swift` | Complex form (TextField, DatePicker, Picker, Toggle, TextEditor, Stepper) |
| `SwiftUI/NewRelicSessionReplay/ClaimFormView.swift` | Insurance claim form (iOS 16+) with Picker, Toggle, TextField, ActionSheet |
| `SwiftUI/NewRelicSessionReplay/ExpenseEntryView.swift` | Expense entry (Picker, DatePicker, TextField) |
| `SwiftUI/NewRelicSessionReplay/ProviderSearchView.swift` | Searchable list with conditional rendering |
| `SwiftUI/NewRelicSessionReplay/ConfirmationView.swift` | Confirmation screen with Toggle and alert |
| `SwiftUI/NewRelicSessionReplay/Views.swift` | DocumentPickerView (UIViewControllerRepresentable), CameraView |
