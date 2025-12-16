//
//  SessionReplayErrorListener.swift
//  Agent_iOS
//
//  Created by New Relic
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

/// Listens for error events and triggers session replay error mode transitions
@available(iOS 13.0, *)
@objcMembers
public class SessionReplayErrorListener: NSObject {

    /// Shared singleton instance
    public static let shared = SessionReplayErrorListener()

    /// Weak reference to the session replay manager
    private weak var sessionReplayManager: SessionReplayManager?

    /// Flag to prevent multiple error triggers in quick succession
    private var errorTriggered = false

    /// Lock for thread safety
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    /// Registers the session replay manager to receive error notifications
    /// - Parameter manager: The SessionReplayManager instance
    public func register(sessionReplayManager manager: SessionReplayManager) {
        lock.lock()
        defer { lock.unlock() }

        self.sessionReplayManager = manager
        NRLOG_DEBUG("SessionReplayErrorListener registered with SessionReplayManager")
    }

    /// Unregisters the session replay manager
    public func unregister() {
        lock.lock()
        defer { lock.unlock() }

        self.sessionReplayManager = nil
        errorTriggered = false
        NRLOG_DEBUG("SessionReplayErrorListener unregistered")
    }

    /// Resets the error trigger flag (called at session boundaries)
    public func resetErrorTrigger() {
        lock.lock()
        defer { lock.unlock() }

        errorTriggered = false
    }

    // MARK: - Error Event Handlers

    /// Called when a handled exception is recorded
    /// - Parameters:
    ///   - exception: The exception that was caught
    ///   - attributes: Additional attributes about the exception
    public func onHandledException(_ exception: NSException, attributes: [AnyHashable: Any]? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard !errorTriggered else {
            NRLOG_DEBUG("Error already triggered, skipping additional exception")
            return
        }

        guard let manager = sessionReplayManager else {
            NRLOG_DEBUG("No SessionReplayManager registered")
            return
        }
#if os(iOS) || os(tvOS)

        let currentMode = manager.getCurrentRecordingMode()
        if currentMode == .error {
            NRLOG_DEBUG("Handled exception detected: \(exception.name.rawValue) - triggering session replay")
            errorTriggered = true
            manager.onErrorDetected()
        }
        #endif
    }

    /// Called when an NSError is recorded
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attributes: Additional attributes about the error
    public func onError(_ error: NSError, attributes: [AnyHashable: Any]? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard !errorTriggered else {
            NRLOG_DEBUG("Error already triggered, skipping additional error")
            return
        }

        guard let manager = sessionReplayManager else {
            NRLOG_DEBUG("No SessionReplayManager registered")
            return
        }
#if os(iOS) || os(tvOS)

        let currentMode = manager.getCurrentRecordingMode()
        if currentMode == .error {
            NRLOG_DEBUG("Error detected: \(error.domain):\(error.code) - triggering session replay")
            errorTriggered = true
            manager.onErrorDetected()
        }
        #endif
    }

    //NOT DOING NETWORK ERRORS
    
//    /// Called when a network error occurs
//    /// - Parameters:
//    ///   - statusCode: HTTP status code (if applicable)
//    ///   - error: The network error
//    ///   - request: The network request that failed
//    public func onNetworkError(statusCode: Int? = nil, error: NSError?, request: URLRequest?) {
//        lock.lock()
//        defer { lock.unlock() }
//
//        guard !errorTriggered else {
//            NRLOG_DEBUG("Error already triggered, skipping network error")
//            return
//        }
//
//        guard let manager = sessionReplayManager else {
//            NRLOG_DEBUG("No SessionReplayManager registered")
//            return
//        }
//
//        let currentMode = manager.getCurrentRecordingMode()
//        if currentMode == .error {
//            // Determine if this is an error worth triggering session replay
//            var shouldTrigger = false
//
//            if let status = statusCode, status >= 400 {
//                shouldTrigger = true
//                NRLOG_DEBUG("HTTP error \(status) detected - triggering session replay")
//            }
//            else if let err = error {
//                shouldTrigger = true
//                NRLOG_DEBUG("Network error detected: \(err.domain):\(err.code) - triggering session replay")
//            }
//
//            if shouldTrigger {
//                errorTriggered = true
//                manager.onErrorDetected()
//            }
//        }
//    }

    /// Called when a log error occurs (if Log.error integration is added)
    /// - Parameters:
    ///   - message: The error message
    ///   - file: Source file where error occurred
    ///   - line: Line number where error occurred
    public func onLogError(message: String, file: String, line: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard !errorTriggered else {
            NRLOG_DEBUG("Error already triggered, skipping log error")
            return
        }

        guard let manager = sessionReplayManager else {
            NRLOG_DEBUG("No SessionReplayManager registered")
            return
        }
#if os(iOS) || os(tvOS)

        let currentMode = manager.getCurrentRecordingMode()
        if currentMode == .error {
            NRLOG_DEBUG("Log error detected: \(message) - triggering session replay")
            errorTriggered = true
            manager.onErrorDetected()
        }
        #endif
    }
}
