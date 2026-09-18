//
//  NRMARetryingHTTPClient.swift
//  NewRelicAgent
//
//  Copyright © 2024 New Relic. All rights reserved.
//

import Foundation
import Network
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

    /// Designated initialiser.
    @objc public init(sessionConfiguration: URLSessionConfiguration, retryPolicy: NRMARetryPolicy) {
        self.retryPolicy = retryPolicy
        super.init()
        // Deliver completion handlers at userInitiated QoS to match the harvest thread.
        // delegateQueue:nil would create an internal utility-QoS queue, causing a
        // priority inversion when the harvest thread blocks on the semaphore in
        // NRMAHarvesterConnection.send: waiting for a lower-priority signal.
        let delegateQueue = OperationQueue()
        delegateQueue.qualityOfService = .userInitiated
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.name = "com.newrelic.retrying-http-client.delegate"
        self.session = URLSession(configuration: sessionConfiguration, delegate: nil, delegateQueue: delegateQueue)
        startPathMonitor()
    }

    /// Convenience init with sensible defaults (default session config, fresh policy).
    @objc public convenience override init() {
        self.init(sessionConfiguration: .default, retryPolicy: NRMARetryPolicy())
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
                        attempt: 0, completion: completion)
    }

    /// Uploads the file at `fileURL` to `request`, retrying on transient failures.
    /// `completion` is called exactly once with the terminal outcome.
    @objc(uploadRequest:fileURL:endpoint:completion:)
    public func upload(request: URLRequest,
                       fileURL: URL,
                       endpoint: String,
                       completion: @escaping NRMAUploadCompletion) {
        scheduleAttempt(request: request, body: .file(fileURL), endpoint: endpoint,
                        attempt: 0, completion: completion)
    }

    /// Collapses any pending retry delay and fires the retry immediately.
    /// Called on app background or when `NWPathMonitor` reports network restoration.
    @objc public func backgroundFlush() {
        retryLock.lock()
        retryGeneration += 1
        let work = pendingWork
        pendingWork = nil
        retryLock.unlock()
        if let work = work {
            queue.async { work() }
        }
    }

    /// Cancels all in-flight tasks and invalidates the underlying `URLSession`.
    /// The client must not be used after this call.
    @objc public func invalidate() {
        pathMonitor.cancel()
        session.invalidateAndCancel()
    }

    // MARK: - Private state

    private var session: URLSession!
    private let queue = DispatchQueue(label: "com.newrelic.retrying-http-client", qos: .utility)
    private let pathMonitor = NWPathMonitor()

    // Generation counter for cancellable retry delays.
    // Incrementing the generation in backgroundFlush() orphans the pending asyncAfter,
    // and the immediately-dispatched work block runs instead.
    private let retryLock = NSLock()
    private var retryGeneration = 0
    private var pendingWork: (() -> Void)?

    // MARK: - Upload body

    private enum Body {
        case data(Data)
        case file(URL)
    }

    // MARK: - Path monitor

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.backgroundFlush()
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "com.newrelic.path-monitor", qos: .utility))
    }

    // MARK: - Core retry loop

    private func scheduleAttempt(request: URLRequest,
                                  body: Body,
                                  endpoint: String,
                                  attempt: Int,
                                  completion: @escaping NRMAUploadCompletion) {
        // Pre-flight connectivity check — only when offline storage is enabled.
        // Failing fast lets NRMAOfflineStorage write the payload to disk via the
        // normal error-response path. Without the flag there is nothing to persist,
        // so we let the request proceed and fail naturally.
        if NRMAFlags.shouldEnableOfflineStorage() && pathMonitor.currentPath.status != .satisfied {
            NRMASupportMetricHelper.enqueueHarvestRetryNetworkSuspendedMetric(endpoint)
            NRLOG_AGENT_DEBUG("HTTP Client: offline, failing immediately — \(endpoint)")
            completion(nil, nil, NSError(domain: NSURLErrorDomain,
                                         code: NSURLErrorNotConnectedToInternet,
                                         userInfo: nil))
            return
        }

        let handler: (Data?, URLResponse?, Error?) -> Void = { [weak self] data, response, error in
            guard let self = self else {
                let cancelError = (error as NSError?) ?? NSError(domain: NSURLErrorDomain,
                                                                  code: NSURLErrorCancelled,
                                                                  userInfo: nil)
                completion(data, response as? HTTPURLResponse, cancelError)
                return
            }
            self.handleResult(data: data, response: response, error: error,
                              request: request, body: body, endpoint: endpoint,
                              attempt: attempt, completion: completion)
        }
        let task: URLSessionUploadTask
        switch body {
        case .data(let d):   task = session.uploadTask(with: request, from: d, completionHandler: handler)
        case .file(let url): task = session.uploadTask(with: request, fromFile: url, completionHandler: handler)
        }
        task.taskDescription = endpoint
        task.resume()
    }

    private func handleResult(data: Data?,
                               response: URLResponse?,
                               error: Error?,
                               request: URLRequest,
                               body: Body,
                               endpoint: String,
                               attempt: Int,
                               completion: @escaping NRMAUploadCompletion) {
        let http   = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let nsErr  = error as NSError?

        let isBackground = isAppInBackground()
        let maxRetries   = retryPolicy.maxRetries(isBackground: isBackground)
        let reason       = retryPolicy.retryReason(forError: nsErr, statusCode: status)

        // ── Terminal: success or a non-retryable error ────────────────────────
        if reason == .none {
            emitOutcomeMetrics(endpoint: endpoint, attempt: attempt, status: status, error: nsErr)
            completion(data, http, error)
            return
        }

        // ── Retries exhausted ─────────────────────────────────────────────────
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

        NRLOG_AGENT_DEBUG("HTTP Client: retrying \(endpoint) (attempt \(next)/\(maxRetries)) after \(delay)s. reason=\(reason.rawValue) status=\(status)")

        scheduleRetry(delay: delay) { [weak self] in
            self?.scheduleAttempt(request: request, body: body, endpoint: endpoint,
                                  attempt: next, completion: completion)
        }
    }

    // Schedules `work` after `delay`, but allows `backgroundFlush()` to collapse
    // the delay by incrementing the generation counter before `delay` expires.
    private func scheduleRetry(delay: TimeInterval, work: @escaping () -> Void) {
        retryLock.lock()
        retryGeneration += 1
        let gen = retryGeneration
        pendingWork = work
        retryLock.unlock()

        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            self.retryLock.lock()
            let current = self.retryGeneration
            let w = self.pendingWork
            if current == gen { self.pendingWork = nil }
            self.retryLock.unlock()
            guard current == gen, let w = w else { return }
            w()
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
        return agent.currentApplicationState == .background
    }
}

