#if DEBUG

import Foundation
import SwiftUI
import NewRelic

@available(iOS 15.0, *)
@MainActor
final class SRDevHUDViewModel: ObservableObject {
    @Published var modeText: String = "-"
    @Published var isRunning: Bool = false
    @Published var isManual: Bool = false
    @Published var harvestPeriod: Int = 60
    @Published var lastHarvestText: String = "never"
    @Published var sessionIdShort: String = "-"

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func forceHarvest() {
        NewRelic.debugSessionReplayManager()?.harvest()
        refresh()
    }

    func toggle() {
        guard let mgr = NewRelic.debugSessionReplayManager() else { return }
        if mgr.isRunning() {
            _ = mgr.manualPauseReplay()
        } else {
            _ = mgr.manualRecordReplay()
        }
        refresh()
    }

    private func refresh() {
        let mgr = NewRelic.debugSessionReplayManager()
        modeText = Self.describe(mgr?.getCurrentRecordingMode())
        isRunning = mgr?.isRunning() ?? false
        isManual = mgr?.isManuallyActive() ?? false
        harvestPeriod = Int(mgr?.harvestPeriod ?? 60)

        if let d = mgr?.lastHarvestDate {
            let secs = Int(Date().timeIntervalSince(d))
            lastHarvestText = "\(secs)s ago"
        } else {
            lastHarvestText = "never"
        }

        let sid = NewRelic.currentSessionId() ?? "-"
        sessionIdShort = sid.count > 8 ? String(sid.suffix(8)) : sid
    }

    private static func describe(_ mode: SessionReplayRecordingMode?) -> String {
        guard let mode = mode else { return "-" }
        switch mode {
        case .off: return "off"
        case .error: return "error"
        case .full: return "full"
        @unknown default: return "?"
        }
    }
}

#endif
