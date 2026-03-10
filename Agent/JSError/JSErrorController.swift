//
//  JSErrorController.swift
//  NewRelicAgent
//
//  Created by New Relic Mobile Agent Team
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

let kJSErrorBackupStoreFolder = "nr_js_error_store"

@objc @objcMembers
public class JSErrorController: NSObject {

    // MARK: - Properties

    var sessionId: String?
    var sessionStartDate: Date?

    private let platform: String
    private let agentConfiguration: AnyObject
    private let attributeValidator: AnyObject

    private var uploader: MobileErrorsUploader?
    private var errorQueue = NSMutableArray()
    private let errorQueueLock = NSLock()

    // MARK: - Initialization

    @objc public init?(analyticsController: AnyObject,
                      sessionStartTime: Date,
                      agentConfiguration: AnyObject,
                      platform: String,
                      sessionId: String,
                      attributeValidator: AnyObject) {

        // Cast to internal types
        guard let config = agentConfiguration as? NRMAAgentConfiguration,
              let validator = attributeValidator as? AttributeValidatorProtocol else {
            NRLOG_AGENT_DEBUG("Failed to create JS error controller. Invalid parameters.")
            return nil
        }

        // Validate required parameters
        guard let appToken = config.applicationToken else {
            NRLOG_AGENT_DEBUG("Failed to create JS error controller. appToken is nil.")
            return nil
        }

        guard !platform.isEmpty && !sessionId.isEmpty else {
            NRLOG_AGENT_DEBUG("Failed to create JS error controller. platform or sessionId is empty.")
            return nil
        }

        self.sessionId = sessionId
        self.sessionStartDate = sessionStartTime
        self.platform = platform
        self.agentConfiguration = config
        self.attributeValidator = validator

        super.init()

        // Initialize uploader
        let collectorHost = config.collectorHost ?? "mobile-collector.newrelic.com"
        let tokenString = appToken.value ?? "unknown"
        let appVersion = NRMAAgentConfiguration.connectionInformation()?.applicationInformation.appVersion ?? "unknown"

        self.uploader = MobileErrorsUploader(host: collectorHost,
                                            applicationToken: tokenString,
                                            appVersion: appVersion,
                                            useSSL: config.useSSL)

        if self.uploader == nil {
            NRLOG_AGENT_DEBUG("Failed to initialize Mobile Errors uploader")
            return nil
        }

        NRLOG_AGENT_DEBUG("JS Error Controller initialized with collector: \(collectorHost)")
    }

    // MARK: - Public Methods

    @objc public func recordJSError(_ name: String,
                      message: String,
                      stackTrace: String,
                      isFatal: Bool,
                      jsAppVersion: String?,
                      additionalAttributes: [String: Any]?) {

        // Validate required parameters
        guard !name.isEmpty else {
            NRLOG_AGENT_DEBUG("Cannot record JS error: name is required")
            return
        }

        guard !message.isEmpty else {
            NRLOG_AGENT_DEBUG("Cannot record JS error: message is required")
            return
        }

        // Create error dictionary
        var errorData: [String: Any] = [
            "name": name,
            "message": message,
            "stackTrace": stackTrace,
            "isFatal": isFatal,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "errorId": UUID().uuidString
        ]

        // Add optional fields
        if let jsAppVersion = jsAppVersion, !jsAppVersion.isEmpty {
            errorData["jsAppVersion"] = jsAppVersion
        }

        // Add additional attributes if provided
        if let additionalAttributes = additionalAttributes, !additionalAttributes.isEmpty {
            var validatedAttributes: [String: Any] = [:]

            for (key, value) in additionalAttributes {
                // Validate attribute using validator
                if let validator = attributeValidator as? AttributeValidatorProtocol,
                   validator.nameValidator(key) && validator.valueValidator(value) {
                    validatedAttributes[key] = value
                } else {
                    NRLOG_AGENT_DEBUG("Skipping invalid JS error attribute: \(key)")
                }
            }

            if !validatedAttributes.isEmpty {
                errorData["attributes"] = validatedAttributes
            }
        }

        NRLOG_AGENT_DEBUG("Recording JS error: \(name)")

        // Add to queue
        errorQueueLock.lock()
        errorQueue.add(errorData)
        errorQueueLock.unlock()

        // Persist to disk
        persistError(errorData)
    }

    @objc public func processAndPublishPersistedErrors() {
        let persistedErrors = loadPersistedErrors()

        if !persistedErrors.isEmpty {
            NRLOG_AGENT_DEBUG("Processing \(persistedErrors.count) persisted JS errors")

            errorQueueLock.lock()
            for error in persistedErrors {
                errorQueue.add(error)
            }
            errorQueueLock.unlock()

            // Don't clear persisted errors yet - wait until after successful send
            // They will be cleared in onHarvestComplete
        }
    }

    // MARK: - Harvest Methods (called manually, not via protocol)

