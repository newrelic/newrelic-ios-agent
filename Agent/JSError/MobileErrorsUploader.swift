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

    private let baseURL: URL
    private let applicationToken: String
    private let appVersion: String

    // NRMARetryingHTTPClient owns the URLSession and handles all retry/backoff.
    var httpClient: NRMARetryingHTTPClient

    // Callbacks for upload completion
    var onUploadSuccess: (() -> Void)?
    var onUploadFailed:  (() -> Void)?

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

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 60.0
        config.timeoutIntervalForResource = 120.0
        self.httpClient = NRMARetryingHTTPClient(
            session: URLSession(configuration: config),
            retryPolicy: NRMARetryPolicy()
        )

        super.init()
        NRLOG_AGENT_DEBUG("Mobile Errors Uploader initialized with URL: \(url)")
    }

    func invalidate() {
        httpClient.invalidate()
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

        if jsonData.count > NRMARetryingHTTPClient.maxPayloadSizeBytes {
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
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("\(jsonData.count)",   forHTTPHeaderField: "Content-Length")
        request.setValue(applicationToken,      forHTTPHeaderField: "X-App-License-Key")
        addNewRelicHeaders(to: &request,
                           sessionId: sessionId,
                           entityGuid: entityGuid,
                           accountId: accountId,
                           trustedAccountId: trustedAccountId,
                           sessionToken: sessionToken,
                           agentConfigToken: agentConfigToken)

        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Sending payload to \(url)")
        NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Payload size: \(jsonData.count) bytes")

        let uploadStart = Date()

        httpClient.upload(request: request, data: jsonData, endpoint: "errors") { [weak self] _, response, error in
            guard let self = self else { return }
            let statusCode = response?.statusCode ?? 0
            let success = error == nil && statusCode >= 200 && statusCode < 300

            if success {
                let elapsedMs = Date().timeIntervalSince(uploadStart) * 1000
                NRMASupportMetricHelper.enqueueJSErrorUploadTimeMetric(elapsedMs)
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload completed successfully")
                self.onUploadSuccess?()
            } else if statusCode == 408 {
                NRMASupportMetricHelper.enqueueJSErrorUploadTimeoutMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request timeout (\(statusCode))")
                self.onUploadFailed?()
            } else if statusCode == 429 {
                NRMASupportMetricHelper.enqueueJSErrorUploadThrottledMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Request was throttled after retries")
                self.onUploadFailed?()
            } else {
                NRMASupportMetricHelper.enqueueJSErrorFailedUploadMetric()
                NRLOG_AGENT_DEBUG("Mobile Errors Uploader: Upload failed. status=\(statusCode) error=\(String(describing: error))")
                self.onUploadFailed?()
            }
        }
    }

    // retryFailedUploads is kept for API compatibility; retry is now handled by NRMARetryingHTTPClient.
    func retryFailedUploads() { }

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
