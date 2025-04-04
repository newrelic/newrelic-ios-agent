//
//  SessionReplayReporter.swift
//  Agent
//
//  Created by Mike Bruin on 3/12/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import Compression
//import NewRelicPrivate

@objcMembers
public class SessionReplayReporter: NSObject {
    private var sessionReplayFramesUploadArray: [Data] = []
    private var isUploading = false
    private var failureCount = 0
    private let uploadQueue = DispatchQueue(label: "com.newrelicagent.sessionreplayqueue")
    private let kNRMAMaxUploadRetry = 3
    private let agentVersion: String
    public var sessionId: String

    @objc public init(agentVersion: String, sessionId: String) {
        self.agentVersion = agentVersion
        self.sessionId = sessionId
    }

    @objc public func enqueueSessionReplayUpload(sessionReplayFramesData: Data) {
       uploadQueue.async {
           guard let gzippedData = sessionReplayFramesData.gzipped() else {
               print("Failed to gzip session replay data")
               return
           }
           self.sessionReplayFramesUploadArray.append(gzippedData)
           self.processNextUploadTask()
       }
   }

    private func processNextUploadTask() {
         uploadQueue.async { [weak self] in
             guard let self = self, !self.isUploading, !self.sessionReplayFramesUploadArray.isEmpty else {
                 return
             }

             self.isUploading = true
             let formattedData = self.sessionReplayFramesUploadArray.first!

             if formattedData.count > kNRMAMaxPayloadSizeLimit {
                 print("Unable to send session replay frames because payload is larger than 1 MB.")
                 self.isUploading = false
                 //NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("replay")
                 return
             }

             var request = URLRequest(url: self.uploadURL()!)
             request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
             request.httpMethod = "POST"

             let session = URLSession(configuration: .default)
             let uploadTask = session.uploadTask(with: request, from: formattedData) { data, response, error in
                 self.handleUploadResponse(data: data, response: response, error: error)
             }

             uploadTask.resume()
         }
     }
    
    private func handleUploadResponse(data: Data?, response: URLResponse?, error: Error?) {
       var errorCode = false
       var errorCodeInt = 0

       if let httpResponse = response as? HTTPURLResponse {
           errorCode = httpResponse.statusCode >= 300
           errorCodeInt = httpResponse.statusCode
       }

       if error == nil && !errorCode {
           print("Session replay frames uploaded successfully.")
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
       } else {
           print("Session replay frames failed to upload. error: \(String(describing: error)), response: \(String(describing: response))")
           self.failureCount += 1
           // NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
       }

       if self.failureCount > self.kNRMAMaxUploadRetry {
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
       }

       self.isUploading = false
       self.processNextUploadTask()
   }
    
    private func uploadURL() -> URL? {
        let urlString = """
        https://staging-bam.nr-data.net/browser/blobs?browser_monitoring_key=NRJS-136db61998107c1947d&type=SessionReplay&app_id=213729589&protocol_version=0&timestamp=\(Date().timeIntervalSince1970 * 1000)&attributes=entityGuid%MTA4MTY5OTR8QlJPV1NFUnxBUFBMSUNBVElPTnwyMTM3Mjk1ODk%26harvestId%3D852c55a391bf26cf_e511ee33802cb580_2%26replay.firstTimestamp%3D1740776671411%26replay.lastTimestamp%3D1740776691411%26replay.nodes%3D311%26session.durationMs%3D32708%26agentVersion%3D\(agentVersion)%26session%3D\(sessionId)%26hasMeta%3Dtrue%26hasSnapshot%3Dtrue%26hasError%3Dfalse%26isFirstChunk%3Dtrue%26invalidStylesheetsDetected%3Dfalse%26inlinedAllStylesheets%3Dtrue%26rrweb.version%3D%255E2.0.0-alpha.17%26payload.type%3Dstandard%26enduser.id%3Dywang%40newrelic.com%26currentUrl%3Dhttps%3A%2F%2Fstaging-one.newrelic.com%2Fcatalogs%2Fsoftware
        """
        return URL(string: urlString)
    }
}

extension Data {
    func gzipped() -> Data? {
        guard !self.isEmpty else { return nil }
        return self.withUnsafeBytes { (sourcePointer: UnsafeRawBufferPointer) -> Data? in
            guard let sourceBaseAddress = sourcePointer.baseAddress else { return nil }
            
            let sourceBuffer = UnsafeBufferPointer(start: sourceBaseAddress.assumingMemoryBound(to: UInt8.self), count: self.count)
            
            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.count)
            defer { destinationBuffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(destinationBuffer, self.count, sourceBuffer.baseAddress!, sourceBuffer.count, nil, COMPRESSION_ZLIB)
            
            guard compressedSize != 0 else { return nil }
            
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
    }
}