    @objc public func onHarvestStart() {
        // No action needed
    }

    @objc public func onHarvestBefore() {
        // No action needed
    }

    @objc public func onHarvest() {
        errorQueueLock.lock()
        let errors = errorQueue as! [[String: Any]]
        errorQueue.removeAllObjects()
        errorQueueLock.unlock()

        if !errors.isEmpty {
            NRLOG_AGENT_DEBUG("Harvesting \(errors.count) JS errors")
            publishErrors(errors)
        }
    }

    @objc public func onHarvestComplete() {
        // Clear persisted errors after successful harvest
        clearPersistedErrors()
    }

    @objc public func onHarvestError() {
        // Retry failed uploads
        uploader?.retryFailedUploads()
    }

    @objc public func onHarvestStop() {
        // No action needed
    }

    @objc public func onHarvestConnected() {
        // Process persisted errors when connection is established
        processAndPublishPersistedErrors()
    }

    @objc public func onHarvestDisconnected() {
        // No action needed
    }

    // MARK: - Private Methods

    private func publishErrors(_ errors: [[String: Any]]) {
        guard let uploader = uploader else {
            NRLOG_AGENT_DEBUG("Cannot publish JS errors: uploader is nil")
            return
        }

        // Get harvest configuration for tokens
        guard let configuration = NRMAHarvestController.configuration() else {
            NRLOG_AGENT_DEBUG("Cannot publish JS errors: harvest configuration is nil")
            return
        }

        // Extract tokens from request_headers_map
        var sessionToken: String?
        var agentConfigToken: String?

        if let requestHeaderMap = configuration.request_header_map as? [String: Any] {
            sessionToken = requestHeaderMap["NR-Session"] as? String
            agentConfigToken = requestHeaderMap["NR-AgentConfiguration"] as? String
        }

        // Format payload
        let payload = formatPayload(errors)

        // DEBUG: Print full payload for Android team
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NRLOG_AGENT_DEBUG("=== JS ERROR PAYLOAD ===\n\(jsonString)\n======================")
        }

        // Get connection info
        let connectInfo = NRMAAgentConfiguration.connectionInformation()

