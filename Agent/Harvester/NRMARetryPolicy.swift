//
//  NRMARetryPolicy.swift
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

import Foundation

/// Why a failed request should (or should not) be retried.
@objc public enum NRMARetryReason: Int {
    /// Not retryable — stop the loop.
    case none
    /// No internet: suspend without consuming a retry attempt.
    case networkOffline
    /// Transient network error or 5xx — retry with exponential backoff.
    case transient
    /// HTTP 429 Rate Limit — retry using Retry-After or exponential backoff.
    case rateLimit
}

/// Shared retry policy for all New Relic harvest endpoints.
///
/// Encapsulates the retry decision and delay calculation so every uploader
/// (connect, data, hex, crash, logs) applies the same rules.  Exposed to ObjC
/// via `@objc` so it can be used from both Swift and Objective-C callers.
/// Inject a custom instance via the uploader's `retryPolicy` property for testing.
@objc
@objcMembers
public class NRMARetryPolicy: NSObject {

    // MARK: - Configuration

    /// Base delay for exponential backoff: delay = initialRetryDelay * 2^attempt.
    public var initialRetryDelay: TimeInterval = 1.0

    /// Upper cap on the computed delay.
    public var maxRetryDelay: TimeInterval = 16.0

    /// Maximum retries in foreground. Delays: 1s, 2s, 4s, 8s, 16s — total ≤31s.
    public var maxForegroundRetries: Int = 5

    /// Maximum retries in background. No delay to respect OS time limits.
    public var maxBackgroundRetries: Int = 1

    // MARK: - Singleton

    /// The default shared policy. Override per-uploader for testing.
    @objc public static let shared = NRMARetryPolicy()

    // MARK: - Private error/status constants

    // NSURLError codes indicating transient connectivity failures.
    private static let retryableNetworkErrors: Set<Int> = [
        NSURLErrorTimedOut,               // -1001: connection timeout
        NSURLErrorCannotFindHost,         // -1003: DNS resolution failure
        NSURLErrorCannotConnectToHost,    // -1004: connection refused
        NSURLErrorNetworkConnectionLost,  // -1005: connection reset
        NSURLErrorDNSLookupFailed,        // -1006: DNS lookup failure
        NSURLErrorSecureConnectionFailed  // -1200: transient SSL/TLS error
    ]

    // HTTP status codes that merit a retry.
    private static let retryableStatusCodes: Set<Int> = [500, 502, 503, 504]

    // MARK: - Public API

    /// Returns why (if at all) the given response should be retried.
    ///
    /// Pass `error: nil` when the transport succeeded but the HTTP status code
    /// is what you want to classify. Pass `statusCode: 0` when the transport
    /// produced an error and no HTTP status is available.
    @objc(retryReasonForError:statusCode:)
    public func retryReason(forError error: NSError?, statusCode: Int) -> NRMARetryReason {
        if let error = error {
            if error.code == NSURLErrorNotConnectedToInternet { return .networkOffline }
            if Self.retryableNetworkErrors.contains(error.code) { return .transient }
            return .none
        }
        if statusCode == 429 { return .rateLimit }
        if Self.retryableStatusCodes.contains(statusCode) { return .transient }
        return .none
    }

    /// Returns the seconds to wait before retry attempt N (0-indexed).
    ///
    /// - Returns 0 when `isBackground` is true — background tasks must not delay.
    /// - For 429, honours the parsed `retryAfterSeconds` value when present,
    ///   capped at `maxRetryDelay`.
    /// - Otherwise uses exponential backoff: initialRetryDelay × 2^attempt, capped.
    @objc(delayForAttempt:statusCode:retryAfterSeconds:isBackground:)
    public func delay(forAttempt attempt: Int,
                      statusCode: Int,
                      retryAfterSeconds: TimeInterval,
                      isBackground: Bool) -> TimeInterval {
        guard !isBackground else { return 0 }
        if statusCode == 429 && retryAfterSeconds > 0 {
            return min(retryAfterSeconds, maxRetryDelay)
        }
        let d = initialRetryDelay * pow(2.0, Double(attempt))
        return min(d, maxRetryDelay)
    }

    /// Returns the maximum number of retries for the current app state.
    @objc(maxRetriesIsBackground:)
    public func maxRetries(isBackground: Bool) -> Int {
        isBackground ? maxBackgroundRetries : maxForegroundRetries
    }
}
