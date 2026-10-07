//
//  SessionReplayManager.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 3/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

@available(iOS 13.0, *)
@objcMembers
public class SessionReplayManager: NSObject {
    
#if os(iOS) || os(tvOS)
    
    private let sessionReplay: NRMASessionReplay
    private let sessionReplayReporter: SessionReplayReporter
    
    public var harvestPeriod: Int64 = 60
    private var harvestseconds = 0
    private var sessionReplayTimer: DispatchSourceTimer?
    
    private let url: NSString
    
    private let sessionReplayQueue = DispatchQueue(label: "com.newrelic.sessionReplayQueue")
    private static let queueKey = DispatchSpecificKey<String>()
    
    private var isManuallyRecording: Bool = false
    
    
    // TWO SESSION REPLAY MODEs
    public var sessionReplayMode: SessionReplayRecordingMode = .off {
        didSet {
            sessionReplay.recordingMode = sessionReplayMode
        }
    }
    
    @objc public init(reporter: SessionReplayReporter, url: NSString) {
        self.url = url
        self.sessionReplay = NRMASessionReplay(url: self.url)
        self.sessionReplayReporter = reporter
        sessionReplayQueue.setSpecific(key: SessionReplayManager.queueKey, value: "com.newrelic.sessionReplayQueue")
        super.init()
        
        self.sessionReplay.delegate = self
        self.sessionReplayMode = .off
    }
    
    deinit {
        sessionReplayTimer?.cancel()
        sessionReplayTimer = nil
    }
    
    // ERROR MODE
    
    // MARK: - Error Sampling Mode Management
    
    /// Sets the recording mode for session replay
    /// - Parameter mode: The recording mode to use
    @objc public func setRecordingMode(_ mode: SessionReplayRecordingMode) {
        sessionReplayQueue.async { [self] in
            self.sessionReplayMode = mode
            sessionReplay.transistionToRecordingMode(mode)
        }
    }
    
    /// Gets the current recording mode
    /// - Returns: The current recording mode
    @objc public func getCurrentRecordingMode() -> SessionReplayRecordingMode {
        return sessionReplay.recordingMode
    }
    
