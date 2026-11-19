//
//  SessionReplayExternalBuffer.swift
//  Agent
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
@_implementationOnly import NewRelicPrivate

#if os(iOS) || os(tvOS)

/// What an upload of buffered events describes, for building its URL.
@available(iOS 13.0, *)
struct ExternalReplayUploadMetadata: Equatable {
    let uncompressedSize: Int
    let firstTimestamp: TimeInterval
    let lastTimestamp: TimeInterval
    let isFirstChunk: Bool
    let isGZipped: Bool
    /// Whether the upload holds a Meta event anywhere.
    let hasMeta: Bool
}

@available(iOS 13.0, *)
enum ExternalReplayAppendResult: Equatable {
    case appended(kept: Int, droppedBeforeMeta: Int)
    case invalid
}

/// One upload's worth of whole batches, in the order they arrived: a JSON array, gzipped when possible.
@available(iOS 13.0, *)
struct ExternalReplayChunk {
    let payload: Data
    let metadata: ExternalReplayUploadMetadata
}

/// Holds rrweb events from an external replay source, such as the Flutter agent, until they're uploaded.
///
/// Each batch keeps the bytes it arrived with, in the layout crash recovery reads
/// (`checkForPreviousSessionFiles`): one JSON array file per batch,
/// `<directory>/<sessionId>/frame_<n>.json`, plus `<directory>/<sessionId>_upload_url.txt`, which
/// describes everything on disk. A session's events are kept from its first batch that holds a
/// Meta on, and every upload takes all of them, so a file can start with any event.
///
/// Not thread safe: use it from one serial queue.
@available(iOS 13.0, *)
final class SessionReplayExternalBuffer {
    private struct Batch {
        let fileIndex: Int
        let firstTimestamp: TimeInterval
        let lastTimestamp: TimeInterval
        let byteCount: Int
        let holdsMeta: Bool
    }

    private struct Event {
        let type: Int
        let timestamp: TimeInterval
    }

    private struct TakenBatch {
        let batch: Batch
        let contents: Data
        let gzipped: Data?

        var estimatedUploadSize: Int { return gzipped?.count ?? contents.count }
    }

    private static let metaType = 4

    /// rrweb timestamps are milliseconds since 1970. A value outside this range is an encoder bug,
    /// and outside Int's range it would stop the app when the upload URL converts it.
    private static let timestampRange = 0.0..<1e15

    private let directory: URL
    private let maxUploadBytes: Int
    private let urlProvider: (ExternalReplayUploadMetadata) -> URL?

    private var batches: [Batch] = []
    private var folderSessionId: String?
    private var nextFileIndex = 0

    /// The session whose events are kept: set by a stored batch that holds a Meta, and cleared by
    /// a final take, a reset, or a failed write. Until it's set, batches without a Meta are dropped.
    private(set) var openSessionId: String?

    /// The session whose folder holds the buffered events, or nil when nothing is buffered.
    var sessionId: String? {
        return folderSessionId
    }

    init(directory: URL, maxUploadBytes: Int, urlProvider: @escaping (ExternalReplayUploadMetadata) -> URL?) {
        self.directory = directory
        self.maxUploadBytes = maxUploadBytes
        self.urlProvider = urlProvider
    }

    /// Stores a JSON array of rrweb events as one file. Batches are dropped until one that holds a
    /// Meta opens the session's stream, and that one is kept whole. A batch that isn't an array of
    /// objects with a numeric `type` and `timestamp` changes nothing.
    func append(_ batch: Data, sessionId: String, isFirstChunk: Bool) -> ExternalReplayAppendResult {
        guard let parsed = Self.parse(batch) else {
            return .invalid
        }

        // An earlier session's batches stay on disk for crash recovery, under their own URL file.
        if let bufferedSessionId = folderSessionId, bufferedSessionId != sessionId {
            reset()
        }

        let events = parsed.events
        guard !events.isEmpty else {
            return .appended(kept: 0, droppedBeforeMeta: 0)
        }
        let holdsMeta = events.contains { $0.type == Self.metaType }
        guard openSessionId == sessionId || holdsMeta else {
            return .appended(kept: 0, droppedBeforeMeta: events.count)
        }
        guard write(parsed.contents, sessionId: sessionId) else {
            openSessionId = nil
            return .appended(kept: 0, droppedBeforeMeta: 0)
        }

        batches.append(Batch(fileIndex: nextFileIndex,
                             firstTimestamp: events[0].timestamp,
                             lastTimestamp: events[events.count - 1].timestamp,
                             byteCount: parsed.contents.count,
                             holdsMeta: holdsMeta))
        nextFileIndex += 1
        openSessionId = sessionId
        writeURLFile(isFirstChunk: isFirstChunk)
        return .appended(kept: events.count, droppedBeforeMeta: 0)
    }

