# UIKit Compatibility — New Relic Mobile Session Replay

This document covers which UIKit components are captured, masked, and tracked by the New Relic Mobile Session Replay (MSR) system, based on the view captor implementations and test harness.

---

## How UIKit Capture Works

The agent walks the UIKit view hierarchy starting from the key window's root view. Each view is matched against a set of **ViewThingy** captors. Unrecognized views fall through to the base `UIViewThingy`. The captured tree is serialized into the RRWeb snapshot format for replay.

**View Captors (Agent/SessionReplay/ViewCaptors/):**

| Captor | Handles |
|---|---|
| `UILabelThingy` | `UILabel`, `RCTParagraphComponentView` (React Native) |
| `UITextFieldThingy` | `UITextField` |
| `UITextViewThingy` | `UITextView` |
| `UISwitchThingy` | `UISwitch` |
| `UIDatePickerThingy` | `UIDatePicker` |
| `UIImageViewThingy` | `UIImageView` |
| `UIVisualEffectViewThingy` | `UIVisualEffectView` (blur/vibrancy) |
| `SwiftUIShapeThingy` | Shape layers in SwiftUI-hosted views |
| `SwiftUIDrawingThingy` | Canvas drawings in SwiftUI-hosted views |
| `CustomTextThingy` | Custom text-rendering views |
| `UIViewThingy` | All other `UIView` subclasses (base fallback) |

Touch events are captured by `SessionReplayTouchCapture` and processed by `SessionReplayTouchEventProcessor`. Touch positions are normalized to the recording coordinate space.

---

## Component Compatibility

### Text Display

| Component | Captured | Masked by Default | Masking Config Key | Notes |
|---|---|---|---|---|
| `UILabel` | ✅ | No | `maskApplicationText` | Text, font (name/size/family/weight), color, alignment, line break mode, letter spacing captured; attributed text fully supported |
| `UITextView` | ✅ | No | `maskUserInputText` | Text, font, color captured; editable state detected; input replaced with `*` when masked |
| Custom text-rendering view | ✅ | No | `maskApplicationText` | `CustomTextThingy` handles views that render text outside `UILabel` |
| React Native `RCTParagraphComponentView` | ✅ | No | `maskApplicationText` | `UILabelThingy` includes explicit support via class name detection |

### Input Controls

| Component | Captured | Masked by Default | Masking Config Key | Notes |
|---|---|---|---|---|
| `UITextField` | ✅ | No | `maskUserInputText` | Text, placeholder, font, color, isSecureTextEntry captured; secure fields always masked; input masked with `*` when `maskUserInputText` is true |
| `UITextField` (secure / password) | ✅ | Yes (auto) | N/A — always masked | `isSecureTextEntry` detection forces masking regardless of config |
| `UITextView` (editable) | ✅ | No | `maskUserInputText` | Same masking behavior as UITextField for editable text views |
| `UISearchBar` | ⚠️ | No | `maskUserInputText` | Internally uses `UITextField`; partial capture via text field detection |

### Switches & Toggles

| Component | Captured | Notes |
|---|---|---|
| `UISwitch` | ✅ | `isOn` state, `onTintColor`, `offTintColor` (derived), `thumbTintColor` captured; rendered in replay as pill-shaped checkbox element with correct colors and state |
| Custom `UIControl` subclass mimicking switch | ⚠️ | Falls back to `UIViewThingy`; visual shape approximated; state not captured semantically |

### Date & Time Pickers

| Component | Captured | Masked by Default | Notes |
|---|---|---|---|
| `UIDatePicker` (wheel style) | ✅ | No | Aggressive subview clipping skipped for wheel style to prevent visual artifacts; respects `maskUserInputText` |
| `UIDatePicker` (graphical / calendar style) | ✅ | No | Captured as div DOM node; selected date masked when `maskUserInputText` is true |
| `UIDatePicker` (compact style) | ✅ | No | Respects `maskUserInputText` |
| `UIDatePicker` (countdown timer style) | ⚠️ | No | Captured as generic view node |

### Image Views

| Component | Captured | Masked by Default | Masking Config Key | Notes |
|---|---|---|---|---|
| `UIImageView` | ✅ | No | `maskAllImages` | Image rendered as `<img>` node in RRWeb; replaced with gray placeholder when `maskAllImages` is true; supports PNG data encoding |
| `UIImageView` with tinted SF Symbols | ✅ | No | `maskAllImages` | Tint color captured; `TintedImagesViewController` test coverage |
| `UIImageView` (async / downloaded) | ✅ | No | `maskAllImages` | Captured when image is in-tree at snapshot time |

### Visual Effects

| Component | Captured | Notes |
|---|---|---|
| `UIVisualEffectView` (blur) | ✅ | Effect style (light/dark/extraLight, prominent, regular) captured in DOM node; rendered in replay with appropriate blur approximation |
| `UIVisualEffectView` (vibrancy) | ✅ | Captured; vibrancy effect noted in DOM attributes |

### Collection & List Views

| Component | Captured | Notes |
|---|---|---|
| `UITableView` | ✅ | Rows captured as individual cell nodes; visible cells only (off-screen cells not in snapshot) |
| `UITableViewCell` | ✅ | Content view and subviews captured recursively |
| `UICollectionView` | ✅ | Visible cells captured; `ScrollableCollectionViewController` uses 3-column flow layout |
| `UICollectionViewCell` | ✅ | Cell subviews captured; `ColorCollectionViewCell` (label + blur) tested |
| `UIScrollView` | ✅ | Scroll position not encoded; content at scroll origin captured |

### Navigation & Containers