    /// Transitions from error mode to full mode, including the 15-second buffer
    @objc public func onError(_ error: Error?) {
        sessionReplayQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.sessionReplayMode == .error {
                
                // ensure the buffered data is marked for upload.
                // The current implementation of processFrameToFile writes to disk.
                // If we switch to FULL, subsequent frames will just be written.
                // The currentMode update to .FULL will stop the pruning in processFrameToFile.
                self.sessionReplayMode = .full
                
                NRLOG_AGENT_DEBUG("Error detected - transitioning session replay to full mode")
                sessionReplay.transitionToFullModeOnError()
            }
        }
    }
    
    @objc private func handleErrorNotification(_ notification: Notification) {
        onError(nil)
    }
    // END ERROR MODE
    
    public func start(fromManual: Bool = false, with newMode: SessionReplayRecordingMode) {
        sessionReplayQueue.async { [self] in
            
            
            // SESSION REPLAY ERRORED SESSION SAMPLING HANDLING
            
            self.setRecordingMode(newMode)
            
            // END SESSION REPLAY ERRORED SESSION SAMPLING HANDLING
            
            
            guard !isRunning() else {
                NRLOG_AGENT_DEBUG("Session replay harvest timer attempting to start while already running.")
                return
            }
            
            sessionReplay.start()
            self.harvestseconds = 0
            
            self.isManuallyRecording = fromManual
            
            NRLOG_AGENT_DEBUG("Session replay harvest timer starting with a period of \(harvestPeriod) s")
            let timer = DispatchSource.makeTimerSource(flags: [], queue: sessionReplayQueue)
            timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
            timer.setEventHandler { [weak self] in self?.sessionReplayTick() }
            timer.resume()
            self.sessionReplayTimer = timer
        }
    }
    
    public func stop() {
        let stopBlock = { [self] in
            guard isRunning() else {
                // NRLOG_AGENT_DEBUG("Session replay harvest timer attempting to stop when not running.")
                return
            }
            
            sessionReplay.stop()
            sessionReplayTimer?.cancel()
            sessionReplayTimer = nil
            
           // NRLOG_AGENT_DEBUG("Session replay has shut down and is no longer running.")
        }
        
        // If we're already on the sessionReplayQueue, execute immediately
        // Otherwise, sync to the queue
        if DispatchQueue.getSpecific(key: SessionReplayManager.queueKey) != nil {
            stopBlock()
        } else {
            sessionReplayQueue.sync(execute: stopBlock)
        }
    }
    
    @objc public func isRunning() -> Bool {
        return sessionReplayTimer != nil
    }
    
    // This function is to handle a session change created by a change in userId
    @objc public func endSession(harvest: Bool = true) {
        stop()
        if harvest {
            self.harvest()
        }
        // Reset isManuallyRecording for new session
        isManuallyRecording = false
        
        // Reset the isFirstChunk for new session
        self.sessionReplay.isFirstChunk = true
    }
    
    @objc public func manualRecordReplay() -> Bool {
        return sessionReplayQueue.sync {
            
            if isRunning() {
                NRLOG_AGENT_DEBUG("Attempted to manually start session replay but it is already recording")
                return false
            }
            
            start(fromManual: true, with: .full)
            
            NRLOG_AGENT_DEBUG("Session replay started via manual recordReplay() API")
            return true
        }
    }
    
    @objc public func manualPauseReplay() -> Bool {
        return sessionReplayQueue.sync {
            
            isManuallyRecording = false
            
            if !isRunning() {
                NRLOG_AGENT_DEBUG("Attempted to pause session replay but it is not currently recording")
                return false
            }
            
            stop()
            harvest()
            sessionReplayMode = .off
            NRLOG_AGENT_DEBUG("Session replay paused via manual pauseReplay() API")
            return true
        }
    }
    
    public func isManuallyActive() -> Bool {
        return sessionReplayQueue.sync { isManuallyRecording }
    }
    
    @objc public func clearAllData() {
        sessionReplayQueue.sync { [self] in
            sessionReplay.clearAllData()
        }
    }
    
    @objc func sessionReplayTick() {
        if isRunning() &&
            (NewRelicAgentInternal.sharedInstance() != nil &&
             NewRelicAgentInternal.sharedInstance()?.isSessionReplayEnabled() ?? false == false)
        {
            NRLOG_AGENT_DEBUG("Session replay harvest timer stopping because New Relic agent is not started.")
            stop()
            return
        }
        
        harvestseconds += 1
        sessionReplay.takeFrame()
        
        if harvestseconds >= harvestPeriod {
            harvest()
        }
    }
    
    @objc public func harvest() {
        // sync is required here or session replay upload fails.
        // When called from sessionReplayTick (already on the queue), run inline to avoid deadlock.
        if DispatchQueue.getSpecific(key: SessionReplayManager.queueKey) != nil {
            harvestSessionReplayFramesAndTouches()
        } else {
            sessionReplayQueue.sync { [weak self] in
                self?.harvestSessionReplayFramesAndTouches()
            }
        }
    }
    
    private func harvestSessionReplayFramesAndTouches() {
        
        defer {
            self.harvestseconds = 0
        }
        
        if sessionReplayMode == .off {
            NRLOG_AGENT_DEBUG("Skipping harvest in off mode.")
            return
        }
        
        if sessionReplayMode == .error {
            NRLOG_AGENT_DEBUG("Skipping harvest in ERROR mode.")
            return
        }
        
        let frames = self.sessionReplay.getSessionReplayFrames()

        // A chunk with no frames has no viewport/DOM to establish Meta from, so any
        // touches captured during this window would upload as a touches-only,
        // completely meta-less payload (see NR-601844 -- confirmed via a real repro
        // where a session ended, via a rapid setUserId change, before its first frame
        // had finished capturing). Bail out WITHOUT calling getSessionReplayTouches()
        // -- that call clears the touch capture's buffer as a side effect, so calling
        // it here would silently discard these touches instead of leaving them to be
        // picked up once a frame actually exists, on the next harvest.
        guard !frames.isEmpty else {
            NRLOG_AGENT_DEBUG("No session replay frames to harvest yet; any touches captured so far are left for the next harvest.")
            return
        }

        let touches = self.sessionReplay.getSessionReplayTouches()

        let boxedFrames = frames.map(AnyRRWebEvent.init)
        let boxedTouches = touches.map(AnyRRWebEvent.init)

        let webViewEvents = self.sessionReplay.getSessionReplayWebViewEvents(
            chunkStart: boxedFrames.first?.base.timestamp ?? 0)

        let uploads = buildReplayUploads(frames: boxedFrames, touches: boxedTouches, webViewEvents: webViewEvents)
        guard !uploads.isEmpty else {
            return
        }
        for upload in uploads {
            self.sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
        }

        self.sessionReplay.isFirstChunk = false
    }

    /// Merges and sorts frame/touch events into upload order. Extracted out of
    /// buildReplayUploads() so the real merge+sort logic -- where the "First
    /// event didn't include meta" defect lived -- is directly testable on its
    /// own, without needing a resolvable harvester configuration (required
    /// further down the pipeline to build the actual upload URL).
    ///
    /// `frames` is never empty-first: NRMASessionReplay.getSessionReplayFrames()
    /// always leads with a Meta event (screen size starts at .zero, so the
    /// first real frame always triggers one), and that leading frame is
    /// always followed by a FullSnapshot -- getSessionReplayFrames() resets
    /// its processor's lastFullFrame to nil before processing its first raw
    /// frame, which forces a full snapshot for it. Touches are captured on an
    /// independent timeline (UIApplication event swizzling) and can be
    /// timestamped at or before either of those leading events, so a plain
    /// timestamp sort across both lists could displace either:
    ///   - Meta must be first so the rrweb player can initialize the
    ///     viewport/document (otherwise: "First event didn't include meta").
    ///   - The FullSnapshot right after it establishes the DOM node IDs that
    ///     later incremental/touch events reference, so it can't be sorted
    ///     after a touch either -- confirmed via a real repro where a touch
    ///     sorted ahead of it (raw frames [meta, fullSnapshot, ...] became
    ///     [meta, touch, touch, fullSnapshot, ...] after a naive merge).
    /// So both leading events are anchored at the front, in order; everything
    /// else (the rest of frames + all touches) is sorted normally by
    /// timestamp after them.
    func mergeAndSortReplayEvents(frames: [AnyRRWebEvent], touches: [AnyRRWebEvent]) -> [AnyRRWebEvent] {
        guard let leadingMeta = frames.first else {
            return touches.sorted { (lhs: AnyRRWebEvent, rhs: AnyRRWebEvent) -> Bool in
                lhs.base.timestamp < rhs.base.timestamp
            }
        }

        var leadingEvents = [leadingMeta]
        var rest = Array(frames.dropFirst())
        if let leadingSnapshot = rest.first, leadingSnapshot.base.type == .fullSnapshot {
            leadingEvents.append(leadingSnapshot)
            rest.removeFirst()
        }

        rest.append(contentsOf: touches)
        rest.sort { (lhs: AnyRRWebEvent, rhs: AnyRRWebEvent) -> Bool in
            lhs.base.timestamp < rhs.base.timestamp
        }

        return leadingEvents + rest
    }

    /// Merges/sorts/encodes a chunk from already-boxed events, returning the
    /// resulting uploads (empty if there was nothing to send) -- more than one
    /// when the chunk had to be split to fit the upload size cap. Extracted out
    /// of harvestSessionReplayFramesAndTouches() so the real merge+sort+encode
    /// path is directly testable with synthetic events, without needing to
    /// dispatch (or mock) an actual upload -- this is still the real production
    /// logic, called above with genuinely captured frames/touches.
    func buildReplayUploads(frames: [AnyRRWebEvent], touches: [AnyRRWebEvent], webViewEvents: [WebViewReplayOutputEvent] = []) -> [SessionReplayData] {
        let chunk = mergeReplayChunk(frames: frames, touches: touches, webViewEvents: webViewEvents)
        guard let payloads = encodeReplayChunk(chunk) else {
            return []
        }
        return createReplayUploads(payloads)
    }

    /// Merges WebView events into the native merge order.
    ///
    /// Native events keep exactly the order mergeAndSortReplayEvents() gives them, leading Meta and
    /// FullSnapshot anchored first. WebView events (already in timestamp order) are merged into the
    /// rest by timestamp, after native events at the same ms: a document attached at a native full
    /// snapshot's timestamp must land after the snapshot that builds its `<iframe>`.
    func mergeReplayChunk(frames: [AnyRRWebEvent], touches: [AnyRRWebEvent], webViewEvents: [WebViewReplayOutputEvent]) -> [ReplayChunkEvent] {
        let native = mergeAndSortReplayEvents(frames: frames, touches: touches)
        guard !webViewEvents.isEmpty else {
            return native.map { .native($0) }
        }

        var anchorCount = 0
        if !frames.isEmpty {
            anchorCount = (frames.count > 1 && frames[1].base.type == .fullSnapshot) ? 2 : 1
        }

        var chunk = [ReplayChunkEvent]()
        chunk.reserveCapacity(native.count + webViewEvents.count)
        chunk.append(contentsOf: native.prefix(anchorCount).map { .native($0) })

        let rest = native.dropFirst(anchorCount)
        var nativeIndex = rest.startIndex
        var webViewIndex = webViewEvents.startIndex
        while nativeIndex < rest.endIndex || webViewIndex < webViewEvents.endIndex {
            let takeNative = nativeIndex < rest.endIndex &&
                (webViewIndex >= webViewEvents.endIndex || rest[nativeIndex].base.timestamp <= webViewEvents[webViewIndex].timestamp)
            if takeNative {
                chunk.append(.native(rest[nativeIndex]))
                nativeIndex += 1
            } else {
                chunk.append(.webView(webViewEvents[webViewIndex]))
                webViewIndex += 1
            }
        }
        return chunk
    }

    /// Encodes and gzips a merged chunk into the exact bytes that would be uploaded, split into as
    /// many payloads as it takes to keep each under the upload cap (see ReplayPayloadSplitter).
    /// Native events are JSON-encoded; WebView events are spliced in as already-serialized JSON
    /// rather than re-encoded. Extracted out of buildReplayUploads() so the real encode+gzip+split
    /// path is directly testable without needing a resolvable harvester configuration, which
    /// building the upload URLs (via uploadURL()) separately requires.
    func encodeReplayChunk(_ chunk: [ReplayChunkEvent], limit: Int = Int(kNRMAMaxPayloadSizeLimit)) -> [ReplayPayloadSplitter.Payload]? {
        guard let pieces = replayPayloadPieces(chunk) else {
            return nil
        }

        let result = ReplayPayloadSplitter.split(pieces, limit: limit, compress: Self.gzippedReplayPayload,
                                                 paginate: ReplayEventPaginator.paginate)
        if result.payloads.count > 1 {
            NRLOG_AGENT_DEBUG("Session replay chunk over the \(limit) byte cap; split into \(result.payloads.count) uploads.")
        }
        Self.reportPaginated(result.paginated.count)
        for index in result.dropped {
            if let webViewEvent = chunk[index].webViewEvent {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] WebView event over the \(limit) byte cap could not be broken up; dropped in whole or part. Native replay is preserved.")
                NRMASupportMetricHelper.enqueueWebViewReplayMetric(webViewEvent.graftGroup != nil ? "DocumentShed" : "EventDropped")
            } else {
                NRLOG_AGENT_DEBUG("Session replay event over the \(limit) byte cap could not be broken up; dropped in whole or part.")
                NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("blobs")
            }
        }
        return result.payloads
    }

    /// One splitter piece per chunk event, marking where an upload must not start: between a Meta
    /// and the FullSnapshot laid out against it, and inside a WebView document attachment, whose
    /// backlog means nothing without the graft it replays onto.
    private func replayPayloadPieces(_ chunk: [ReplayChunkEvent]) -> [ReplayPayloadSplitter.Piece]? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        var pieces = [ReplayPayloadSplitter.Piece]()
        pieces.reserveCapacity(chunk.count)
        var graftGroupBounds = [Int: (first: Int, last: Int)]()
        for (index, event) in chunk.enumerated() {
            switch event {
            case .native(let nativeEvent):
                var piece: ReplayPayloadSplitter.Piece
                do {
                    piece = .init(json: try encoder.encode(nativeEvent), timestamp: event.timestamp)
                } catch {
                    NRLOG_AGENT_DEBUG("Failed to encode session replay events to JSON: \(error)")
                    return nil
                }
                if nativeEvent.base.type == .fullSnapshot, index > 0,
                   case .native(let previous) = chunk[index - 1], previous.base.type == .meta {
                    piece.canStartUpload = false
                }
                pieces.append(piece)
            case .webView(let webViewEvent):
                pieces.append(.init(json: webViewEvent.json, timestamp: event.timestamp))
                if let group = webViewEvent.graftGroup {
                    graftGroupBounds[group] = (graftGroupBounds[group]?.first ?? index, index)
                }
            }
        }

        for bounds in graftGroupBounds.values where bounds.last > bounds.first {
            for index in (bounds.first + 1)...bounds.last {
                pieces[index].canStartUpload = false
            }
        }
        return pieces
    }

    private static func reportPaginated(_ count: Int) {
        for _ in 0..<count {
            NRLOG_AGENT_DEBUG("Session replay event over the upload cap on its own; broken into smaller events.")
            NRMASupportMetricHelper.enqueueSessionReplayEventPaginatedMetric()
        }
    }

    /// The bytes to upload for a payload's JSON: gzipped, or the JSON as is if gzip fails.
    private static func gzippedReplayPayload(_ json: Data) -> Data {
        do {
            return try json.gzipped()
        } catch {
            NRLOG_AGENT_DEBUG("Failed to gzip session replay data: \(error.localizedDescription)")
            return json
        }
    }

    private func createReplayUploads(_ payloads: [ReplayPayloadSplitter.Payload]) -> [SessionReplayData] {
        var uploads = [SessionReplayData]()
        for payload in payloads {
            // Construct upload URL. Only the first upload of a split chunk can be the session's first.
            guard let url = sessionReplayReporter.uploadURL(
                uncompressedDataSize: payload.uncompressedSize,
                firstTimestamp: payload.firstTimestamp,
                lastTimestamp: payload.lastTimestamp,
                isFirstChunk: self.sessionReplay.isFirstChunk && uploads.isEmpty,
                isGZipped: payload.data.isGzipped
            ) else {
                NRLOG_AGENT_DEBUG("Failed to construct upload URL for session replay.")
                break
            }
            uploads.append(SessionReplayData(sessionReplayFramesData: payload.data, url: url))
        }
        return uploads
    }
    
    // REPLAY PERSISTENCE
    
    public func checkForPreviousSessionFiles() {
        sessionReplayQueue.async { [self] in
            // CHECK FOR MSR DIRECTORIES FROM PREVIOUSLY CRASHED SESSIONS
            NRLOG_AGENT_DEBUG("CHECK FOR MSR DIRECTORIES FROM PREVIOUSLY CRASHED SESSIONS")
            
            guard let sessionReplayDirectory = getSessionReplayDirectory() else {
                NRLOG_AGENT_DEBUG("Could not access session replay directory")
                return
            }
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: sessionReplayDirectory, includingPropertiesForKeys: nil)
                
                // Extract unique session IDs from session replay files
                let sessionIds = Set(fileURLs.compactMap { fileURL -> String? in
                    let fileName = fileURL.lastPathComponent
                    if fileName.hasSuffix("_upload_url.txt") {
                        return fileName.replacingOccurrences(of: "_upload_url.txt", with: "")
                    }
                    return nil
                })
                NRLOG_AGENT_DEBUG("MSR DIRECTORIES FOUND \(sessionIds)")
                
                // Process each session
                for sessionId in sessionIds {
                    processSessionReplayFile(sessionId: sessionId, directory: sessionReplayDirectory)
                }
                
            }
            catch {
                NRLOG_AGENT_DEBUG("Failed to read session replay directory: \(error)")
            }
        }
    }
    
    private func processSessionReplayFile(sessionId: String, directory: URL) {
        let urlFile = directory.appendingPathComponent("\(sessionId)_upload_url.txt")
        
        do {
            NRLOG_AGENT_DEBUG("Processing session replay for session ID: \(sessionId)")
            
            // BEGIN URL CONSTRUCTION
            
            guard let urlString = try? String(contentsOf: urlFile),
                  let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                NRLOG_AGENT_DEBUG("No valid URL found for session replay file with session ID: \(sessionId)")
                return
            }
            //NRLOG_AGENT_DEBUG(url.absoluteString)
            
            // END URL CONSTRUCTION
            
            // BEGIN DATA CONSTRUCTION
            
            // Find all frame files for this session
            let sessionDirectory = directory.appendingPathComponent(sessionId)
            guard FileManager.default.fileExists(atPath: sessionDirectory.path) else {
                NRLOG_AGENT_DEBUG("Session directory not found for session ID: \(sessionId)")
                return
            }
            
            let pieces = try persistedReplayPieces(sessionDirectory: sessionDirectory)
            
            if pieces.isEmpty {
                NRLOG_AGENT_DEBUG("No full snapshot frame found for session ID: \(sessionId)")
                try FileManager.default.removeItem(at: sessionDirectory)
                try? FileManager.default.removeItem(at: urlFile)
                return
            }
            
            // END DATA CONSTRUCTION
            
            let uploads = persistedReplayUploads(pieces: pieces, persistedURL: url)
            for upload in uploads {
                sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            }
            NRLOG_AGENT_DEBUG("Enqueued \(uploads.count) previous session replay upload(s) for session ID: \(sessionId)")
            
            // Remove processed files
            try FileManager.default.removeItem(at: sessionDirectory)
            try? FileManager.default.removeItem(at: urlFile)
            
        } catch {
            NRLOG_AGENT_DEBUG("Failed to process session replay file for session ID \(sessionId): \(error)")
        }
    }
    
    /// Reads a persisted session's frame files, in order, starting from the first one holding a full
    /// snapshot (nothing before it can be replayed). Each frame file becomes one splitter piece: its
    /// events exactly as written, without the enclosing brackets, so a split persisted session is
    /// only ever cut between captured frames, and nothing is decoded and re-encoded.
    func persistedReplayPieces(sessionDirectory: URL) throws -> [ReplayPayloadSplitter.Piece] {
        let frameFiles = try FileManager.default.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("frame_") }
            .sorted { (url1, url2) -> Bool in
                let name1 = url1.deletingPathExtension().lastPathComponent
                let name2 = url2.deletingPathExtension().lastPathComponent
                
                let number1 = Int(name1.replacingOccurrences(of: "frame_", with: "")) ?? 0
                let number2 = Int(name2.replacingOccurrences(of: "frame_", with: "")) ?? 0
                
                return number1 < number2
            }
        
        let decoder = JSONDecoder()
        var pieces = [ReplayPayloadSplitter.Piece]()
        var foundFirstFullFrame = false
        
        for frameFile in frameFiles {
            do {
                let frameContent = try Data(contentsOf: frameFile)
                // Decoding the headers also validates the file: a frame cut short by the crash would
                // otherwise make the whole upload it lands in unreadable.
                let events = try decoder.decode([PersistedReplayEventHeader].self, from: frameContent)
                guard let firstEvent = events.first, let lastEvent = events.last,
                      let elements = Self.jsonArrayElements(frameContent) else {
                    continue
                }
                
                if !foundFirstFullFrame {
                    guard events.contains(where: { $0.type == RRWebEventType.fullSnapshot.rawValue }) else {
                        NRLOG_AGENT_DEBUG("Skipping frame file \(frameFile.lastPathComponent) - no full snapshot found yet")
                        continue
                    }
                    foundFirstFullFrame = true
                }
                
                pieces.append(.init(json: elements, firstTimestamp: firstEvent.timestamp, lastTimestamp: lastEvent.timestamp))
            } catch {
                NRLOG_AGENT_DEBUG("Skipping unreadable frame file \(frameFile.lastPathComponent): \(error)")
            }
        }
        return pieces
    }
    
    /// Uploads for a persisted session: split to fit the upload cap like a live harvest, each sent to
    /// the persisted URL with its own size and timestamps. Only the first can be the session's first.
    func persistedReplayUploads(pieces: [ReplayPayloadSplitter.Piece], persistedURL: URL, limit: Int = Int(kNRMAMaxPayloadSizeLimit)) -> [SessionReplayData] {
        let result = ReplayPayloadSplitter.split(pieces, limit: limit, compress: Self.gzippedReplayPayload,
                                                 paginate: ReplayEventPaginator.paginate)
        if result.payloads.count > 1 {
            NRLOG_AGENT_DEBUG("Previous session replay over the \(limit) byte cap; split into \(result.payloads.count) uploads.")
        }
        Self.reportPaginated(result.paginated.count)
        for _ in result.dropped {
            NRLOG_AGENT_DEBUG("Previous session replay frame over the \(limit) byte cap could not be broken up; dropped in whole or part.")
            NRMASupportMetricHelper.enqueueMaxPayloadSizeLimitMetric("blobs")
        }
        
        let isFirstChunk = SessionReplayReporter.replayAttribute("isFirstChunk", of: persistedURL) == String(true)
        var uploads = [SessionReplayData]()
        for payload in result.payloads {
            var attributes = [
                "isFirstChunk": String(isFirstChunk && uploads.isEmpty),
                "decompressedBytes": String(payload.uncompressedSize),
                "replay.firstTimestamp": String(Int(payload.firstTimestamp)),
                "replay.lastTimestamp": String(Int(payload.lastTimestamp))
            ]
            var removed = Set<String>()
            if payload.data.isGzipped {
                attributes["content_encoding"] = "gzip"
            } else {
                removed.insert("content_encoding")
            }
            guard let url = SessionReplayReporter.rewritingReplayAttributes(of: persistedURL, setting: attributes, removing: removed) else {
                NRLOG_AGENT_DEBUG("Failed to construct upload URL for previous session replay.")
                break
            }
            uploads.append(SessionReplayData(sessionReplayFramesData: payload.data, url: url))
        }
        return uploads
    }
    
    /// The elements of a serialized JSON array, without its brackets.
    private static func jsonArrayElements(_ json: Data) -> Data? {
        let isWhitespace = { (byte: UInt8) in byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 }
        guard let first = json.firstIndex(where: { !isWhitespace($0) }),
              let last = json.lastIndex(where: { !isWhitespace($0) }),
              first < last, json[first] == UInt8(ascii: "["), json[last] == UInt8(ascii: "]") else {
            return nil
        }
        let elements = json[json.index(after: first)..<last]
        return elements.contains(where: { !isWhitespace($0) }) ? Data(elements) : nil
    }
    
    private func getSessionReplayDirectory() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(kNRMA_SessionReplayFrames_folder)
    }
    