        // Send to uploader
        uploader.sendPayload(payload,
                           sessionId: sessionId,
                           entityGuid: configuration.entity_guid,
                           accountId: NSNumber(value: configuration.account_id),
                           trustedAccountId: nil, // trusted_account_key is a string, not needed for this endpoint
                           sessionToken: sessionToken,
                           agentConfigToken: agentConfigToken)
    }

    private func formatPayload(_ errors: [[String: Any]]) -> [String: Any] {
        // Get connection info for device data
        let connectInfo = NRMAAgentConfiguration.connectionInformation()

        // Build payload per Mobile Errors Protocol
        var payload: [String: Any] = [:]

        payload["timestamp"] = Int64(Date().timeIntervalSince1970 * 1000)
        payload["agentName"] = NewRelicInternalUtils.agentName()

        // Use platformVersion first, fallback to agentVersion
        if let deviceInfo = connectInfo?.deviceInformation {
            let version = deviceInfo.platformVersion ?? deviceInfo.agentVersion as String? as NSString?
            payload["agentVersion"] = version ?? NewRelicInternalUtils.agentVersion()
        } else {
            payload["agentVersion"] = NewRelicInternalUtils.agentVersion()
        }

        if let configuration = NRMAHarvestController.configuration(),
           configuration.application_id > 0 {
            payload["dataToken"] = [configuration.application_id, 0]
        }

        payload["appInfo"] = [
            "appName": connectInfo?.applicationInformation.appName ?? "unknown",
            "appVersion": connectInfo?.applicationInformation.appVersion ?? "unknown",
            "appBuild": connectInfo?.applicationInformation.appBuild ?? "unknown",
            "bundleId": Bundle.main.bundleIdentifier ?? "unknown"
        ]

        payload["deviceInfo"] = getDeviceInfo()

        // Session attributes - simplified to just sessionId
        payload["sessionAttributes"] = [
            "sessionId": sessionId ?? ""
        ]

        // Format events
        let events = errors.map { formatErrorAsEvent($0) }
        payload["analyticsEvents"] = events

        return payload
    }

    private func formatErrorAsEvent(_ errorData: [String: Any]) -> [String: Any] {
        var event: [String: Any] = [:]

        event["eventType"] = "MobileJSError"

        // Required fields from error data
        if let errorId = errorData["errorId"] as? String {
            event["errorId"] = errorId
        }

        if let message = errorData["message"] as? String {
            event["description"] = message
        }

        if let name = errorData["name"] as? String {
            event["errorType"] = name
        }

        if let isFatal = errorData["isFatal"] as? Bool {
            event["isFatalError"] = isFatal ? "true" : "false"
        }

        if let timestamp = errorData["timestamp"] as? Int64 {
            event["timestamp"] = timestamp
        }

        // URL encode stack trace
        if let stackTrace = errorData["stackTrace"] as? String, !stackTrace.isEmpty {
            event["threads"] = urlEncodeStackTrace(stackTrace)
        }

        // Add jsAppVersion
        if let jsAppVersion = errorData["jsAppVersion"] as? String {
            event["jsAppVersion"] = jsAppVersion
        }

        // Add additional attributes if present
        if let attributes = errorData["attributes"] as? [String: Any] {
            for (key, value) in attributes {
                event[key] = value
            }
        }

        // Add session attributes (same as log endpoint)
        if let sessionAttributesJSON = analyticsController?.sessionAttributeJSONString(),
           !sessionAttributesJSON.isEmpty,
           let sessionData = sessionAttributesJSON.data(using: .utf8),
           let sessionAttributes = try? JSONSerialization.jsonObject(with: sessionData) as? [String: Any] {
            for (key, value) in sessionAttributes {
                // Don't override existing attributes
                if event[key] == nil {
                    event[key] = value
                }
            }
        }

        return event
    }

    private func urlEncodeStackTrace(_ stackTrace: String) -> String {
        return stackTrace.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stackTrace
    }

    private func getDeviceInfo() -> [String: Any] {
        let connectInfo = NRMAAgentConfiguration.connectionInformation()
        guard let deviceInfo = connectInfo?.deviceInformation else {
            return [:]
        }

        var info: [String: Any] = [:]

        // Use properties that actually exist on NRMADeviceInformation
        info["osVersion"] = deviceInfo.osVersion as String? ?? "unknown"
        info["osName"] = deviceInfo.osName as String? ?? "unknown"
        info["model"] = deviceInfo.model as String? ?? "unknown"
        info["deviceId"] = deviceInfo.deviceId as String? ?? "unknown"
        info["agentName"] = deviceInfo.agentName as String? ?? "unknown"
        info["agentVersion"] = deviceInfo.agentVersion as String? ?? "unknown"
        info["manufacturer"] = deviceInfo.manufacturer as String? ?? "Apple"

        // Add misc if available
        if let misc = deviceInfo.misc {
            for (key, value) in misc {
                if let key = key as? String {
                    info[key] = value
                }
            }
        }

        return info
    }

    // MARK: - Persistence

    private func persistError(_ errorData: [String: Any]) {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            NRLOG_AGENT_DEBUG("Cannot persist JS error: unable to get documents directory")
            return
        }

        let storePath = (documentsPath as NSString).appendingPathComponent(kJSErrorBackupStoreFolder)

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(atPath: storePath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NRLOG_AGENT_DEBUG("Failed to create JS error storage directory: \(error)")
            return
        }

        // Generate unique filename
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let fileName = "js_error_\(timestamp).json"
        let filePath = (storePath as NSString).appendingPathComponent(fileName)

        // Serialize to JSON and write
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: errorData, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
            NRLOG_AGENT_DEBUG("Persisted JS error to: \(fileName)")
        } catch {
            NRLOG_AGENT_DEBUG("Failed to persist JS error: \(error)")
        }
    }

    private func loadPersistedErrors() -> [[String: Any]] {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return []
        }

        let storePath = (documentsPath as NSString).appendingPathComponent(kJSErrorBackupStoreFolder)

        guard FileManager.default.fileExists(atPath: storePath) else {
            return []
        }

        var errors: [[String: Any]] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: storePath)

            for file in files where file.hasSuffix(".json") {
                let filePath = (storePath as NSString).appendingPathComponent(file)

                if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                   let errorData = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    errors.append(errorData)
                }
            }
        } catch {
            NRLOG_AGENT_DEBUG("Failed to load persisted JS errors: \(error)")
        }

        return errors
    }

    private func clearPersistedErrors() {
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            return
        }

        let storePath = (documentsPath as NSString).appendingPathComponent(kJSErrorBackupStoreFolder)

        do {
            try FileManager.default.removeItem(atPath: storePath)
            NRLOG_AGENT_DEBUG("Cleared persisted JS errors")
        } catch {
            NRLOG_AGENT_DEBUG("Failed to clear persisted JS errors: \(error)")
        }
    }

    // MARK: - Testing Support

    /// Internal method for testing: retrieves a copy of the current error queue
    /// - Returns: Array of error dictionaries currently in the queue
    @objc public func getErrorQueueForTesting() -> [[String: Any]] {
        errorQueueLock.lock()
        defer { errorQueueLock.unlock() }

        var errors: [[String: Any]] = []
        for case let error as [String: Any] in errorQueue {
            errors.append(error)
        }
        return errors
    }

    /// Internal method for testing: clears the error queue
    @objc public func clearErrorQueueForTesting() {
        errorQueueLock.lock()
        defer { errorQueueLock.unlock() }
        errorQueue.removeAllObjects()
    }
}
