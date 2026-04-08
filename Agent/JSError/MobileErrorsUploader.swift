//
//  MobileErrorsUploader.swift
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

class MobileErrorsUploader: NSObject {

    private static let retryLimit = 2
    private static let maxPayloadSizeLimitBytes = 1048576 // 1 MB

    private let baseURL: URL
    private let applicationToken: String
    private let appVersion: String
    private let useSSL: Bool
    private var session: URLSession

    private let retryQueue = NSMutableArray()
    private let retryQueueLock = NSLock()
    private let retryTracker = NSMutableDictionary()
    private let retryTrackerLock = NSLock()

    // Timer tracking for supportability metrics
    private let uploadTimers = NSMutableDictionary()
    private let uploadTimersLock = NSLock()

    // MARK: - Initialization

    init?(host: String, applicationToken: String, appVersion: String, useSSL: Bool) {
        guard !host.isEmpty else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: host is required")
            return nil
        }

        guard !applicationToken.isEmpty else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: applicationToken is required")
            return nil
        }

        guard !appVersion.isEmpty else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: appVersion is required")
            return nil
        }

        // Construct base URL
        let scheme = useSSL ? "https" : "http"
        let urlString = "\(scheme)://\(host)/mobile/errors"

        guard let url = URL(string: urlString) else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: invalid URL")
            return nil
        }

        self.baseURL = url
        self.applicationToken = applicationToken
        self.appVersion = appVersion
        self.useSSL = useSSL

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        self.session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)

        super.init()

        // Set delegate after initialization
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        NRLOG_AGENT_DEBUG("Mobile Errors Uploader initialized with URL: \(self.baseURL)")
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    // MARK: - Public Methods

    func sendPayload(_ payload: [String: Any],
                     sessionId: String?,
                     entityGuid: String?,
                     accountId: NSNumber?,
                     trustedAccountId: NSNumber?,
                     sessionToken: String?,
                     agentConfigToken: String?) {
        // Serialize to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Failed to serialize payload to JSON")
            return
        }

        // Check payload size
        if jsonData.count > Self.maxPayloadSizeLimitBytes {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Payload exceeds 1 MB limit (\(jsonData.count) bytes), discarding")
            return
        }

        // Create URL with query parameters
        guard var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Failed to create URL components")
            return
        }

        // Add required query parameters
        urlComponents.queryItems = [
            URLQueryItem(name: "protocol_version", value: "1"),
            URLQueryItem(name: "platform", value: "reactnative")
        ]

        guard let url = urlComponents.url else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Failed to construct URL with query params")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData

        // Add headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
        request.setValue(applicationToken, forHTTPHeaderField: "X-App-License-Key")

        // Add New Relic headers
        addNewRelicHeaders(to: &request,
                          sessionId: sessionId,
                          entityGuid: entityGuid,
                          accountId: accountId,
                          trustedAccountId: trustedAccountId,
                          sessionToken: sessionToken,
                          agentConfigToken: agentConfigToken)

        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Sending payload to \(url)")
        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Payload size: \(jsonData.count) bytes")

        // Log all headers for debugging
        print("========== Mobile Errors Request Headers ==========")
        print("URL: \(url)")
        print("Payload size: \(jsonData.count) bytes")
        request.allHTTPHeaderFields?.forEach { key, value in
            print("  \(key): \(value)")
        }
        print("===================================================")

        // Track for retry
        trackRequest(request)

        // Start timing for supportability metrics
        startUploadTimer(for: request)

        // Create and start upload task
        let task = session.dataTask(with: request)
        task.resume()
    }

    func retryFailedUploads() {
        retryQueueLock.lock()
        let requestsToRetry = retryQueue as! [URLRequest]
        retryQueue.removeAllObjects()
        retryQueueLock.unlock()

        guard !requestsToRetry.isEmpty else {
            return
        }

        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Retrying \(requestsToRetry.count) failed uploads")

        for request in requestsToRetry {
            // Start timing for retry
            startUploadTimer(for: request)

            let task = session.dataTask(with: request)
            task.resume()
        }
    }

    func invalidate() {
        session.finishTasksAndInvalidate()
    }

    // MARK: - Private Methods

    private func addNewRelicHeaders(to request: inout URLRequest,
                                    sessionId: String?,
                                    entityGuid: String?,
                                    accountId: NSNumber?,
                                    trustedAccountId: NSNumber?,
                                    sessionToken: String?,
                                    agentConfigToken: String?) {
        // Standard New Relic Mobile headers (from Mobile Errors Protocol)
        request.setValue(NewRelicInternalUtils.agentVersion(), forHTTPHeaderField: "X-NewRelic-Agent-Version")
        request.setValue(appVersion, forHTTPHeaderField: "X-NewRelic-App-Version")
        request.setValue(NewRelicInternalUtils.osName(), forHTTPHeaderField: "X-NewRelic-Os-Name")

        // Session token (from connect response request_headers_map)
        if let sessionToken = sessionToken, !sessionToken.isEmpty {
            request.setValue(sessionToken, forHTTPHeaderField: "X-NewRelic-Session")
        } else if let sessionId = sessionId, !sessionId.isEmpty {
            // Fallback to session ID if token not available
            request.setValue(sessionId, forHTTPHeaderField: "X-NewRelic-Session")
        }

        // Agent configuration token (from connect response request_headers_map)
        if let agentConfigToken = agentConfigToken, !agentConfigToken.isEmpty {
            request.setValue(agentConfigToken, forHTTPHeaderField: "X-NewRelic-AgentConfiguration")
        }

        // Entity GUID
        if let entityGuid = entityGuid, !entityGuid.isEmpty {
            request.setValue(entityGuid, forHTTPHeaderField: "X-NewRelic-Entity-Guid")
        }

        // Account IDs (required by protocol)
        if let accountId = accountId {
            request.setValue(accountId.stringValue, forHTTPHeaderField: "X-NewRelic-Account-Id")
        }
        if let trustedAccountId = trustedAccountId {
            request.setValue(trustedAccountId.stringValue, forHTTPHeaderField: "X-NewRelic-Trusted-Account-Id")
        }
    }

    private func trackRequest(_ request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        retryTrackerLock.lock()
        retryTracker[url] = NSNumber(value: 0)
        retryTrackerLock.unlock()
    }

    private func shouldRetryRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }

        retryTrackerLock.lock()
        let retryCount = retryTracker[url] as? NSNumber
        retryTrackerLock.unlock()

        return retryCount != nil && retryCount!.intValue < Self.retryLimit
    }

    private func incrementRetryCount(for request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        retryTrackerLock.lock()
        let currentCount = (retryTracker[url] as? NSNumber)?.intValue ?? 0
        retryTracker[url] = NSNumber(value: currentCount + 1)
        retryTrackerLock.unlock()
    }

    private func removeFromRetryTracker(_ request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        retryTrackerLock.lock()
        retryTracker.removeObject(forKey: url)
        retryTrackerLock.unlock()
    }

    private func handleSuccessfulRequest(_ request: URLRequest) {
        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload completed successfully")
        removeFromRetryTracker(request)
    }

    private func handleFailedRequest(_ request: URLRequest, error: Error?) {
        if let error = error {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload failed - \(error.localizedDescription)")
        } else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload failed with unknown error")
        }

        // Check if we should retry
        if shouldRetryRequest(request) {
            incrementRetryCount(for: request)

            retryQueueLock.lock()
            retryQueue.add(request)
            retryQueueLock.unlock()

            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Added request to retry queue")
        } else {
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Max retries reached, discarding request")
            removeFromRetryTracker(request)
        }
    }

    private func handleResponse(_ response: URLResponse, request: URLRequest) {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        let statusCode = httpResponse.statusCode

        print("========== Mobile Errors Response Status ==========")
        print("Status code: \(statusCode)")
        print("===================================================")

        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Received response with status code: \(statusCode)")

        // Record supportability metrics based on status code
        if statusCode >= 200 && statusCode < 300 {
            // Success - record upload time
            recordUploadTime(for: request)
            handleSuccessfulRequest(request)
        } else if statusCode == 408 {
            // Timeout
            NRMASupportMetricHelper.enqueueJSErrorUploadTimeoutMetric()
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request timeout (\(statusCode))")
            removeFromRetryTracker(request)
        } else if statusCode == 429 {
            // Throttled
            NRMASupportMetricHelper.enqueueJSErrorUploadThrottledMetric()
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request throttled (\(statusCode)), will retry")
            handleFailedRequest(request, error: nil)
        } else if statusCode >= 400 && statusCode < 500 {
            // Client error - don't retry
            NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Client error (\(statusCode)), not retrying")
            removeFromRetryTracker(request)
        } else if statusCode >= 500 && statusCode < 600 {
            // Server error - retry
            NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Server error (\(statusCode)), will retry")
            handleFailedRequest(request, error: nil)
        } else {
            NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Unexpected status code: \(statusCode)")
            handleFailedRequest(request, error: nil)
        }
    }

    // MARK: - Supportability Metrics

    private func startUploadTimer(for request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        uploadTimersLock.lock()
        uploadTimers[url] = Date()
        uploadTimersLock.unlock()
    }

    private func recordUploadTime(for request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }

        uploadTimersLock.lock()
        let startTime = uploadTimers[url] as? Date
        uploadTimers.removeObject(forKey: url)
        uploadTimersLock.unlock()

        if let startTime = startTime {
            let elapsedTime = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
            NRMASupportMetricHelper.enqueueJSErrorUploadTimeMetric(elapsedTime)
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Recorded upload time: \(elapsedTime)ms")
        }
    }
}

// MARK: - URLSessionDelegate

extension MobileErrorsUploader: URLSessionDelegate, URLSessionDataDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = task.originalRequest else {
            return
        }

        if let error = error {
            // Network or other error occurred
            let nsError = error as NSError

            // Check if it was cancelled
            if nsError.code == NSURLErrorCancelled {
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload was cancelled")
                removeFromRetryTracker(request)
                return
            }

            handleFailedRequest(request, error: error)
        } else if let response = task.response {
            // Request completed, check status code
            handleResponse(response, request: request)
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Allow the task to proceed
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Log response data
        if let responseString = String(data: data, encoding: .utf8) {
            print("========== Mobile Errors Response ==========")
            print("Response body: \(responseString)")
            print("============================================")
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Response data: \(responseString)")
        }
    }
}