#endif
}

#if os(iOS) || os(tvOS)

@available(iOS 13.0, *)
extension SessionReplayManager: NRMASessionReplayDelegate {
    public func generateUploadURL(
        uncompressedDataSize: Int,
        firstTimestamp: TimeInterval,
        lastTimestamp: TimeInterval,
        isFirstChunk: Bool,
        isGZipped: Bool
    ) -> URL? {
        return self.sessionReplayReporter.uploadURL(uncompressedDataSize: uncompressedDataSize, firstTimestamp: firstTimestamp, lastTimestamp: lastTimestamp, isFirstChunk: isFirstChunk, isGZipped: isGZipped)
    }
}
#endif

/// The fields of a persisted replay event that crash recovery needs to place it (see persistedReplayPieces).
struct PersistedReplayEventHeader: Decodable {
    let type: Int
    let timestamp: TimeInterval
}

/// Splits one chunk's events into as many uploads as it takes to keep each under the upload cap.
///
/// The reporter drops an over-cap upload whole, so an oversized chunk would otherwise lose every event
/// in it. A session's uploads are replayed in order, so cutting a chunk loses nothing as long as order is
/// kept: an over-cap range is cut in two near its byte midpoint and each half is tried again, until every
/// range fits. A piece over the cap on its own is handed to `paginate` to be broken into smaller ones
/// (see ReplayEventPaginator), and dropped only if it can't be.
enum ReplayPayloadSplitter {

