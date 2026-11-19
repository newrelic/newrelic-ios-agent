//
//  SessionReplayExternalTestSupport.swift
//  NewRelicAgent
//
//  Copyright © 2026 New Relic. All rights reserved.
//
//  Shared helpers for the tests of rrweb events from an external replay source.
//

import Foundation
import zlib
@testable import NewRelic

func rrwebEvent(_ type: Int, _ timestamp: Int, _ data: String = "{}") -> String {
    return #"{"type":\#(type),"timestamp":\#(timestamp),"data":\#(data)}"#
}

func rrwebBatch(_ events: [String]) -> String {
    return "[" + events.joined(separator: ",") + "]"
}

/// Text that gzip can't shrink much: base64 of random bytes.
func randomText(_ count: Int) -> String {
    let bytes = (0..<count).map { _ in UInt8.random(in: 0...255) }
    return String(Data(bytes).base64EncodedString().prefix(count))
}

func gunzipForTests(_ data: Data) throws -> Data {
    var stream = z_stream()
    var status = inflateInit2_(&stream, 15 + 16, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard status == Z_OK else {
        throw NSError(domain: "gunzip", code: Int(status), userInfo: nil)
    }
    defer { inflateEnd(&stream) }

    var output = Data()
    try data.withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) in
        stream.next_in = UnsafeMutablePointer(mutating: inputBuffer.baseAddress!.assumingMemoryBound(to: Bytef.self))
        stream.avail_in = uInt(data.count)

        repeat {
            let chunkSize = 16384
            var outputBuffer = [UInt8](repeating: 0, count: chunkSize)
            try outputBuffer.withUnsafeMutableBytes { (outputBufferPointer: UnsafeMutableRawBufferPointer) in
                let typedPointer = outputBufferPointer.baseAddress!.assumingMemoryBound(to: Bytef.self)
                stream.next_out = typedPointer
                stream.avail_out = uInt(chunkSize)

                status = inflate(&stream, Z_NO_FLUSH)
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw NSError(domain: "gunzip", code: Int(status), userInfo: nil)
                }

                let bytesWritten = chunkSize - Int(stream.avail_out)
                if bytesWritten > 0 {
                    output.append(typedPointer, count: bytesWritten)
                }
            }
        } while status != Z_STREAM_END
    }
    return output
}

/// Records the upload URLs it's asked for and the uploads it's given, instead of sending them.
final class CapturingSessionReplayReporter: SessionReplayReporter {
    struct Request: Equatable {
        let uncompressedDataSize: Int
        let firstTimestamp: TimeInterval
        let lastTimestamp: TimeInterval
        let isFirstChunk: Bool
        let isGZipped: Bool
        let hasMeta: Bool
    }

    // Written on the replay queue, read by the tests after draining it.
    private let lock = NSLock()
    private var recordedRequests: [URL: Request] = [:]
    private var recordedUploads: [SessionReplayData] = []

    var requests: [URL: Request] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    var uploads: [SessionReplayData] {
        lock.lock()
        defer { lock.unlock() }
        return recordedUploads
    }

    override func uploadURL(uncompressedDataSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval,
                            isFirstChunk: Bool, isGZipped: Bool, hasMeta: Bool = true) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        let url = URL(string: "https://test.invalid/upload/\(recordedRequests.count)")!
        recordedRequests[url] = Request(uncompressedDataSize: uncompressedDataSize, firstTimestamp: firstTimestamp,
                                        lastTimestamp: lastTimestamp, isFirstChunk: isFirstChunk,
                                        isGZipped: isGZipped, hasMeta: hasMeta)
        return url
    }

    override func enqueueSessionReplayUpload(upload: SessionReplayData) {
        lock.lock()
        defer { lock.unlock() }
        recordedUploads.append(upload)
    }
}
