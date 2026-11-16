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
    let rrwebVersion: String
}

@available(iOS 13.0, *)
enum ExternalReplayAppendResult: Equatable {
    case appended(kept: Int, droppedBeforeMeta: Int)
    case invalid
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

    private static let metaType = 4
    private static let fullSnapshotType = 2

    private let directory: URL
    private let maxUploadBytes: Int
    private let urlProvider: (ExternalReplayUploadMetadata) -> URL?

    private var segments: [Segment] = []
    private var folderSessionId: String?
    private var nextFileIndex = 0
    private var rrwebVersion = ""

    /// Whether events that don't start a segment are kept. False until the first Meta,
    /// and again after a final take, a reset, or a failed write.
    private(set) var hasOpenSegment = false

    init(directory: URL, maxUploadBytes: Int, urlProvider: @escaping (ExternalReplayUploadMetadata) -> URL?) {
        self.directory = directory
        self.maxUploadBytes = maxUploadBytes
        self.urlProvider = urlProvider
    }

    /// Stores a JSON array of rrweb events. Events that arrive while no segment is open are dropped
    /// until the next Meta. A batch that isn't an array of objects with a numeric `type` and
    /// `timestamp` changes nothing.
    func append(_ batch: Data, rrwebVersion: String, sessionId: String, isFirstChunk: Bool) -> ExternalReplayAppendResult {
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
            self.rrwebVersion = rrwebVersion
            writeURLFile(isFirstChunk: isFirstChunk)
        }
        return .appended(kept: kept, droppedBeforeMeta: droppedBeforeMeta)
    }

    /// Forgets the buffered segments and leaves their files on disk. Events are dropped until the next Meta.
    func reset() {
        segments.removeAll()
        folderSessionId = nil
        nextFileIndex = 0
        rrwebVersion = ""
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
                  let timestamp = number(object["timestamp"]) else {
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
                                                    isGZipped: true,
                                                    rrwebVersion: rrwebVersion)
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
