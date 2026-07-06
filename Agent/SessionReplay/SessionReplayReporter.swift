//
//  SessionReplayReporter.swift
//  Agent
//
//  Created by Mike Bruin on 3/12/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import Compression
import zlib
@_implementationOnly import NewRelicPrivate

@objcMembers
public class SessionReplayReporter: NSObject {
    private var sessionReplayFramesUploadArray: [SessionReplayData] = []
    private var isUploading = false
    private var failureCount = 0
    private let uploadQueue = DispatchQueue(label: "com.newrelicagent.sessionreplayqueue")
    private let kNRMAMaxUploadRetry = 3
    private let applicationToken: String
    private let url: NSString
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var pendingUploads = 0
    private var pendingOfflineUploads = 0
    private var offlineUploadMetricSize: Int = 0
    private let offlineStorage: NRMAOfflineStorage

    // HTTP Header Constants
    private static let kContentTypeHeader = "Content-Type"
    private static let kContentEncodingHeader = "Content-Encoding"
    private static let kAcceptEncodingHeader = "Accept-Encoding"
    private static let kContentLengthHeader = "Content-Length"
    private static let kAppLicenseKeyHeader = "X-App-License-Key"
    private static let kOctetStreamContentType = "application/octet-stream"
    private static let kGzipEncoding = "gzip"
    private static let kPostMethod = "POST"

    @objc public init(applicationToken: String, url: NSString) {
        self.applicationToken = applicationToken
        self.url = url
        self.offlineStorage = NRMAOfflineStorage(endpoint: "sessionreplay")
        super.init()

        // Set max offline storage size if configured
        if let _ = NRMAAgentConfiguration.connectionInformation() {
            let maxSize = NRMAAgentConfiguration.getMaxOfflineStorageSize()
            self.offlineStorage.setMaxOfflineStorageSize(maxSize)
        }
    }

    func enqueueSessionReplayUpload(upload: SessionReplayData) {
        uploadQueue.async {
            self.sessionReplayFramesUploadArray.append(upload)
            self.pendingUploads += 1
            self.beginBackgroundTaskIfNeeded()
            self.processNextUploadTask()
        }
   }
    
    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskId == .invalid else { return }
        