    /// Takes every batch for upload, packed into chunks of at most `maxUploadBytes` after gzip.
    /// A regular take leaves the stream open, so the next batch continues it without a Meta.
    /// A final take closes it. A single batch over the limit still goes out, alone.
    func takeChunks(final: Bool, isFirstChunk: Bool) -> [ExternalReplayChunk] {
        let taken = batches
        batches.removeAll()
        if final {
            openSessionId = nil
        }
        guard !taken.isEmpty else {
            return []
        }

        // Greedy, by each batch's own gzipped size. packPayloads checks the real combined size.
        var packs: [[TakenBatch]] = []
        var packSize = 0
        for batch in taken.compactMap(load) {
            if packs.isEmpty || packSize + batch.estimatedUploadSize > maxUploadBytes {
                packs.append([])
                packSize = 0
            }
            packs[packs.count - 1].append(batch)
            packSize += batch.estimatedUploadSize
        }
        let chunks = packs.flatMap { packPayloads($0[...]) }.enumerated().map { index, packed in
            ExternalReplayChunk(payload: packed.payload,
                                metadata: ExternalReplayUploadMetadata(uncompressedSize: packed.uncompressedSize,
                                                                       firstTimestamp: packed.firstTimestamp,
                                                                       lastTimestamp: packed.lastTimestamp,
                                                                       isFirstChunk: isFirstChunk && index == 0,
                                                                       isGZipped: packed.payload.isGzipped,
                                                                       hasMeta: packed.hasMeta))
        }

        // Nothing is left, so the folder and its URL file go too.
        if let folder = folderURL() {
            try? FileManager.default.removeItem(at: folder)
        }
        if let urlFile = urlFileURL() {
            try? FileManager.default.removeItem(at: urlFile)
        }
        folderSessionId = nil
        nextFileIndex = 0
        return chunks
    }

    /// Forgets the buffered batches and leaves their files on disk. Batches are dropped until one holds a Meta.
    func reset() {
        batches.removeAll()
        folderSessionId = nil
        nextFileIndex = 0
        openSessionId = nil
    }

    // MARK: - Parsing

    /// The batch without the whitespace around its array, and its events. Nil unless it's a JSON
    /// array of objects with a numeric `type` and `timestamp`.
    private static func parse(_ batch: Data) -> (contents: Data, events: [Event])? {
        guard let start = batch.firstIndex(where: { !isWhitespace($0) }),
              let last = batch.lastIndex(where: { !isWhitespace($0) }),
              batch[start] == UInt8(ascii: "["), batch[last] == UInt8(ascii: "]") else {
            return nil
        }
        let contents = batch[start...last]
        guard let elements = (try? JSONSerialization.jsonObject(with: contents)) as? [Any] else {
            return nil
        }
        var events: [Event] = []
        events.reserveCapacity(elements.count)
        for element in elements {
            guard let object = element as? [String: Any],
                  let type = number(object["type"]),
                  let timestamp = number(object["timestamp"]),
                  timestampRange.contains(timestamp.doubleValue) else {
                return nil
            }
            events.append(Event(type: type.intValue, timestamp: timestamp.doubleValue))
        }
        return (contents, events)
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() else {
            return nil
        }
        return number
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        return byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
    }

    // MARK: - Uploads

    private typealias PackedPayload = (payload: Data, uncompressedSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval,
                                       hasMeta: Bool)