    struct Piece {
        /// One or more serialized events, comma-separated, without the enclosing array brackets.
        let json: Data
        let firstTimestamp: TimeInterval
        let lastTimestamp: TimeInterval
        /// False when this piece depends on the one before it, so an upload must not start here.
        /// Honored when there is any other place to cut.
        var canStartUpload = true

        init(json: Data, firstTimestamp: TimeInterval, lastTimestamp: TimeInterval, canStartUpload: Bool = true) {
            self.json = json
            self.firstTimestamp = firstTimestamp
            self.lastTimestamp = lastTimestamp
            self.canStartUpload = canStartUpload
        }

        init(json: Data, timestamp: TimeInterval, canStartUpload: Bool = true) {
            self.init(json: json, firstTimestamp: timestamp, lastTimestamp: timestamp, canStartUpload: canStartUpload)
        }
    }

    struct Payload {
        /// The bytes to upload: `compress`'s output for the payload's JSON array.
        let data: Data
        /// The size of the JSON array before compression.
        let uncompressedSize: Int
        let firstTimestamp: TimeInterval
        let lastTimestamp: TimeInterval
    }

    struct Result {
        /// In replay order.
        var payloads = [Payload]()
        /// Pieces over the cap on their own that were broken into smaller ones.
        var paginated = [Int]()
        /// Pieces over the cap on their own that were dropped, in whole or (if paginated) in part.
        var dropped = [Int]()
    }

