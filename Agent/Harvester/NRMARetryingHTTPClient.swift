//
//  NRMARetryingHTTPClient.swift
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

// Completion type used by all upload methods.
// Called exactly once with the terminal outcome after all retry attempts.
public typealias NRMAUploadCompletion = @convention(block) (Data?, HTTPURLResponse?, Error?) -> Void

/// A per-instance HTTP upload client with built-in exponential-backoff retry,
/// offline detection, and supportability metric emission.
///
/// Every New Relic upload path (connect, data, hex, crash, logs) holds its own
/// instance so it can tune the URLSession configuration independently while
/// sharing the same retry semantics via the injected `retryPolicy`.
///
/// **Ownership** — the caller creates and retains the client; call `invalidate()`
/// before releasing to cancel any in-flight tasks and close the session.
///
/// **Threading** — `upload(...)` may be called from any thread. The internal
/// retry scheduling runs on a private serial queue. The `completion` block is
/// also dispatched on that queue; callers that need a specific queue must
/// dispatch themselves.
@objc
@objcMembers
public class NRMARetryingHTTPClient: NSObject {

    // MARK: - Public configuration

    /// Policy used for retry decisions and delay calculation. Injected at init
    /// so tests can substitute a fast-cycling policy without touching singletons.
    public let retryPolicy: NRMARetryPolicy

    // MARK: - Constants

    /// 1 MB payload limit shared by all upload paths.
    public static let maxPayloadSizeBytes = kNRMAMaxPayloadSizeLimit

    // MARK: - Init

    /// Designated initialiser. Pass a custom `URLSession` to control timeout,
    /// max connections per host, etc. Pass a custom `retryPolicy` for tests.
    @objc public init(session: URLSession, retryPolicy: NRMARetryPolicy) {
        self.session  = session
        self.retryPolicy = retryPolicy
        super.init()
    }

    /// Convenience init with sensible defaults (standard `URLSession`, fresh policy).
    @objc public convenience override init() {
        self.init(session: URLSession(configuration: .default),
                  retryPolicy: NRMARetryPolicy())
    }

    // MARK: - Upload API

    /// Uploads `data` to `request`, retrying on transient failures.
    /// `completion` is called exactly once with the terminal outcome.
    @objc(uploadRequest:data:endpoint:completion:)
    public func upload(request: URLRequest,
                       data: Data,
                       endpoint: String,
                       completion: @escaping NRMAUploadCompletion) {
        scheduleAttempt(request: request, body: .data(data), endpoint: endpoint,
                        attempt: 0, offlinePollCount: 0, completion: completion)
    }

    /// Uploads the file at `fileURL` to `request`, retrying on transient failures.
    /// `completion` is called exactly once with the terminal outcome.
    @objc(uploadRequest:fileURL:endpoint:completion:)
    public func upload(request: URLRequest,
                       fileURL: URL,
                       endpoint: String,
                       completion: @escaping NRMAUploadCompletion) {
        scheduleAttempt(request: request, body: .file(fileURL), endpoint: endpoint,
                        attempt: 0, offlinePollCount: 0, completion: completion)
    }

    /// Cancels all in-flight tasks and invalidates the underlying `URLSession`.
    /// The client must not be used after this call.
    @objc public func invalidate() {
        session.invalidateAndCancel()
    }

    // MARK: - Private state

    private let session: URLSession
    private let queue = DispatchQueue(label: "com.newrelic.retrying-http-client", qos: .utility)

    // Offline polling: retry every 5 s, up to 60 s (12 polls) before consuming an attempt.
    private static let offlinePollInterval: TimeInterval = 5
    private static let maxOfflinePolls = 12

    // MARK: - Upload body

    private enum Body {
        case data(Data)
        case file(URL)
    }

    // MARK: - Core retry loop

    private func scheduleAttempt(request: URLRequest,
                                  body: Body,
                                  endpoint: String,
                                  attempt: Int,
                                  offlinePollCount: Int,
                                  completion: @escaping NRMAUploadCompletion) {
        let task: URLSessionUploadTask
        // Handle the result directly on the URLSession callback thread rather than
        // hopping to the internal queue. URLSession calls back at an appropriate
        // priority; adding a fixed-QoS hop here causes a priority inversion when a
        // higher-priority thread (e.g. the harvest thread at User-initiated QoS) is
        // blocked on a semaphore waiting for this completion to fire.
        // The internal `queue` is still used only for asyncAfter retry delays, where
        // no thread is blocked on it.
        let handler: (Data?, URLResponse?, Error?) -> Void = { [weak self] data, response, error in
            self?.handleResult(data: data, response: response, error: error,
                               request: request, body: body, endpoint: endpoint,
                               attempt: attempt, offlinePollCount: offlinePollCount,
                               completion: completion)
        }
        switch body {
        case .data(let d):    task = session.uploadTask(with: request, from: d, completionHandler: handler)
        case .file(let url):  task = session.uploadTask(with: request, fromFile: url, completionHandler: handler)
        }
        task.resume()
    }