    /// Reads a batch's file and gzips it, to estimate its share of an upload.
    private func load(_ batch: Batch) -> TakenBatch? {
        guard let fileURL = batchFileURL(batch.fileIndex),
              let contents = try? Data(contentsOf: fileURL),
              contents.count > 2, contents.first == UInt8(ascii: "["), contents.last == UInt8(ascii: "]") else {
            NRLOG_AGENT_DEBUG("Failed to read an external session replay batch.")
            return nil
        }
        return TakenBatch(batch: batch, contents: contents, gzipped: Self.gzip(contents))
    }

    /// Nil if gzip fails; the upload then goes out uncompressed, as the agent's own replay does.
    private static func gzip(_ data: Data) -> Data? {
        do {
            return try data.gzipped()
        } catch {
            NRLOG_AGENT_DEBUG("Failed to gzip external session replay data: \(error.localizedDescription)")
            return nil
        }
    }

    /// One payload for the pack, halved until each part fits or holds a single batch.
    private func packPayloads(_ pack: ArraySlice<TakenBatch>) -> [PackedPayload] {
        guard let first = pack.first, let last = pack.last else {
            return []
        }
        let raw: Data
        let gzipped: Data?
        if pack.count == 1 {
            raw = first.contents
            gzipped = first.gzipped
        } else {
            raw = Self.joinArrays(pack.map(\.contents))
            gzipped = Self.gzip(raw)
        }
        let payload = gzipped ?? raw
        if payload.count > maxUploadBytes && pack.count > 1 {
            let middle = pack.startIndex + pack.count / 2
            return packPayloads(pack[..<middle]) + packPayloads(pack[middle...])
        }
        return [(payload, raw.count, first.batch.firstTimestamp, last.batch.lastTimestamp, pack.contains { $0.batch.holdsMeta })]
    }

    /// Joins JSON arrays into one, keeping their elements' bytes.
    private static func joinArrays(_ arrays: [Data]) -> Data {
        var joined = Data("[".utf8)
        for (index, array) in arrays.enumerated() {
            if index > 0 {
                joined.append(contentsOf: ",".utf8)
            }
            joined.append(array[(array.startIndex + 1)..<(array.endIndex - 1)])
        }
        joined.append(contentsOf: "]".utf8)
        return joined
    }

    // MARK: - Files

    /// Writes a batch's file. A failed write leaves no folder recorded when nothing else is buffered.
    private func write(_ contents: Data, sessionId: String) -> Bool {
        if batches.isEmpty {
            folderSessionId = sessionId
            nextFileIndex = 0
        }
        guard let folder = folderURL(), let fileURL = batchFileURL(nextFileIndex) else {
            return false
        }
        do {
            try FileManager.default.createDirectory(at: folder,
                                                    withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try contents.write(to: fileURL, options: .atomic)
        } catch {
            NRLOG_AGENT_DEBUG("Failed to write external session replay events: \(error)")
            if batches.isEmpty {
                folderSessionId = nil
            }
            return false
        }
        return true
    }

    /// Describes everything on disk, so crash recovery can upload it as one payload.
    private func writeURLFile(isFirstChunk: Bool) {
        guard let urlFile = urlFileURL(), let first = batches.first, let last = batches.last else {
            return
        }
        let metadata = ExternalReplayUploadMetadata(uncompressedSize: batches.reduce(0) { $0 + $1.byteCount },
                                                    firstTimestamp: first.firstTimestamp,
                                                    lastTimestamp: last.lastTimestamp,
                                                    isFirstChunk: isFirstChunk,
                                                    isGZipped: true,
                                                    hasMeta: batches.contains { $0.holdsMeta })
        guard let uploadURL = urlProvider(metadata) else {
            NRLOG_AGENT_DEBUG("Failed to construct an upload URL for external session replay events.")
            return
        }
        do {
            try uploadURL.absoluteString.write(to: urlFile, atomically: true, encoding: .utf8)
        } catch {
            NRLOG_AGENT_DEBUG("Failed to write the external session replay upload URL: \(error)")
        }
    }

    private func folderURL() -> URL? {
        return folderSessionId.map { directory.appendingPathComponent($0, isDirectory: true) }
    }

    private func batchFileURL(_ index: Int) -> URL? {
        return folderURL()?.appendingPathComponent("frame_\(index).json")
    }

    private func urlFileURL() -> URL? {
        return folderSessionId.map { directory.appendingPathComponent("\($0)_upload_url.txt") }
    }
}

#endif
