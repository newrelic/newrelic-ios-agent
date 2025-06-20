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

    @objc public init(applicationToken: String) {
        self.applicationToken = applicationToken
    }

    func enqueueSessionReplayUpload(upload: SessionReplayData) {
        uploadQueue.async {
            self.sessionReplayFramesUploadArray.append(upload)
            self.processNextUploadTask()
        }
   }

    private func processNextUploadTask() {
         uploadQueue.async { [weak self] in
             guard let self = self, !self.isUploading, !self.sessionReplayFramesUploadArray.isEmpty else {
                 return
             }

             self.isUploading = true
             
             let upload = self.sessionReplayFramesUploadArray.first!

             if upload.sessionReplayFramesData.count > kNRMAMaxPayloadSizeLimit {
                 NRLOG_WARNING("Unable to send session replay frames because payload is larger than 1 MB. \(upload.sessionReplayFramesData.count) bytes.")
                 self.isUploading = false
                 NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("SessionReplay")
                 self.sessionReplayFramesUploadArray.removeFirst()
                 return
             }

             var request = URLRequest(url: upload.url)
             request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
             if upload.sessionReplayFramesData.isGzipped {
                 request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
                 request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
             }
             request.setValue(String(upload.sessionReplayFramesData.count), forHTTPHeaderField: "Content-Length")
             request.setValue(applicationToken, forHTTPHeaderField:"X-App-License-Key")

             request.httpMethod = "POST"

             let session = URLSession(configuration: .default)
             let uploadTask = session.uploadTask(with: request, from: upload.sessionReplayFramesData) { data, response, error in
                 self.handleUploadResponse(data: data, response: response, error: error, dataSize: upload.sessionReplayFramesData.count)
             }

             uploadTask.resume()
         }
     }
    
    private func handleUploadResponse(data: Data?, response: URLResponse?, error: Error?, dataSize: Int) {
       var errorCode = false
       var errorCodeInt = 0

       if let httpResponse = response as? HTTPURLResponse {
           errorCode = httpResponse.statusCode >= 300
           errorCodeInt = httpResponse.statusCode
       }

       if error == nil && !errorCode {
           NRLOG_DEBUG("Session replay frames uploaded successfully.")
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
           NRMASupportMetricHelper.enqueueSessionReplaySuccessMetric(dataSize)
       } else {
           self.failureCount += 1
       }

       if self.failureCount > self.kNRMAMaxUploadRetry {
           NRLOG_ERROR("Session replay frames failed to upload. error: \(String(describing: error)), response: \(String(describing: response))")
           NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
       }

       self.isUploading = false
       self.processNextUploadTask()
   }
    
    func uploadURL(uncompressedDataSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval, isFirstChunk: Bool, isGZipped: Bool) -> URL? {
        guard let config = NRMAHarvestController.configuration() else {
            NRLOG_ERROR("Error accessing harvester configuration information")
            return nil
        }
        guard let cStringAppVersion: UnsafePointer<CChar> = NRMA_getAppVersion(), let appVersion = String(validatingUTF8: cStringAppVersion) else {
            NRLOG_ERROR("Error accessing app version information")
            return nil
        }
        var attributes: [String: String] = [
            "entityGuid": config.entity_guid,
            "isFirstChunk": String(isFirstChunk),
            "rrweb.version": "^2.0.0-alpha.17",
            "payload.type": "standard",
            "hasMeta": String(true),
            "decompressedBytes": String(uncompressedDataSize),
            "replay.firstTimestamp": String(firstTimestamp),
            "replay.lastTimestamp": String(lastTimestamp),
            "appVersion": appVersion
        ]
        if isGZipped {
            attributes["content_encoding"] = "gzip"
        }
        do {
            if let sessionAttributes = NewRelicAgentInternal.sharedInstance().analyticsController.sessionAttributeJSONString(),
               !sessionAttributes.isEmpty,
               let data = sessionAttributes.data(using: .utf8),
               let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                for (key, value) in dictionary {
                    attributes[key] = value as? String
                }
            }
        } catch {
            NRLOG_ERROR("Failed to retrieve session attributes: \(error)")
        }
        
        let attributesString = attributes.map { key, value in
            return "\(key)=\(value)"
        }.joined(separator: "&")

        var urlComponents = URLComponents(string: "https://staging-mobile-collector.newrelic.com/mobile/blobs")

        urlComponents?.queryItems = [
            URLQueryItem(name: "type", value: "SessionReplay"),
            URLQueryItem(name: "app_id", value: String(config.application_id)),
            URLQueryItem(name: "protocol_version", value: "0"),
            URLQueryItem(name: "timestamp", value: String(Int64(Date().timeIntervalSince1970 * 1000))),
            URLQueryItem(name: "attributes", value: attributesString)
        ]

        NRLOG_DEBUG(urlComponents?.url?.absoluteString ?? "Error constructing URL for session replay upload")
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
