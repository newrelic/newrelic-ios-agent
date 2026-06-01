//
//  NRMASessionDurationManager.swift
//  NewRelicAgent
//
//  Created by New Relic on 3/31/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

/**
 * Manages session duration tracking for automatic session termination.
 * This class is responsible for tracking when a session started and
 * determining if the session has exceeded the configured maximum duration.
 */
@objc
@objcMembers
public class NRMASessionDurationManager: NSObject {

    // MARK: - Singleton

    /// Shared singleton instance
    @objc
    public static let shared = NRMASessionDurationManager()

    // MARK: - Properties

    private let queue = DispatchQueue(label: "com.newrelic.sessionDurationManager", attributes: .concurrent)
    private var _sessionStartTime: Date?
    private var _maxSessionDuration: TimeInterval = 14400.0 // 4 hours in seconds

    private var sessionStartTime: Date? {
        get {
            queue.sync { _sessionStartTime }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?._sessionStartTime = newValue
            }
        }
    }

    /// Maximum session duration in seconds (default: 14400 = 4 hours)
    @objc
    public var maxSessionDuration: TimeInterval {
        get {
            queue.sync { _maxSessionDuration }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?._maxSessionDuration = newValue
            }
        }
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        // Initialize with current time
        sessionStartTime = Date()
        NRLOG_AGENT_DEBUG("SessionDurationManager: Initialized with session start time: \(sessionStartTime?.description ?? "nil"), max duration: \(_maxSessionDuration) seconds")
    }

    // MARK: - Public Methods

    /**
     * Updates the session start time to the provided date.
     * Call this whenever a new session begins.
     *
     * - Parameter startTime: The Date when the session started
     */
    @objc
    public func updateSessionStartTime(_ startTime: Date?) {
        guard let startTime = startTime else {
            NRLOG_ERROR("SessionDurationManager: Attempted to set nil session start time")
            return
        }

        sessionStartTime = startTime
        NRLOG_AGENT_DEBUG("SessionDurationManager: Updated session start time to: \(startTime)")
    }

    /**
     * Checks if the current session has exceeded the configured maximum duration.
     * Uses the maxSessionDuration property to determine the limit.
     *
     * - Returns: true if the session has exceeded the configured maximum duration, false otherwise
     */
    @objc
    public func hasSessionExceeded() -> Bool {
        guard let startTime = sessionStartTime else {
            NRLOG_AGENT_DEBUG("SessionDurationManager: No session start time set")
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let limit = queue.sync { _maxSessionDuration }
        let exceeded = elapsed >= limit

        if exceeded {
            NRLOG_AGENT_DEBUG("SessionDurationManager: Session duration (\(String(format: "%.0f", elapsed)) seconds) has exceeded limit (\(String(format: "%.0f", limit)) seconds)")
        }

        return exceeded
    }

    /**
     * Checks if the current session has exceeded the specified duration.
     * This method allows checking against a custom duration value.
     *
     * - Parameter durationInSeconds: The maximum allowed session duration in seconds
     * - Returns: true if the session has exceeded the duration, false otherwise
     */
    @objc
    public func hasSessionExceededDuration(_ durationInSeconds: TimeInterval) -> Bool {
        guard let startTime = sessionStartTime else {
            NRLOG_AGENT_DEBUG("SessionDurationManager: No session start time set")
            return false
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let exceeded = elapsed >= durationInSeconds

        if exceeded {
            NRLOG_AGENT_DEBUG("SessionDurationManager: Session duration (\(String(format: "%.0f", elapsed)) seconds) has exceeded limit (\(String(format: "%.0f", durationInSeconds)) seconds)")
        }

        return exceeded
    }

    /**
     * Returns the elapsed time of the current session in seconds.
     *
     * - Returns: The number of seconds elapsed since session start, or 0 if no session is active
     */
    @objc
    public func currentSessionDuration() -> TimeInterval {
        guard let startTime = sessionStartTime else {
            return 0.0
        }

        return Date().timeIntervalSince(startTime)
    }
}
