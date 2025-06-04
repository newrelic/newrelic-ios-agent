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
           guard let gzippedData = NRMAHarvesterConnection.gzipData(upload.sessionReplayFramesData) else {
               NRLOG_ERROR("Failed to gzip session replay data")
               return
           }
           upload.sessionReplayFramesData = gzippedData
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
             let formattedData = upload.sessionReplayFramesData

             if formattedData.count > kNRMAMaxPayloadSizeLimit {
                 NRLOG_WARNING("Unable to send session replay frames because payload is larger than 1 MB.")
                 self.isUploading = false
                 NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("replay") // SUBJECT TO CHANGE WITH ENDPOINT NAME
                 return
             }

             var request = URLRequest(url: upload.url)
             request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
             request.setValue("gzip", forHTTPHeaderField: "Content-Encoding")
             request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
             request.setValue(String(formattedData.count), forHTTPHeaderField: "Content-Length")
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
           NRLOG_DEBUG("Session replay frames uploaded successfully.")
           self.sessionReplayFramesUploadArray.removeFirst()
           self.failureCount = 0
           NRMASupportMetricHelper.enqueueSessionReplaySuccessMetric(originalDataSize)
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
    
    func uploadURL(uncompressedDataSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval, isFirstChunk: Bool) -> URL? {
        guard let config = NRMAHarvestController.configuration() else {
            NRLOG_ERROR("Error accessing harvester configuration information")
            return nil
        }
        let attributes: [String: String] = [
            "entityGuid": config.entity_guid,
            "agentVersion": NewRelicInternalUtils.agentVersion(),
            "session": NewRelicAgentInternal.sharedInstance().currentSessionId(),
            "isFirstChunk": String(isFirstChunk),
            "rrweb.version": "^2.0.0-alpha.17",
            "payload.type": "standard",
            "hasMeta": String(true),
            "decompressedBytes": String(uncompressedDataSize),
            "replay.firstTimestamp": String(firstTimestamp),
            "replay.lastTimestamp": String(lastTimestamp)
        ]
        
        let attributesString = attributes.map { key, value in
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return "\(key)=\(encodedValue)"
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
