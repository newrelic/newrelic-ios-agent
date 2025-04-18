//
//  SessionReplayReporter.swift
//  Agent
//
//  Created by Mike Bruin on 3/12/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import Compression
import NewRelicPrivate

@objcMembers
public class SessionReplayReporter: NSObject {
    private var sessionReplayFramesUploadArray: [Data] = []
    private var isUploading = false
    private var failureCount = 0
    private let uploadQueue = DispatchQueue(label: "com.newrelicagent.sessionreplayqueue")
    private let kNRMAMaxUploadRetry = 3
    private let applicationToken: String

    @objc public init(applicationToken: String) {
        self.applicationToken = applicationToken
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
                 NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("replay") // SUBJECT TO CHANGE WITH ENDPOINT NAME
                 return
             }

             var request = URLRequest(url: self.uploadURL()!)
             request.setValue("application/json", forHTTPHeaderField: "Content-Type")
             request.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
             request.setValue(applicationToken, forHTTPHeaderField:"X-App-License-Key")

             request.httpMethod = "POST"

             let session = URLSession(configuration: .default)
             let uploadTask = session.uploadTask(with: request, from: formattedData) { data, response, error in
                 self.handleUploadResponse(data: data, response: response, error: error, originalDataSize: formattedData.count)
             }

             uploadTask.resume()
         }
     }
    
    private func handleUploadResponse(data: Data?, response: URLResponse?, error: Error?, originalDataSize: Int) {
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
           NRMASupportMetricHelper.enqueueSessionReplaySuccessMetric(originalDataSize)
       } else {
           self.failureCount += 1
       }

       if self.failureCount > self.kNRMAMaxUploadRetry {
           print("Session replay frames failed to upload. error: \(String(describing: error)), response: \(String(describing: response))")
           NRMASupportMetricHelper.enqueueSessionReplayFailedMetric()
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
       }

       self.isUploading = false
       self.processNextUploadTask()
   }
    
    private func uploadURL() -> URL? {
        let urlString = "https://staging-mobile-collector.newrelic.com/mobile/blobs?type=SessionReplay&app_id=0&attributes=version%3Dsasha-tests-the-pipeline"
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
