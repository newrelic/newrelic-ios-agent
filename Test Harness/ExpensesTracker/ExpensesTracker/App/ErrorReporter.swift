//
//  ErrorReporter.swift
//  ExpensesTracker
//
//  Port of the Android app's utils/ErrorReporter — the two-line helper it used everywhere it wanted
//  a handled error in New Relic with a little context attached.
//
//  The Android version called NewRelic.recordHandledException(e, attributes). On iOS the closest
//  equivalent for a Swift error is NewRelic.recordError(_:attributes:); recordHandledException takes
//  an NSException, which Swift code does not throw. Both land in the same place in the product
//  (MobileHandledException), so the shape of the helper survives the port intact.
//

import Foundation
import NewRelic

enum ErrorReporter {

    /// Reports a caught error to New Relic, tagged with where it came from.
    ///
    /// - Parameters:
    ///   - error: the error that was caught.
    ///   - source: where it happened, e.g. the view controller's name.
    ///   - additionalInfo: any extra context; omitted from the attributes when empty.
    static func reportHandled(_ error: Error,
                              source: String,
                              additionalInfo: String? = nil) {
        appLog("[ExpensesTracker] Error in \(source): \(error.localizedDescription)")

        var attributes: [String: Any] = ["error_source": source]
        if let additionalInfo, !additionalInfo.isEmpty {
            attributes["additional_info"] = additionalInfo
        }

        NewRelic.recordError(error, attributes: attributes)
    }

    /// Records an error-shaped custom event when there is no actual error object to report — the
    /// Android `recordErrorEvent` case.
    static func recordErrorEvent(type: String,
                                 source: String,
                                 message: String,
                                 severity: String) {
        appLog("[ExpensesTracker] \(source) — \(type): \(message)")

        NewRelic.recordCustomEvent("ErrorEvent", attributes: [
            "error_type": type,
            "error_source": source,
            "message": message,
            "severity": severity
        ])
    }
}
