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
}

@available(iOS 13.0, *)
enum ExternalReplayAppendResult: Equatable {
    case appended(kept: Int, droppedBeforeMeta: Int)
    case invalid
}

/// One upload's worth of whole segments: a JSON array that starts with a Meta, gzipped when possible.
@available(iOS 13.0, *)
struct ExternalReplayChunk {
    let payload: Data
    let metadata: ExternalReplayUploadMetadata
}

/// Holds rrweb events from an external replay source, such as the Flutter agent, until they're uploaded.
///
/// Events keep the bytes they arrived with, in the layout crash recovery reads
/// (`checkForPreviousSessionFiles`): one JSON array file per segment,
/// `<directory>/<sessionId>/frame_<n>.json`, plus `<directory>/<sessionId>_upload_url.txt`, which
/// describes everything on disk. A segment starts at a Meta event, so every file starts with one.
///
/// Not thread safe: use it from one serial queue.
@available(iOS 13.0, *)
final class SessionReplayExternalBuffer {
    private struct Segment {
        let fileIndex: Int
        let firstTimestamp: TimeInterval
        var lastTimestamp: TimeInterval
        var byteCount: Int
        var hasFullSnapshot: Bool
    }

    private struct Event {
        let type: Int
        let timestamp: TimeInterval
        let bytes: Range<Data.Index>
    }

    private struct TakenSegment {
        let segment: Segment
        let contents: Data
        let gzipped: Data?

        var estimatedUploadSize: Int { return gzipped?.count ?? contents.count }
    }

    private static let metaType = 4
    private static let fullSnapshotType = 2

    /// rrweb timestamps are milliseconds since 1970. A value outside this range is an encoder bug,
    /// and outside Int's range it would stop the app when the upload URL converts it.
    private static let timestampRange = 0.0..<1e15

    private let directory: URL
    private let maxUploadBytes: Int
    private let urlProvider: (ExternalReplayUploadMetadata) -> URL?

    private var segments: [Segment] = []
    private var folderSessionId: String?
    private var nextFileIndex = 0

    /// Whether events that don't start a segment are kept. False until the first Meta,
    /// and again after a final take, a reset, or a failed write.
    private(set) var hasOpenSegment = false

    /// The session whose folder holds the buffered events, or nil when nothing is buffered.
    var sessionId: String? {
        return folderSessionId
    }

    init(directory: URL, maxUploadBytes: Int, urlProvider: @escaping (ExternalReplayUploadMetadata) -> URL?) {
        self.directory = directory
        self.maxUploadBytes = maxUploadBytes
        self.urlProvider = urlProvider
    }

    /// Stores a JSON array of rrweb events. Events that arrive while no segment is open are dropped
    /// until the next Meta. A batch that isn't an array of objects with a numeric `type` and
    /// `timestamp` changes nothing.
    func append(_ batch: Data, sessionId: String, isFirstChunk: Bool) -> ExternalReplayAppendResult {
        guard let events = Self.parse(batch) else {
            return .invalid
        }

        // One run per segment the events go to. Only the first run can continue the open segment.
        var runs: [(opensSegment: Bool, events: [Event])] = []
        var droppedBeforeMeta = 0
        for event in events {
            if event.type == Self.metaType {
                runs.append((opensSegment: true, events: [event]))
            } else if !runs.isEmpty {
                runs[runs.count - 1].events.append(event)
            } else if hasOpenSegment {
                runs.append((opensSegment: false, events: [event]))
            } else {
                droppedBeforeMeta += 1
            }
        }

        var kept = 0
        for run in runs {
            let written = run.opensSegment
                ? openSegment(with: run.events, from: batch, sessionId: sessionId)
                : appendToOpenSegment(run.events, from: batch)
            if written {
                kept += run.events.count
            }
        }

        if kept > 0 {
            writeURLFile(isFirstChunk: isFirstChunk)
        }
        return .appended(kept: kept, droppedBeforeMeta: droppedBeforeMeta)
    }