| Component | Captured | Notes |
|---|---|---|
| `UINavigationController` / `UINavigationBar` | ✅ | Navigation bar title and buttons captured as view nodes |
| `UITabBarController` / `UITabBar` | ✅ | Tab bar items captured; selected state included |
| `UIViewController` (generic) | ✅ | View hierarchy captured from `view` property root |
| `UIHostingController` (SwiftUI bridge) | ✅ | Detected by `ControllerTypeDetector`; SwiftUI subtree captured via `UIHostingViewRecordOrchestrator` |

### Overlays & Presentations

| Component | Captured | Notes |
|---|---|---|
| `UIAlertController` (alert style) | ⚠️ | System-rendered; may appear as an overlay view; content not structured in snapshot |
| `UIAlertController` (action sheet) | ⚠️ | System-rendered overlay; partial capture |
| `UIActivityViewController` | ❌ | System share sheet not captured |
| `UIDocumentPickerViewController` | ❌ | System document picker not captured |
| Modal `UIViewController` (custom) | ✅ | Presented controller's view hierarchy captured normally |

### Web Content

| Component | Captured | Notes |
|---|---|---|
| `WKWebView` | ⚠️ | View frame captured as a node; web page DOM content is **not** replayed — only the native chrome around it |
| `UIWebView` (deprecated) | ❌ | Not supported |

---

## Masking & Privacy

### Global Configuration Keys

Set at agent initialization or via `NewRelicConfig`:

| Key | Type | Effect |
|---|---|---|
| `maskApplicationText` | Bool | Replaces all `UILabel` and static text content with `*` |
| `maskUserInputText` | Bool | Replaces all `UITextField`, `UITextView`, and `UIDatePicker` user-entered values with `*` |
| `maskAllImages` | Bool | Replaces all `UIImageView` content with a gray placeholder |
| `maskAllUserTouches` | Bool | Suppresses all touch event recording |

### BlockView

Setting `blockView: true` on a `ViewDetails` record (or using `NRConditionalMaskView(blockView: true)` in SwiftUI) replaces the entire subtree with an opaque black block in the replay. This is the strongest privacy option.

### Pause / Resume Recording

`ConfidentialViewController` demonstrates the recommended pattern for screens containing sensitive data that cannot be masked at the view level:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    NewRelic.pauseReplay()
}

override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    NewRelic.recordReplay()
}
```

This completely pauses the session replay recording while the screen is visible and resumes it when the user navigates away. Use this for screens displaying SSNs, credit card numbers, account credentials, or any content that cannot be selectively masked.

---

## Recording Modes

| Mode | Behavior |
|---|---|
| `off` | No recording; replay disabled |
| `error` | 15-second circular buffer maintained in memory; automatically promotes to `full` when an error/crash is detected |
| `full` | Continuous recording; data uploaded every 60 seconds |

Frame capture details:
- Full snapshot every **15 seconds** (forced regardless of diffs)
- Incremental diffs between full snapshots
- Circular buffer max **32 frames** (~30 seconds at ~1 fps)
- Background file I/O queue for frame persistence
- Auto-prune interval: **30 seconds**

---

## Touch Event Tracking

Touch events are recorded by `SessionReplayTouchCapture` unless `maskAllUserTouches` is true. Each event includes:

| Property | Details |
|---|---|
| Phase | `.began`, `.moved`, `.ended` |
| Location | Normalized screen coordinates |
| Timestamp | Unix epoch ms |

Touch positions are sanitized — they encode location but not identity or biometric data.

---

## Test Harness UIKit Files

| File | What Is Tested |
|---|---|
| `ViewControllers/ViewController.swift` | Main demo hub; UIStackView, UIImageView (NASA APOD), SecureLabel/UnsecureLabel, UITableView options menu (~20 entries), BlockView examples |
| `ViewControllers/ConfidentialViewController.swift` | `pauseReplay()` / `recordReplay()` pattern; sensitive field display (SSN, CC, password) |
| `ViewControllers/SwitchTestViewController.swift` | UISwitch (default, custom `onTintColor`, custom `thumbTintColor`, off-state); `CustomSwitch` subclass; ScrollView layout |
| `ViewControllers/DateTimePickerViewController.swift` | UIDatePicker (wheel date + wheel time); formatted output display |
| `ViewControllers/InfiniteScrollViewController.swift` | UITableView with pagination (25 items/page, 1.5s simulated network delay) |
| `ViewControllers/ScrollableCollectionViewController.swift` | UICollectionView with flow layout (3 columns); 100 color-coded cells with `UIBlurEffect` |
| `ViewControllers/WebViewController.swift` | WKWebView (newrelic.com); navigation delegate; auth challenge handling |
| `ViewControllers/AttributedTextTestViewController.swift` | UILabel with attributed text (multiple fonts/colors/runs) |
| `ViewControllers/TintedImagesViewController.swift` | UIImageView with tinted SF Symbols |
| `ViewControllers/InfiniteImageCollectionViewController.swift` | UICollectionView with async image loading and infinite scroll |
| `ViewControllers/ImageFullScreen.swift` | Full-screen UIImageView presentation |

---

## Known Limitations & Notes

| Limitation | Details |
|---|---|
| `UIAlertController` | System-rendered; content not structured in RRWeb snapshot |
| `WKWebView` DOM | Web page DOM content not replayed — only the native frame |
| Off-screen cells | `UITableView` and `UICollectionView` off-screen cells are not in snapshots |
| `UISearchBar` | Partial; captured via internal `UITextField` detection |
| Custom `UIControl` subclasses | Fall back to `UIViewThingy`; semantic state (value, selected) not captured |
| `UIActivityViewController` | System overlay; not captured |
| `UIWebView` (deprecated) | Not supported |
| Scroll position | `UIScrollView` content offset is not encoded in frame data |
| Countdown `UIDatePicker` | Captured as generic view; timer value not semantically structured |