    private func handleResult(data: Data?,
                               response: URLResponse?,
                               error: Error?,
                               request: URLRequest,
                               body: Body,
                               endpoint: String,
                               attempt: Int,
                               offlinePollCount: Int,
                               completion: @escaping NRMAUploadCompletion) {
        let http   = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let nsErr  = error as NSError?

        let isBackground = isAppInBackground()
        let maxRetries   = retryPolicy.maxRetries(isBackground: isBackground)
        let reason       = retryPolicy.retryReason(forError: nsErr, statusCode: status)

        // ── Terminal: success or a non-retryable HTTP error ──────────────────
        if reason == .none {
            emitOutcomeMetrics(endpoint: endpoint, attempt: attempt, status: status, error: nsErr)
            completion(data, http, error)
            return
        }

        // ── Offline: poll for connectivity before consuming an attempt ────────
        if reason == .networkOffline && offlinePollCount < Self.maxOfflinePolls {
            NRMASupportMetricHelper.enqueueHarvestRetryNetworkSuspendedMetric(endpoint)
            NRLOG_AGENT_DEBUG("HTTP Client: no internet — suspending \(endpoint) (poll \(offlinePollCount + 1)/\(Self.maxOfflinePolls))")
            queue.asyncAfter(deadline: .now() + Self.offlinePollInterval) { [weak self] in
                self?.scheduleAttempt(request: request, body: body, endpoint: endpoint,
                                      attempt: attempt, offlinePollCount: offlinePollCount + 1,
                                      completion: completion)
            }
            return
        }

        // ── Retries exhausted (includes offline-poll timeout) ─────────────────
        if attempt >= maxRetries {
            NRMASupportMetricHelper.enqueueHarvestRetryFailedMetric(endpoint)
            NRMASupportMetricHelper.enqueueHarvestFailedUploadMetric(endpoint)
            completion(data, http, error)
            return
        }

        // ── Schedule next attempt with exponential backoff ────────────────────
        let retryAfter = retryAfterSeconds(from: http) ?? 0
        let delay = retryPolicy.delay(forAttempt: attempt, statusCode: status,
                                       retryAfterSeconds: retryAfter, isBackground: isBackground)
        let next = attempt + 1

        NRLOG_AGENT_DEBUG("HTTP Client: retrying \(endpoint) (attempt \(next)/\(maxRetries)) after \(delay)s. status=\(status)")

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.scheduleAttempt(request: request, body: body, endpoint: endpoint,
                                  attempt: next, offlinePollCount: 0,
                                  completion: completion)
        }
    }

    // MARK: - Metric helpers

    private func emitOutcomeMetrics(endpoint: String, attempt: Int, status: Int, error: NSError?) {
        let success = error == nil && status >= 200 && status < 300
        if attempt > 0 && success {
            NRMASupportMetricHelper.enqueueHarvestRetrySuccessMetric(endpoint)
        }
        if !success {
            NRMASupportMetricHelper.enqueueHarvestFailedUploadMetric(endpoint)
        }
    }

    // MARK: - Retry-After header parsing

    private func retryAfterSeconds(from response: HTTPURLResponse?) -> TimeInterval? {
        guard let headers = response?.allHeaderFields else { return nil }
        for (key, value) in headers {
            guard let keyStr = key as? String,
                  keyStr.caseInsensitiveCompare("Retry-After") == .orderedSame,
                  let valueStr = value as? String else { continue }
            let trimmed = valueStr.trimmingCharacters(in: .whitespaces)
            if let secs = TimeInterval(trimmed), secs > 0 { return secs }
            // HTTP-date format
            let fmt = DateFormatter()
            fmt.locale   = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(abbreviation: "GMT")
            fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
            if let date = fmt.date(from: trimmed) {
                let delta = date.timeIntervalSinceNow
                return delta > 0 ? delta : nil
            }
        }
        return nil
    }

    // MARK: - Application state

    private func isAppInBackground() -> Bool {
        guard let agent = NewRelicAgentInternal.sharedInstance() else { return false }
        #if os(watchOS)
        return agent.currentApplicationState == .background
        #else
        return agent.currentApplicationState == .background
        #endif
    }
}
