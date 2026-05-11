#if DEBUG

import UIKit
import NewRelic

/// Drives the `SRDebugOverlayView`. On start, re-samples the SR capture every
/// 1.0s and pushes the flattened rects to the view. Kept as a plain class so
/// the Dev HUD window can hold it directly and toggle it.
@available(iOS 13.0, *)
@MainActor
final class SRDebugOverlayController {

    /// Weak global so the HUD's SwiftUI view model can reach the active controller
    /// without wiring through UIKit init chains.
    static weak var shared: SRDebugOverlayController?

    let view: SRDebugOverlayView
    private var timer: Timer?

    init(view: SRDebugOverlayView) {
        self.view = view
        Self.shared = self
    }

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        view.isHidden = false
        tick() // show something immediately
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        view.rects = []
        view.isHidden = true
    }

    private func tick() {
        let rects = NewRelic.debugSessionReplayManager()?.debugCaptureOverlayRects() ?? []
        view.rects = rects
    }
}

#endif