        DispatchQueue.main.async {
            self.backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
                NRLOG_AGENT_DEBUG("Session replay background task expiring")
                self?.endBackgroundTaskIfNeeded()
            }
        }
    }
    
    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskId != .invalid else { return }
        
        DispatchQueue.main.async {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }
    }

    private func processNextUploadTask() {
         uploadQueue.async { [weak self] in
             guard let self = self, !self.isUploading, !self.sessionReplayFramesUploadArray.isEmpty else {
                 return
             }

             self.isUploading = true
             
             let upload = self.sessionReplayFramesUploadArray.first!
             let dataSizeInBytes = upload.sessionReplayFramesData.count
             let dataSizeInMB = Double(dataSizeInBytes) / (1024.0 * 1024.0)
             NRLOG_AGENT_DEBUG("Session replay frames compressed data: \(String(format: "%.2f", dataSizeInMB)) MB")

             if upload.sessionReplayFramesData.count > kNRMAMaxPayloadSizeLimit {
                 NRLOG_AGENT_DEBUG("Unable to send session replay frames because payload is larger than 1 MB. \(upload.sessionReplayFramesData.count) bytes.")
                 self.isUploading = false
                 NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("SessionReplay")
                 self.sessionReplayFramesUploadArray.removeFirst()
                 self.pendingUploads -= 1
                 
                 // Check if we should end the background task
                 if self.pendingUploads == 0 && self.sessionReplayFramesUploadArray.isEmpty && self.pendingOfflineUploads == 0 {
                     self.endBackgroundTaskIfNeeded()
                 }
                 return
             }

             var request = URLRequest(url: upload.url)
             request.setValue(Self.kOctetStreamContentType, forHTTPHeaderField: Self.kContentTypeHeader)
             if upload.sessionReplayFramesData.isGzipped {
                 request.setValue(Self.kGzipEncoding, forHTTPHeaderField: Self.kContentEncodingHeader)
                 request.setValue(Self.kGzipEncoding, forHTTPHeaderField: Self.kAcceptEncodingHeader)
             }
             request.setValue(String(upload.sessionReplayFramesData.count), forHTTPHeaderField: Self.kContentLengthHeader)
             request.setValue(applicationToken, forHTTPHeaderField: Self.kAppLicenseKeyHeader)

             request.httpMethod = Self.kPostMethod

             let session = URLSession(configuration: .default)
             let uploadTask = session.uploadTask(with: request, from: upload.sessionReplayFramesData) { data, response, error in
                 self.uploadQueue.async {
                     self.handleUploadResponse(data: data, response: response, error: error, dataSize: upload.sessionReplayFramesData.count, upload: upload)
                 }
             }

             uploadTask.resume()
         }
     }

    private func sendOfflineStorage() {
        // Prevent concurrent offline storage uploads
        guard pendingOfflineUploads == 0 else {
            return
        }

        // Check if offline storage is enabled
        guard NRMAFlags.shouldEnableOfflineStorage() else {
            // If disabled, clear any existing offline storage
            _ = NRMAOfflineStorage.clearAllOfflineDirectories()
            return
        }

        // Retrieve all offline data
        guard let offlineDataArray = offlineStorage.getAllOfflineData(true) else { // true = clear after retrieval
            return
        }

        guard !offlineDataArray.isEmpty else {
            return
        }

        NRLOG_AGENT_DEBUG("Number of offline session replay data posts: \(offlineDataArray.count)")

        // Set pending count immediately to prevent race condition
        pendingOfflineUploads = offlineDataArray.count
        beginBackgroundTaskIfNeeded()
        processOfflineUploads(offlineDataArray)
    }

    private func processOfflineUploads(_ offlineDataArray: [Data]) {
        for data in offlineDataArray {
            // Decode SessionReplayData
            guard let upload = try? JSONDecoder().decode(SessionReplayData.self, from: data) else {
                NRLOG_AGENT_DEBUG("Failed to decode offline session replay data")
                self.handleOfflineUploadComplete(size: 0)
                continue
            }

            // Create URLRequest with headers
            var request = URLRequest(url: upload.url)
            request.setValue(Self.kOctetStreamContentType, forHTTPHeaderField: Self.kContentTypeHeader)
            if upload.sessionReplayFramesData.isGzipped {
                request.setValue(Self.kGzipEncoding, forHTTPHeaderField: Self.kContentEncodingHeader)
                request.setValue(Self.kGzipEncoding, forHTTPHeaderField: Self.kAcceptEncodingHeader)
            }
            request.setValue(String(upload.sessionReplayFramesData.count), forHTTPHeaderField: Self.kContentLengthHeader)
            request.setValue(applicationToken, forHTTPHeaderField: Self.kAppLicenseKeyHeader)
            request.httpMethod = Self.kPostMethod
            request.httpBody = upload.sessionReplayFramesData

            // Send asynchronously
            let session = URLSession(configuration: .default)
            let task = session.dataTask(with: request) { [weak self] _, response, error in
                guard let self = self else { return }

                self.uploadQueue.async {
                    if let error = error as NSError?, NRMAOfflineStorage.checkError(toPersist: error) {
                        // Network error - persist back to storage
                        _ = self.offlineStorage.persistData(toDisk: data)
                        self.handleOfflineUploadComplete(size: 0)
                    } else {
                        // Success or non-network error - count as sent
                        self.handleOfflineUploadComplete(size: upload.sessionReplayFramesData.count)
                    }
                }
            }
            task.resume()
        }
    }

    private func handleOfflineUploadComplete(size: Int) {
        self.pendingOfflineUploads -= 1

        if size > 0 {
            self.offlineUploadMetricSize += size
        }

        // When all offline uploads complete, report metric and reset flag
        if self.pendingOfflineUploads == 0 {
            if self.offlineUploadMetricSize > 0 {
                NRMASupportMetricHelper.enqueueOfflinePayloadMetric(self.offlineUploadMetricSize)
                self.offlineUploadMetricSize = 0
            }
        }

        // Check if all uploads (regular + offline) are complete
        if self.pendingUploads == 0 && self.sessionReplayFramesUploadArray.isEmpty && self.pendingOfflineUploads == 0 {
            self.endBackgroundTaskIfNeeded()
        }
    }

    private func handleUploadResponse(data: Data?, response: URLResponse?, error: Error?, dataSize: Int, upload: SessionReplayData) {
       var errorCode = false
       var errorCodeInt = 0

       if let httpResponse = response as? HTTPURLResponse {
           errorCode = httpResponse.statusCode >= 300
           errorCodeInt = httpResponse.statusCode
       }

       if error == nil && !errorCode {
           NRLOG_AGENT_DEBUG("Session replay frames uploaded successfully.")
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
           self.pendingUploads -= 1
           NRMASupportMetricHelper.enqueueSessionReplaySuccessMetric(dataSize)
           // Try to send any offline storage
           self.sendOfflineStorage()
       } else if errorCodeInt == URL_TOO_LARGE {
           NRLOG_AGENT_DEBUG("Session replay frames failed to upload. error: \(String(describing: error)), response: \(String(describing: response))")
           NRMASupportMetricHelper.enqueueSessionReplayURLTooLargeMetric()
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
           self.pendingUploads -= 1
       } else {
           self.failureCount += 1
       }

       if self.failureCount > self.kNRMAMaxUploadRetry {
           NRLOG_AGENT_DEBUG("Session replay frames failed to upload. error: \(String(describing: error)), response: \(String(describing: response))")

           // Check if we should persist to offline storage
           if NRMAFlags.shouldEnableOfflineStorage(),
              let nsError = error as NSError?,
              NRMAOfflineStorage.checkError(toPersist: nsError) {
               if let encodedData = try? JSONEncoder().encode(upload) {
                   // Persist to offline storage for retry later
                   if self.offlineStorage.persistData(toDisk: encodedData) {
                       NRLOG_AGENT_DEBUG("Session replay data persisted to offline storage due to network error")
                   } else {
                       NRLOG_AGENT_DEBUG("Failed to persist session replay data to offline storage")
                       NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
                   }
               } else {
                   NRLOG_AGENT_DEBUG("Failed to encode session replay data for offline storage")
                   NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
               }
           } else {
               // Not a network error or offline storage disabled - record as failed
               NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
           }
           
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
           self.pendingUploads -= 1
       }

       self.isUploading = false
       self.processNextUploadTask()
       
       // End background task when all uploads are complete
       if self.pendingUploads == 0 && self.sessionReplayFramesUploadArray.isEmpty && self.pendingOfflineUploads == 0 {
           self.endBackgroundTaskIfNeeded()
       }
   }
    
    func uploadURL(uncompressedDataSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval, isFirstChunk: Bool, isGZipped: Bool) -> URL? {
        guard let config = NRMAHarvestController.configuration() else {
            NRLOG_AGENT_DEBUG("Error accessing harvester configuration information")
            return nil
        }
        guard let connectionInfo = NRMAAgentConfiguration.connectionInformation() else {
            NRLOG_AGENT_DEBUG("Error accessing connection information")
            return nil
        }
        var attributes: [String: String] = [
            "entityGuid": config.entity_guid,
            "isFirstChunk": String(isFirstChunk),
            "rrweb.version": "^2.0.0-alpha.17",
            "payload.type": "standard",
            "hasMeta": String(true),
            "hasReplay": String(true),
            "decompressedBytes": String(uncompressedDataSize),
            "replay.firstTimestamp": String(Int(firstTimestamp)),
            "replay.lastTimestamp": String(Int(lastTimestamp)),
            "appVersion": {
                guard let applicationInformation = connectionInfo.applicationInformation,
                      let appVersion = applicationInformation.appVersion as String? else {
                    return "unknown"
                }
                return appVersion
            }(),
            "instrumentation.provider": "mobile",
            "instrumentation.name": {
                guard let deviceInfo = connectionInfo.deviceInformation else {
                    return NewRelicInternalUtils.agentName()
                }
                let platform = deviceInfo.platform
                return platform.rawValue == 0 // NRMAPlatform_Native
                    ? NewRelicInternalUtils.agentName()
                    : NewRelicInternalUtils.string(from: platform)
            }(),
            "instrumentation.version": {
                guard let deviceInfo = connectionInfo.deviceInformation,
                      let platformVersion = deviceInfo.platformVersion as String? else {
                    return NewRelicInternalUtils.agentVersion()
                }
                return platformVersion
            }(),
            "collector.name": NewRelicInternalUtils.agentName()
        ]
        if isGZipped {
            attributes["content_encoding"] = Self.kGzipEncoding
        }
        do {
            if let agent = NewRelicAgentInternal.sharedInstance(), let analyticsController = agent.analyticsController, let sessionAttributes = analyticsController.sessionAttributeJSONString(),
               !sessionAttributes.isEmpty,
               let data = sessionAttributes.data(using: .utf8),
               let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                for (key, value) in dictionary {
                    // Convert different types to strings
                    if let stringValue = value as? String {
                        attributes[key] = stringValue
                    } else if let boolValue = value as? Bool {
                        attributes[key] = boolValue ? "true" : "false"
                    } else if let numberValue = value as? NSNumber {
                        // Check if it's a boolean wrapped as NSNumber
                        if CFGetTypeID(numberValue as CFTypeRef) == CFBooleanGetTypeID() {
                            attributes[key] = numberValue.boolValue ? "true" : "false"
                        } else {
                            attributes[key] = numberValue.stringValue
                        }
                    } else {
                        // For any other type, use string description
                        attributes[key] = String(describing: value)
                    }
                }
            }
        }
        catch {
            NRLOG_AGENT_DEBUG("Failed to retrieve session attributes: \(error)")
        }
        
        let attributesString = attributes.map { key, value in
            return "\(key)=\(value)"
        }.joined(separator: "&")

        var urlComponents = URLComponents(string:"https://\(self.url as String)")

        urlComponents?.queryItems = [
            URLQueryItem(name: "type", value: "SessionReplay"),
            URLQueryItem(name: "app_id", value: String(config.application_id)),
            URLQueryItem(name: "protocol_version", value: "0"),
            URLQueryItem(name: "timestamp", value: String(Int64((Date().timeIntervalSince1970 * 1000).rounded()))),
            URLQueryItem(name: "attributes", value: attributesString)
        ]

        return urlComponents?.url
    }
}