    /// - Parameters:
    ///   - limit: the size cap the reporter enforces, applied to `compress`'s output
    ///   - compress: the bytes to upload for a payload's JSON array
    ///   - paginate: breaks a piece that is over the cap on its own into smaller pieces that replay to
    ///     the same result, each aiming at the given uncompressed size; nil if it can't be broken up
    static func split(_ pieces: [Piece], limit: Int, compress: (Data) -> Data,
                      paginate: (Piece, Int) -> [Piece]? = { _, _ in nil }) -> Result {
        // offsets[i] is where pieces[i] starts in the pieces' concatenated JSON.
        var offsets = [Int]()
        offsets.reserveCapacity(pieces.count + 1)
        offsets.append(0)
        for piece in pieces {
            offsets.append(offsets[offsets.count - 1] + piece.json.count)
        }

        var result = Result()
        func process(_ range: Range<Int>) {
            guard !range.isEmpty else { return }
            let json = joinedJSON(pieces[range])
            let data = compress(json)
            if data.count <= limit {
                result.payloads.append(Payload(data: data,
                                               uncompressedSize: json.count,
                                               firstTimestamp: pieces[range.lowerBound].firstTimestamp,
                                               lastTimestamp: pieces[range.upperBound - 1].lastTimestamp))
                return
            }
            guard range.count > 1 else {
                let index = range.lowerBound
                // Aim each part at half the cap, by this piece's own compression ratio.
                let partSize = max(1, Int(Double(json.count) * Double(limit) / Double(data.count) / 2))
                guard let parts = paginate(pieces[index], partSize), parts.count > 1 else {
                    result.dropped.append(index)
                    return
                }
                let paginated = split(parts, limit: limit, compress: compress, paginate: paginate)
                result.payloads.append(contentsOf: paginated.payloads)
                result.paginated.append(index)
                if !paginated.dropped.isEmpty {
                    result.dropped.append(index)
                }
                return
            }
            let cut = cutIndex(range, pieces: pieces, offsets: offsets)
            process(range.lowerBound..<cut)
            process(cut..<range.upperBound)
        }
        process(0..<pieces.count)
        return result
    }