    /// Takes whole segments for upload, packed into chunks of at most `maxUploadBytes` after gzip.
    /// A regular take keeps the segment in progress, so the next upload starts at a Meta too.
    /// A final take sends everything except a trailing segment that never got its FullSnapshot,
    /// and leaves no segment open. A single segment over the limit still goes out, alone.
    func takeChunks(final: Bool, isFirstChunk: Bool) -> [ExternalReplayChunk] {
        let taken = final ? segments : Array(segments.dropLast())
        segments.removeFirst(taken.count)
        if final {
            hasOpenSegment = false
        }
        guard !taken.isEmpty else {
            return []
        }

        var sent = taken
        if final, let last = sent.last, !last.hasFullSnapshot {
            NRLOG_AGENT_DEBUG("Dropping external session replay events after a Meta that has no FullSnapshot.")
            sent.removeLast()
        }

        // Greedy, by each segment's own gzipped size. packPayloads checks the real combined size.
        var packs: [[TakenSegment]] = []
        var packSize = 0
        for segment in sent.compactMap(load) {
            if packs.isEmpty || packSize + segment.estimatedUploadSize > maxUploadBytes {
                packs.append([])
                packSize = 0
            }
            packs[packs.count - 1].append(segment)
            packSize += segment.estimatedUploadSize
        }
        let chunks = packs.flatMap { packPayloads($0[...]) }.enumerated().map { index, packed in
            ExternalReplayChunk(payload: packed.payload,
                                metadata: ExternalReplayUploadMetadata(uncompressedSize: packed.uncompressedSize,
                                                                       firstTimestamp: packed.firstTimestamp,
                                                                       lastTimestamp: packed.lastTimestamp,
                                                                       isFirstChunk: isFirstChunk && index == 0,
                                                                       isGZipped: packed.payload.isGzipped))
        }

        for segment in taken {
            if let fileURL = segmentFileURL(segment.fileIndex) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        if segments.isEmpty {
            if let folder = folderURL() {
                try? FileManager.default.removeItem(at: folder)
            }
            if let urlFile = urlFileURL() {
                try? FileManager.default.removeItem(at: urlFile)
            }
            folderSessionId = nil
        } else {
            writeURLFile(isFirstChunk: isFirstChunk && chunks.isEmpty)
        }
        return chunks
    }

    /// Forgets the buffered segments and leaves their files on disk. Events are dropped until the next Meta.
    func reset() {
        segments.removeAll()
        folderSessionId = nil
        nextFileIndex = 0
        hasOpenSegment = false
    }

    // MARK: - Parsing

    private static func parse(_ batch: Data) -> [Event]? {
        guard let ranges = RRWebJSONArraySlicer.elementRanges(in: batch),
              let elements = (try? JSONSerialization.jsonObject(with: batch)) as? [Any],
              elements.count == ranges.count else {
            return nil
        }
        var events: [Event] = []
        events.reserveCapacity(elements.count)
        for (element, range) in zip(elements, ranges) {
            guard let object = element as? [String: Any],
                  let type = number(object["type"]),
                  let timestamp = number(object["timestamp"]),
                  timestampRange.contains(timestamp.doubleValue) else {
                return nil
            }
            events.append(Event(type: type.intValue, timestamp: timestamp.doubleValue, bytes: range))
        }
        return events
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() else {
            return nil
        }
        return number
    }

    // MARK: - Uploads

    private typealias PackedPayload = (payload: Data, uncompressedSize: Int, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval)

    /// Reads a segment's file and gzips it, to estimate its share of an upload.
    private func load(_ segment: Segment) -> TakenSegment? {
        guard let fileURL = segmentFileURL(segment.fileIndex),
              let contents = try? Data(contentsOf: fileURL),
              contents.count > 2, contents.first == UInt8(ascii: "["), contents.last == UInt8(ascii: "]") else {
            NRLOG_AGENT_DEBUG("Failed to read an external session replay segment.")
            return nil
        }
        return TakenSegment(segment: segment, contents: contents, gzipped: Self.gzip(contents))
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

    /// One payload for the pack, halved until each part fits or holds a single segment.
    private func packPayloads(_ pack: ArraySlice<TakenSegment>) -> [PackedPayload] {
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
        return [(payload, raw.count, first.segment.firstTimestamp, last.segment.lastTimestamp)]
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

    private func openSegment(with events: [Event], from batch: Data, sessionId: String) -> Bool {
        if segments.isEmpty {
            folderSessionId = sessionId
            nextFileIndex = 0
        }
        guard let folder = folderURL(), let fileURL = segmentFileURL(nextFileIndex) else {
            return false
        }

        var contents = Data("[".utf8)
        for (index, event) in events.enumerated() {
            if index > 0 {
                contents.append(contentsOf: ",".utf8)
            }
            contents.append(batch[event.bytes])
        }
        contents.append(contentsOf: "]".utf8)

        do {
            try FileManager.default.createDirectory(at: folder,
                                                    withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try contents.write(to: fileURL, options: .atomic)
        } catch {
            NRLOG_AGENT_DEBUG("Failed to write an external session replay segment: \(error)")
            hasOpenSegment = false
            return false
        }

        segments.append(Segment(fileIndex: nextFileIndex,
                                firstTimestamp: events[0].timestamp,
                                lastTimestamp: events[events.count - 1].timestamp,
                                byteCount: contents.count,
                                hasFullSnapshot: events.contains { $0.type == Self.fullSnapshotType }))
        nextFileIndex += 1
        hasOpenSegment = true
        return true
    }

    /// Writes the events over the open segment's closing `]`, then closes it again.
    private func appendToOpenSegment(_ events: [Event], from batch: Data) -> Bool {
        guard var segment = segments.last, let fileURL = segmentFileURL(segment.fileIndex) else {
            return false
        }

        var addition = Data()
        for event in events {
            addition.append(contentsOf: ",".utf8)
            addition.append(batch[event.bytes])
        }
        addition.append(contentsOf: "]".utf8)

        do {
            let handle = try FileHandle(forUpdating: fileURL)
            defer { try? handle.close() }
            let size = try handle.seekToEnd()
            guard size > 0 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            do {
                try handle.seek(toOffset: size - 1)
                try handle.write(contentsOf: addition)
            } catch {
                // Put the closing bracket back, so the file stays one JSON array.
                try? handle.truncate(atOffset: size - 1)
                try? handle.write(contentsOf: Data("]".utf8))
                throw error
            }
            segment.byteCount = Int(size) - 1 + addition.count
        } catch {
            NRLOG_AGENT_DEBUG("Failed to append to an external session replay segment: \(error)")
            hasOpenSegment = false
            return false
        }

        segment.lastTimestamp = events[events.count - 1].timestamp
        segment.hasFullSnapshot = segment.hasFullSnapshot || events.contains { $0.type == Self.fullSnapshotType }
        segments[segments.count - 1] = segment
        return true
    }

    /// Describes everything on disk, so crash recovery can upload it as one payload.
    private func writeURLFile(isFirstChunk: Bool) {
        guard let urlFile = urlFileURL(), let first = segments.first, let last = segments.last else {
            return
        }
        let metadata = ExternalReplayUploadMetadata(uncompressedSize: segments.reduce(0) { $0 + $1.byteCount },
                                                    firstTimestamp: first.firstTimestamp,
                                                    lastTimestamp: last.lastTimestamp,
                                                    isFirstChunk: isFirstChunk,
                                                    isGZipped: true)
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

    private func segmentFileURL(_ index: Int) -> URL? {
        return folderURL()?.appendingPathComponent("frame_\(index).json")
    }

    private func urlFileURL() -> URL? {
        return folderSessionId.map { directory.appendingPathComponent("\($0)_upload_url.txt") }
    }
}

#endif
