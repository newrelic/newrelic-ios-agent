//
//  SymbolToolError.swift
//  2026 New Relic
//

import Foundation

/// Errors raised while turning a dSYM into a map file or uploading it.
///
/// Most failures make the pipeline fall back to uploading the zipped dSYM instead; the message is
/// what ends up in `upload_dsym_results.log`.
enum SymbolToolError: Error, CustomStringConvertible, Equatable {
    case conversionFailed(String)
    case archiveFailed(String)
    case uploadFailed(String)
    /// The upload failed in a way a dSYM upload would hit too (rejected app token, unreachable host).
    case uploadRejected(String)

    var description: String {
        switch self {
        case .conversionFailed(let reason): return "Error in conversion: \(reason)"
        case .archiveFailed(let reason): return "Error creating archive: \(reason)"
        case .uploadFailed(let reason), .uploadRejected(let reason): return "Error uploading: \(reason)"
        }
    }

    var shouldFallBackToDSYMUpload: Bool {
        if case .uploadRejected = self { return false }
        return true
    }
}
