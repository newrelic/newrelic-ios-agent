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

    private static let retryLimit = 5
    private static let maxPayloadSizeLimitBytes = 1048576 // 1 MB

    private let baseURL: URL
    private let applicationToken: String
    private let appVersion: String
    private let useSSL: Bool
    private var session: URLSession
    private let orchestrator = NRMARetryOrchestrator(initialDelay: 1.0, maxDelay: 16.0)

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

        // Configure URL session (completion-handler based; no delegate needed)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        self.session = URLSession(configuration: config)

        super.init()

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

        let startTime = Date()
        let localSession = self.session

        let executeRequest: NRMAExecuteRequestBlock = { onResponse in
            let task = localSession.dataTask(with: request) { data, response, error in
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("========== Mobile Errors Response ==========")
                    print("Response body: \(responseString)")
                    print("============================================")
                    NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Response data: \(responseString)")
                }
                onResponse(response as? HTTPURLResponse, data, error)
            }
            task.resume()
        }

        let shouldRetry: (HTTPURLResponse?, Error?) -> Bool = { response, error in
            if let nsError = error as NSError? {
                return nsError.code != NSURLErrorCancelled
            }
            guard let statusCode = response?.statusCode else { return false }
            return statusCode == 429 || (statusCode >= 500 && statusCode < 600)
        }

        let waitForDelay = NRMARetryOrchestrator.asyncWaitForDelay(on: .global())

        orchestrator.execute(withMaxRetries: Self.retryLimit,
                             executeRequest: executeRequest,
                             shouldRetry: shouldRetry,
                             waitForDelay: waitForDelay) { response, _, error, _ in
            if let nsError = error as NSError?, nsError.code == NSURLErrorCancelled {
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload was cancelled")
                return
            }

            if let error = error {
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload failed - \(error.localizedDescription)")
                NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
                return
            }

            guard let httpResponse = response else { return }
            let statusCode = httpResponse.statusCode

            print("========== Mobile Errors Response Status ==========")
            print("Status code: \(statusCode)")
            print("===================================================")
            NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Received response with status code: \(statusCode)")

            if statusCode >= 200 && statusCode < 300 {
                let elapsed = Date().timeIntervalSince(startTime) * 1000
                NRMASupportMetricHelper.enqueueJSErrorUploadTimeMetric(elapsed)
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload completed successfully")
            } else if statusCode == 408 {
                NRMASupportMetricHelper.enqueueJSErrorUploadTimeoutMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request timeout (\(statusCode))")
            } else if statusCode == 429 {
                NRMASupportMetricHelper.enqueueJSErrorUploadThrottledMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request throttled (\(statusCode)), max retries reached")
            } else if statusCode >= 400 && statusCode < 500 {
                NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Client error (\(statusCode)), not retrying")
            } else {
                NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Unexpected status code: \(statusCode)")
            }
        }
    }

    func retryFailedUploads() {
        // Retries are now handled immediately by NRMARetryOrchestrator inside sendPayload.
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
}