    /// Where to cut `range` in two: the place nearest its byte midpoint where an upload may start, or
    /// the place nearest its byte midpoint if there is none. Cutting by bytes rather than by count
    /// matters because one full snapshot can outweigh every other event in the chunk.
    private static func cutIndex(_ range: Range<Int>, pieces: [Piece], offsets: [Int]) -> Int {
        let midpoint = (offsets[range.lowerBound] + offsets[range.upperBound]) / 2
        var nearest = range.lowerBound + 1
        var nearestAllowed: Int?
        for index in (range.lowerBound + 1)..<range.upperBound {
            let distance = abs(offsets[index] - midpoint)
            if distance < abs(offsets[nearest] - midpoint) {
                nearest = index
            }
            if pieces[index].canStartUpload, nearestAllowed.map({ distance < abs(offsets[$0] - midpoint) }) ?? true {
                nearestAllowed = index
            }
        }
        return nearestAllowed ?? nearest
    }

    static func joinedJSON<Pieces: Collection>(_ pieces: Pieces) -> Data where Pieces.Element == Piece {
        var data = Data()
        data.reserveCapacity(pieces.reduce(2) { $0 + $1.json.count + 1 })
        data.append(UInt8(ascii: "["))
        for (index, piece) in pieces.enumerated() {
            if index > 0 {
                data.append(UInt8(ascii: ","))
            }
            data.append(piece.json)
        }
        data.append(UInt8(ascii: "]"))
        return data
    }
}