extension Data {
    func gzipped() throws -> Data {
        var stream = z_stream()
        var status: Int32

        status = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))

        guard status == Z_OK else {
            throw GzipError(code: status, message: "deflateInit2_ failed")
        }

        var compressedData = Data()
       
        try self.withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.baseAddress!.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(self.count)

            repeat {
                let chunkSize = 16384
                var outputBuffer = [UInt8](repeating: 0, count: chunkSize)
               
                try outputBuffer.withUnsafeMutableBytes { (outputBufferPointer: UnsafeMutableRawBufferPointer) in
                    // Get a typed pointer to the start of the buffer's memory.
                    let typedPointer = outputBufferPointer.baseAddress!.assumingMemoryBound(to: Bytef.self)
                   
                    stream.next_out = typedPointer
                    // This avoids accessing `outputBuffer.count` inside the closure.
                    stream.avail_out = uInt(chunkSize)

                    status = deflate(&stream, Z_FINISH)
                   
                    if status != Z_OK && status != Z_STREAM_END {
                        throw GzipError(code: status, message: "deflate failed")
                    }
                   
                    let bytesWritten = chunkSize - Int(stream.avail_out)
                   
                    if bytesWritten > 0 {
                        //This avoids referencing the `outputBuffer` variable itself.
                        compressedData.append(typedPointer, count: bytesWritten)
                    }
                }
            } while status != Z_STREAM_END
        }

        guard deflateEnd(&stream) == Z_OK else {
            throw GzipError(code: Z_ERRNO, message: "deflateEnd failed")
        }

        return compressedData
    }
    
    var isGzipped: Bool {
        return self.count >= 2 && self[0] == 0x1f && self[1] == 0x8b
    }
}

  // A simple error struct
  struct GzipError: Error {
      let code: Int32
      let message: String
  }
