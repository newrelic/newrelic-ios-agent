// NewRelic+Helpers.swift
import Foundation
@_implementationOnly import NewRelicPrivate

extension NewRelic {

    // MARK: - Helpers for trying out New Relic features

    @objc(crashNow:)
    public static func crashNow(_ message: String?) {
        // If Agent is shutdown we shouldn't respond.
        if NewRelicAgentInternal.sharedInstance()?.isShutdown ?? false {
            return
        }
        NSException(
            name: NSExceptionName("NewRelicDemoException"),
            reason: message ?? "This is a demo crash from +[NewRelic demoCrash:]",
            userInfo: nil
        ).raise()
    }

    @objc(crashNow)
    public static func crashNow() {
        crashNow(nil)
    }
}