/// Breaks one piece that is over the upload cap on its own into smaller pieces that replay to the same
/// result, so the splitter can spread it over several uploads instead of dropping it.
///
/// - A piece of several events (a persisted frame file) is cut into its events, byte for byte.
/// - A FullSnapshot keeps its document's spine and is followed by IncrementalSnapshot mutations, at the
///   same timestamp, adding back the subtrees taken out of it.
/// - A mutation's added subtrees are broken up the same way and spread over several mutations.
///
/// A subtree taken out goes back in front of its next sibling, which is always in place by then, so
/// document order is kept. The document and `<html>` keep their children, so the player's document
/// stays well formed. A single node that carries most of the bytes (one huge text node, say) can't
/// be broken up, and the splitter drops it.
enum ReplayEventPaginator {

    /// - Parameter partSize: the uncompressed size each part should aim at
    /// - Returns: the parts in replay order, or nil if the piece can't be broken up
    static func paginate(_ piece: ReplayPayloadSplitter.Piece, partSize: Int) -> [ReplayPayloadSplitter.Piece]? {
        var array = Data("[".utf8)
        array.append(piece.json)
        array.append(UInt8(ascii: "]"))
        guard let events = (try? JSONSerialization.jsonObject(with: array)) as? [[String: Any]], !events.isEmpty else {
            return nil
        }

        if events.count > 1 {
            let elements = topLevelElements(of: piece.json)
            guard elements.count == events.count else {
                return nil
            }
            return zip(events, elements).enumerated().map { index, pair -> ReplayPayloadSplitter.Piece in
                let followsMeta = index > 0 && eventType(events[index - 1]) == RRWebEventType.meta.rawValue
                return .init(json: pair.1,
                             timestamp: timestamp(of: pair.0) ?? piece.firstTimestamp,
                             canStartUpload: index == 0 ? piece.canStartUpload
                                                        : !(followsMeta && eventType(pair.0) == RRWebEventType.fullSnapshot.rawValue))
            }
        }

        let event = events[0]
        let parts: [[String: Any]]?
        switch eventType(event) {
        case RRWebEventType.fullSnapshot.rawValue:
            parts = paginateFullSnapshot(event, partSize: partSize)
        case RRWebEventType.incrementalSnapshot.rawValue:
            parts = paginateMutation(event, partSize: partSize)
        default:
            parts = nil
        }
        guard let parts = parts, parts.count > 1 else {
            return nil
        }

        var pieces = [ReplayPayloadSplitter.Piece]()
        pieces.reserveCapacity(parts.count)
        for (index, part) in parts.enumerated() {
            guard let json = serialized(part) else {
                return nil
            }
            pieces.append(.init(json: json, timestamp: timestamp(of: part) ?? piece.firstTimestamp,
                                canStartUpload: index == 0 ? piece.canStartUpload : true))
        }
        return pieces
    }

    // MARK: - Events

    private static func paginateFullSnapshot(_ event: [String: Any], partSize: Int) -> [[String: Any]]? {
        guard var data = event["data"] as? [String: Any],
              let root = data["node"] as? [String: Any],
              let flattened = flatten(root, partSize: partSize),
              !flattened.adds.isEmpty,
              let batches = batched(flattened.adds, partSize: partSize) else {
            return nil
        }

        data["node"] = flattened.node
        var snapshot = event
        snapshot["data"] = data
        return [snapshot] + batches.map { batch in
            mutation(at: event["timestamp"], adds: batch, removes: [], texts: [], attributes: [])
        }
    }

    private static func paginateMutation(_ event: [String: Any], partSize: Int) -> [[String: Any]]? {
        guard let data = event["data"] as? [String: Any],
              data["source"] as? Int == RRWebIncrementalSource.mutation.rawValue,
              let adds = data["adds"] as? [[String: Any]], !adds.isEmpty else {
            return nil
        }

        var expanded = [[String: Any]]()
        for add in dependencyOrdered(adds) {
            guard let node = add["node"] as? [String: Any], let flattened = flatten(node, partSize: partSize) else {
                return nil
            }
            var kept = add
            kept["node"] = flattened.node
            expanded.append(kept)
            expanded.append(contentsOf: flattened.adds)
        }
        guard let batches = batched(expanded, partSize: partSize), batches.count > 1 else {
            return nil
        }

        // The player applies a mutation's removes before its adds, and its texts and attributes after
        // them, so those go with the first and last batches.
        return batches.enumerated().map { index, batch in
            var part = event
            var partData = data
            partData["adds"] = batch
            partData["removes"] = index == 0 ? (data["removes"] ?? []) : []
            partData["texts"] = index == batches.count - 1 ? (data["texts"] ?? []) : []
            partData["attributes"] = index == batches.count - 1 ? (data["attributes"] ?? []) : []
            part["data"] = partData
            return part
        }
    }

    private static func mutation(at timestamp: Any?, adds: [[String: Any]], removes: [Any], texts: [Any], attributes: [Any]) -> [String: Any] {
        return ["type": RRWebEventType.incrementalSnapshot.rawValue,
                "timestamp": timestamp ?? 0,
                "data": ["source": RRWebIncrementalSource.mutation.rawValue,
                         "adds": adds, "removes": removes, "texts": texts, "attributes": attributes]]
    }

    // MARK: - Nodes

    private struct Flattened {
        /// The node with the children it keeps.
        let node: [String: Any]
        /// Its serialized size with those children.
        let size: Int
        /// Adds putting back what was taken out of it, in an order the player can apply.
        let adds: [[String: Any]]
    }

