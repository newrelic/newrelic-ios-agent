//
//  NRMASessionManager.swift
//  NewRelicAgent
//
//  Created by New Relic on 11/21/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

/// Manages mobile session lifecycle including:
/// - 4-hour maximum session duration
/// - 30-minute inactivity timeout
@objc public class NRMASessionManager: NSObject {
    
    // MARK: - Singleton
    
    /// Shared instance of the session manager
    @objc public static let shared = NRMASessionManager()
    
    // MARK: - Constants
    
    private static let defaultMaxSessionDuration: TimeInterval = 4 * 60 * 60 // 4 hours in seconds
    private static let defaultInactivityTimeout: TimeInterval = 30 * 60   // 30 minutes in seconds
    
    // MARK: - Properties
    
    /// The timestamp when the current session started (in milliseconds since epoch)
    @objc public private(set) var sessionStartTimeMS: Int64 = 0
    
    /// The timestamp of the last recorded user activity (in milliseconds since epoch)
    @objc public private(set) var lastActivityTimeMS: Int64 = 0
    
    @objc public private(set) var lastBackgroundTimeMS: Int64 = 0
    
    /// Maximum session duration in seconds (default: 4 hours = 14400 seconds)
    @objc public var maxSessionDuration: TimeInterval = defaultMaxSessionDuration
    
    /// Inactivity timeout in seconds (default: 30 minutes = 1800 seconds)
    @objc public var inactivityTimeout: TimeInterval = defaultInactivityTimeout
    
    private let sessionQueue = DispatchQueue(label: "com.newrelic.sessionManager", attributes: [])
    
    // MARK: - Session Lifecycle
    
    /// Start a new session with the current timestamp
    @objc public func startNewSession() {
        let currentTime = NRMASessionManager.currentTimeMillis()
        startNewSession(withStartTime: currentTime)
    }
    
    /// Start a new session with a specific start time
    @objc public func startNewSession(withStartTime startTimeMS: Int64) {
        sessionQueue.sync {
            self.sessionStartTimeMS = startTimeMS
            self.lastActivityTimeMS = startTimeMS
            self.lastBackgroundTimeMS = 0
            
            NRLOG_DEBUG("New session started at: \(startTimeMS)")
        }
    }
    
    /// Record user activity
    @objc public func recordActivity() {
        sessionQueue.async {
            self.lastActivityTimeMS = NRMASessionManager.currentTimeMillis()
            NRLOG_DEBUG("Activity recorded at: \(self.lastActivityTimeMS)")
        }
    }
    
    /// Record last background timestamp
    @objc public func recordBackgroundTimestamp() {
        sessionQueue.async {
            self.lastBackgroundTimeMS = NRMASessionManager.currentTimeMillis()
            NRLOG_DEBUG("Background timestamp recorded at: \(self.lastBackgroundTimeMS)")
        }
    }
    
    // MARK: - Session Validation
    
    /// Check if the current session should end due to duration or inactivity
    /// - Returns: true if session should end, false otherwise
    @objc public func shouldEndSession() -> Bool {
        var shouldEnd = false
        sessionQueue.sync {
            shouldEnd = hasExceededMaxDuration() // || hasExceededInactivityTimeout()
        }
        return shouldEnd
    }
    
    /// Check if the current session should end due to background timeout
    /// - Returns: true if session should end, false otherwise
    @objc public func shouldEndSessionFromBackground() -> Bool {
        var shouldEnd = false
        sessionQueue.sync {
            shouldEnd = hasExceededBackgroundTimeout()
        }
        return shouldEnd
    }
    
    /// Check if session has exceeded maximum duration
    /// - Returns: true if duration exceeded, false otherwise
    @objc public func hasExceededMaxDuration() -> Bool {
        let currentTime = NRMASessionManager.currentTimeMillis()
        let sessionDurationMS = currentTime - sessionStartTimeMS
        let sessionDurationSeconds = TimeInterval(sessionDurationMS) / 1000.0
        
        let exceeded = sessionDurationSeconds >= maxSessionDuration
        if exceeded {
            NRLOG_DEBUG(String(format: "Session exceeded max duration: %.2f seconds (limit: %.2f seconds)",
                                      sessionDurationSeconds, maxSessionDuration))
        }
        return exceeded
    }
    
    /// Check if session has exceeded inactivity timeout
    /// - Returns: true if inactivity exceeded, false otherwise
    @objc public func hasExceededInactivityTimeout() -> Bool {
        let currentTime = NRMASessionManager.currentTimeMillis()
        let inactivityDurationMS = currentTime - lastActivityTimeMS
        let inactivityDurationSeconds = TimeInterval(inactivityDurationMS) / 1000.0
        
        let exceeded = inactivityDurationSeconds >= inactivityTimeout
        if exceeded {
            NRLOG_DEBUG(String(format: "Session exceeded inactivity timeout: %.2f seconds (limit: %.2f seconds)",
                                      inactivityDurationSeconds, inactivityTimeout))
        }
        return exceeded
    }
    
    /// Check if session has exceeded background timeout
    /// - Returns: true if background exceeded, false otherwise
    @objc public func hasExceededBackgroundTimeout() -> Bool {
        if lastBackgroundTimeMS == 0 {
            return true
        }
        let currentTime = NRMASessionManager.currentTimeMillis()
        let backgroundDurationMS = currentTime - lastBackgroundTimeMS
        let backgroundDurationSeconds = TimeInterval(backgroundDurationMS) / 1000.0
        
        let exceeded = backgroundDurationSeconds >= inactivityTimeout
        if exceeded {
            NRLOG_DEBUG(String(format: "Session exceeded background timeout: %.2f seconds (limit: %.2f seconds)",
                               backgroundDurationSeconds, inactivityTimeout))
        }
        return exceeded
    }
    
    // MARK: - Utility Methods
    
    /// Get current time in milliseconds since epoch
    @objc public static func currentTimeMillis() -> Int64 {
        var time = timeval()
        gettimeofday(&time, nil)
        return Int64(time.tv_sec) * 1000 + Int64(time.tv_usec) / 1000
    }
}
