//
//  Logger.swift
//  2026 New Relic
//

import Foundation

/// Writes progress to stdout, which the `run-symbol-tool` wrapper redirects to `upload_dsym_results.log`.
struct Logger {
    let isDebugEnabled: Bool
    private let write: (String) -> Void

    init(debug: Bool = false, write: @escaping (String) -> Void = { print($0) }) {
        self.isDebugEnabled = debug
        self.write = write
    }

    func info(_ message: @autoclosure () -> String) {
        write(message())
    }

    func debug(_ message: @autoclosure () -> String) {
        guard isDebugEnabled else { return }
        write(message())
    }

    /// Masks a secret for display, keeping a short prefix (which carries the region, e.g. `eu01xx`)
    /// so `--debug` logs can be shared with support.
    static func mask(_ secret: String) -> String {
        let visibleCount = secret.count > 8 ? 6 : 0
        return String(secret.prefix(visibleCount)) + String(repeating: "*", count: secret.count - visibleCount)
    }
}