    /// Takes the largest subtrees out of `node` until what's left is within `partSize`. A child that
    /// is itself too big stays, with its own largest subtrees taken out of it in turn.
    private static func flatten(_ node: [String: Any], partSize: Int) -> Flattened? {
        var shallow = node
        let children = shallow.removeValue(forKey: "childNodes") as? [[String: Any]] ?? []
        guard let shallowSize = serialized(shallow)?.count else {
            return nil
        }
        guard !children.isEmpty else {
            return Flattened(node: node, size: shallowSize, adds: [])
        }

        var results = [Flattened]()
        results.reserveCapacity(children.count)
        for child in children {
            guard let result = flatten(child, partSize: partSize) else {
                return nil
            }
            results.append(result)
        }

        // + `,"childNodes":[]` and the commas between children
        var size = shallowSize + 15 + results.reduce(0) { $0 + $1.size + 1 }
        var takenOut = Set<Int>()
        if size > partSize && !keepsChildren(node) {
            for index in results.indices.sorted(by: { results[$0].size > results[$1].size }) where size > partSize {
                takenOut.insert(index)
                size -= results[index].size + 1
            }
        }

        var adds = [[String: Any]]()
        let nodeId = node["id"] ?? NSNull()
        // Last first, so each one's next sibling is already back in place.
        for index in results.indices.reversed() where takenOut.contains(index) {
            let nextId = index + 1 < children.count ? (children[index + 1]["id"] ?? NSNull()) : NSNull()
            adds.append(["parentId": nodeId, "nextId": nextId, "node": results[index].node])
            adds.append(contentsOf: results[index].adds)
        }
        for index in results.indices where !takenOut.contains(index) {
            adds.append(contentsOf: results[index].adds)
        }

        shallow["childNodes"] = results.indices.filter { !takenOut.contains($0) }.map { results[$0].node }
        return Flattened(node: shallow, size: size, adds: adds)
    }

    /// The document and `<html>` keep their children: the player builds a document's structure itself
    /// and doesn't expect it to arrive piecemeal.
    private static func keepsChildren(_ node: [String: Any]) -> Bool {
        return node["type"] as? Int == SerializedNodeType.document.rawValue ||
            (node["type"] as? Int == SerializedNodeType.element.rawValue && node["tagName"] as? String == TagType.html.rawValue)
    }

    /// `adds` reordered, as little as possible, so none comes before an add that puts in its parent or
    /// next sibling. The player resolves that order itself within one mutation, but not across mutations.
    private static func dependencyOrdered(_ adds: [[String: Any]]) -> [[String: Any]] {
        var addIndexById = [Int: Int]()
        func register(_ node: [String: Any], for index: Int) {
            if let id = node["id"] as? Int {
                addIndexById[id] = index
            }
            for child in node["childNodes"] as? [[String: Any]] ?? [] {
                register(child, for: index)
            }
        }
        for (index, add) in adds.enumerated() {
            if let node = add["node"] as? [String: Any] {
                register(node, for: index)
            }
        }

        let dependencies = adds.enumerated().map { index, add -> [Int] in
            [add["parentId"] as? Int, add["nextId"] as? Int].compactMap { id in
                id.flatMap { addIndexById[$0] }.flatMap { $0 == index ? nil : $0 }
            }
        }
        guard dependencies.contains(where: { !$0.isEmpty }) else {
            return adds
        }

        var placed = [Bool](repeating: false, count: adds.count)
        var ordered = [[String: Any]]()
        ordered.reserveCapacity(adds.count)
        var progressed = true
        while ordered.count < adds.count && progressed {
            progressed = false
            for index in adds.indices where !placed[index] && dependencies[index].allSatisfy({ placed[$0] }) {
                placed[index] = true
                ordered.append(adds[index])
                progressed = true
            }
        }
        // A cycle can't be ordered; leave the rest as it was.
        ordered.append(contentsOf: adds.indices.filter { !placed[$0] }.map { adds[$0] })
        return ordered
    }

    /// Consecutive runs of `adds`, each within `partSize` unless a single add is bigger.
    private static func batched(_ adds: [[String: Any]], partSize: Int) -> [[[String: Any]]]? {
        var batches = [[[String: Any]]]()
        var batch = [[String: Any]]()
        var batchSize = 0
        for add in adds {
            guard let size = serialized(add)?.count else {
                return nil
            }
            if !batch.isEmpty && batchSize + size + 1 > partSize {
                batches.append(batch)
                batch = []
                batchSize = 0
            }
            batch.append(add)
            batchSize += size + 1
        }
        if !batch.isEmpty {
            batches.append(batch)
        }
        return batches
    }

    // MARK: - JSON

    private static func serialized(_ object: Any) -> Data? {
        return try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
    }

    private static func eventType(_ event: [String: Any]) -> Int? {
        return event["type"] as? Int
    }

    private static func timestamp(of event: [String: Any]) -> TimeInterval? {
        return (event["timestamp"] as? NSNumber)?.doubleValue
    }

    /// The bytes of each element of a JSON array's contents (`json` without its brackets), as written.
    static func topLevelElements(of json: Data) -> [Data] {
        var elements = [Data]()
        var depth = 0
        var inString = false
        var escaped = false
        var start = json.startIndex
        for index in json.indices {
            let byte = json[index]
            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                depth -= 1
            case UInt8(ascii: ",") where depth == 0:
                elements.append(trimmed(json[start..<index]))
                start = json.index(after: index)
            default:
                break
            }
        }
        elements.append(trimmed(json[start..<json.endIndex]))
        return elements.filter { !$0.isEmpty }
    }

    private static func trimmed(_ bytes: Data) -> Data {
        let isWhitespace = { (byte: UInt8) in byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 }
        guard let first = bytes.firstIndex(where: { !isWhitespace($0) }),
              let last = bytes.lastIndex(where: { !isWhitespace($0) }) else {
            return Data()
        }
        return Data(bytes[first...last])
    }
}
