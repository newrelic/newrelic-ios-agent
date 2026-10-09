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

    /// When true, an external source (e.g. the New Relic Flutter agent) supplies
    /// session-replay frames via `recordSessionReplayEvents`, so the native
    /// capture loop must NOT run — otherwise it records the opaque host view
    /// (e.g. `FlutterView`) as blank frames that pollute the replay. Ingest and
    /// upload stay active. Setting this true while native capture is already
    /// running tears the capture loop down.
    @objc public var externalCaptureSource: Bool = false {
        didSet {
            guard oldValue != externalCaptureSource else { return }
            if externalCaptureSource {
                if isRunning() {
                    NRLOG_AGENT_DEBUG("Session replay: external capture source enabled — stopping native capture.")
                    // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge):
                    // upload native's segment now so it lands before the external
                    // source's next chunk. Only when native was resumed by the toggle,
                    // so the initial suppression at startAgent behaves as before.
                    if resumedByExternalToggle {
                        NSLog("🧪[HYBRID-POC] externalCaptureSource=true — harvesting native segment, then stopping")
                        harvest()
                    }
                    stop()
                }
                resumedByExternalToggle = false
            } else {
                // TEST-ONLY (Option C PoC): the caller
                // (NewRelicAgentInternal.setSessionReplayExternalCaptureSource:)
                // restarts native capture in the config-derived mode — this
                // manager's sessionReplayMode stays .off until the first harvest
                // connect, so it can't be used here.
                resumedByExternalToggle = true
            }
        }
    }

    // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge).
    private var resumedByExternalToggle = false
    
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

            // POC (2026-10-08): upload the external (e.g. Flutter) error-mode buffer.
            // Keyed off our own flag, not sessionReplayMode, which can stay .off for
            // external sources (native capture never starts).
            if !self.externalErrorTriggered {
                self.externalErrorTriggered = true
                self.flushExternalErrorBuffer()
            }

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

            // Ingest-only: an external source (e.g. Flutter) provides frames, so
            // skip the native capture engine + timer. The recording mode is still
            // set above, and `recordSessionReplayEvents` ingest/upload is unaffected.
            // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge):
            // NSLog bypasses the agent's own log-level gating, so it stays visible
            // even when NRLOG_AGENT_DEBUG output is throttled (e.g. after repeated
            // relaunches against staging).
            NSLog("🧪[HYBRID-POC] start(fromManual:\(fromManual), mode:\(newMode)) — externalCaptureSource=\(externalCaptureSource) isRunning=\(isRunning())")

            guard !externalCaptureSource else {
                NRLOG_AGENT_DEBUG("Session replay: external capture source active — skipping native capture (ingest-only).")
                NSLog("🧪[HYBRID-POC] start() returning early — externalCaptureSource still true")
                return
            }

            guard !isRunning() else {
                NRLOG_AGENT_DEBUG("Session replay harvest timer attempting to start while already running.")
                NSLog("🧪[HYBRID-POC] start() returning early — already running")
                return
            }

            NSLog("🧪[HYBRID-POC] start() proceeding — native capture timer about to start")
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

        // POC: the external error-mode buffer belongs to the old session. Clear its disk
        // copy now, while currentSessionId() still names the old session.
        if !externalBuffer.isEmpty { clearPersistedExternalBuffer() }
        sessionReplayQueue.async { [weak self] in
            self?.externalBuffer.removeAll()
            self?.externalErrorTriggered = false
        }
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
        // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge).
        NSLog("🧪[HYBRID-POC] sessionReplayTick #\(harvestseconds) — took a native frame")

        if harvestseconds == harvestPeriod {
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
        // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge).
        NSLog("🧪[HYBRID-POC] harvestSessionReplayFramesAndTouches() entered — mode=\(sessionReplayMode)")

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

        guard let upload = buildReplayUpload(frames: boxedFrames, touches: boxedTouches) else {
            return
        }
        // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge).
        NSLog("🧪[HYBRID-POC] NATIVE-OWN-CAPTURE upload enqueued — frames=\(boxedFrames.count) touches=\(boxedTouches.count) isFirstChunk=\(self.sessionReplay.isFirstChunk)")
        self.sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)

        self.sessionReplay.isFirstChunk = false
    }

    /// Merges and sorts frame/touch events into upload order. Extracted out of
    /// buildReplayUpload() so the real merge+sort logic -- where the "First
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
    /// resulting upload (or nil if there was nothing to send). Extracted out of
    /// harvestSessionReplayFramesAndTouches() so the real merge+sort+encode path
    /// is directly testable with synthetic events, without needing to dispatch
    /// (or mock) an actual upload -- this is still the real production logic,
    /// called above with genuinely captured frames/touches.
    func buildReplayUpload(frames: [AnyRRWebEvent], touches: [AnyRRWebEvent]) -> SessionReplayData? {
        let container = mergeAndSortReplayEvents(frames: frames, touches: touches)

        let firstTimestamp = TimeInterval(container.first?.base.timestamp ?? 0)
        let lastTimestamp  = TimeInterval(container.last?.base.timestamp ?? 0)

        return self.createReplayUpload(container: container,
                                        firstTimestamp: firstTimestamp,
                                        lastTimestamp: lastTimestamp)
    }

    /// Encodes and gzips a merged/sorted event container to the exact bytes
    /// that would be uploaded, plus the pre-gzip size (needed for the upload
    /// URL's metadata). Extracted out of createReplayUpload() so the real
    /// encode+gzip path is directly testable without needing a resolvable
    /// harvester configuration, which createReplayUpload() separately
    /// requires (via uploadURL()) to build the final upload URL.
    func encodeReplayPayload(container: [AnyRRWebEvent]) -> (data: Data, uncompressedSize: Int)? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes

        let jsonData: Data
        do {
            jsonData = try encoder.encode(container)
        } catch {
            NRLOG_AGENT_DEBUG("Failed to encode session replay events to JSON: \(error)")
            return nil
        }

        return compressReplayPayload(jsonData)
    }

    /// Gzips an already-serialized rrweb-event JSON payload, returning the bytes
    /// to upload plus the pre-gzip size. Shared by native-captured frames and
    /// externally-supplied events; falls back to the uncompressed bytes if gzip
    /// fails.
    func compressReplayPayload(_ jsonData: Data) -> (data: Data, uncompressedSize: Int) {
        let uncompressedDataSize = jsonData.count

        var payload = jsonData
        do {
            payload = try jsonData.gzipped()
        } catch {
            NRLOG_AGENT_DEBUG("Failed to gzip session replay data: \(error.localizedDescription)")
        }

        return (payload, uncompressedDataSize)
    }

    private func createReplayUpload(container: [AnyRRWebEvent], firstTimestamp: TimeInterval, lastTimestamp: TimeInterval) -> SessionReplayData? {
        guard let (jsonData, uncompressedDataSize) = encodeReplayPayload(container: container) else {
            return nil
        }

        return buildUpload(payload: jsonData,
                           uncompressedDataSize: uncompressedDataSize,
                           firstTimestamp: firstTimestamp,
                           lastTimestamp: lastTimestamp,
                           isFirstChunk: self.sessionReplay.isFirstChunk)
    }

    /// Shared upload tail: build the upload URL via the reporter and wrap an
    /// already-encoded payload in SessionReplayData. Reused by both
    /// native-captured frames and externally-supplied events.
    private func buildUpload(payload: Data,
                             uncompressedDataSize: Int,
                             firstTimestamp: TimeInterval,
                             lastTimestamp: TimeInterval,
                             isFirstChunk: Bool) -> SessionReplayData? {
        guard let url = sessionReplayReporter.uploadURL(
            uncompressedDataSize: uncompressedDataSize,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            isFirstChunk: isFirstChunk,
            isGZipped: payload.isGzipped
        ) else {
            NRLOG_AGENT_DEBUG("Failed to construct upload URL for session replay.")
            return nil
        }

        return SessionReplayData(sessionReplayFramesData: payload, url: url)
    }

    /// Ingests already-serialized rrweb events produced off-agent (e.g. by the
    /// New Relic Flutter agent) into the existing native uploader. `eventsJSON`
    /// must be a JSON array of rrweb events. Skipped when the recording mode is
    /// off. The gzip + enqueue happen asynchronously so the caller's thread is
    /// never blocked.
    /// - Returns: true if the batch was accepted for processing.
    @objc public func recordSessionReplayEvents(_ eventsJSON: String) -> Bool {
        return recordSessionReplayEvents(eventsJSON, bufferForErrorMode: false)
    }

    // MARK: - POC (2026-10-08): native error buffer for external rrweb. Not reviewed.
    // Parallel to rawFrames (which holds native view-tree frames): a rolling window
    // of already-serialized rrweb events, uploaded once on error. In memory only —
    // no crash persistence yet.

    private var externalBuffer: [[String: Any]] = []
    private var externalErrorTriggered = false
    private let externalBufferWindowMs: Double = 15_000
    private let externalBufferMaxEvents = 20_000
    private static let rrwebTypeMeta = 4

    /// Drops events older than the window, but keeps the slice starting at the last
    /// Meta at or before the cutoff so the buffered slice is always renderable.
    private func pruneExternalBuffer(nowMs: Double) {
        let cutoff = nowMs - externalBufferWindowMs
        var start: Int? = nil
        for (i, event) in externalBuffer.enumerated() {
            let ts = (event["timestamp"] as? NSNumber)?.doubleValue ?? .greatestFiniteMagnitude
            if (event["type"] as? NSNumber)?.intValue == SessionReplayManager.rrwebTypeMeta && ts <= cutoff {
                start = i
            }
            if ts > cutoff { break }
        }
        if let start = start, start > 0 {
            externalBuffer.removeFirst(start)
        }
        if externalBuffer.count > externalBufferMaxEvents {
            externalBuffer.removeFirst(externalBuffer.count - externalBufferMaxEvents)
        }
    }

    // Crash persistence: the buffer is mirrored to disk in the same layout the native
    // error buffer uses (<frames>/<sessionId>/frame_N.json + <sessionId>_upload_url.txt
    // + the .errorMode marker), so checkForPreviousSessionFiles() uploads it on the next
    // launch after a crash, and a clean exit clears it as a stale error-mode buffer.

    private func externalBufferFiles() -> (folder: URL, frame: URL, url: URL, marker: URL)? {
        guard let root = getSessionReplayDirectory(),
              let sessionId = NewRelicAgentInternal.sharedInstance()?.currentSessionId() else {
            return nil
        }
        let folder = root.appendingPathComponent("\(sessionId)/")
        return (folder,
                folder.appendingPathComponent("frame_0.json"),
                root.appendingPathComponent("\(sessionId)_upload_url.txt"),
                root.appendingPathComponent(kNRMA_SessionReplayErrorMode_marker))
    }

    private func persistExternalBuffer() {
        guard !externalBuffer.isEmpty,
              let files = externalBufferFiles(),
              let jsonData = try? JSONSerialization.data(withJSONObject: externalBuffer) else { return }
        let bounds = SessionReplayManager.timestampBounds(jsonData)
        let now = Date().timeIntervalSince1970 * 1000
        guard let uploadUrl = sessionReplayReporter.uploadURL(
            uncompressedDataSize: jsonData.count,
            firstTimestamp: bounds?.0 ?? now,
            lastTimestamp: bounds?.1 ?? now,
            isFirstChunk: sessionReplay.isFirstChunk,
            isGZipped: true) else { return }
        do {
            try FileManager.default.createDirectory(
                at: files.folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            try jsonData.write(to: files.frame, options: .atomic)
            try uploadUrl.absoluteString.write(to: files.url, atomically: true, encoding: .utf8)
            if !FileManager.default.fileExists(atPath: files.marker.path) {
                FileManager.default.createFile(atPath: files.marker.path, contents: nil)
            }
        } catch {
            NSLog("🧪[SR-NATIVE-BUFFER] failed to persist buffer: \(error)")
        }
    }

    private func clearPersistedExternalBuffer() {
        guard let files = externalBufferFiles() else { return }
        try? FileManager.default.removeItem(at: files.folder)
        try? FileManager.default.removeItem(at: files.url)
        try? FileManager.default.removeItem(at: files.marker)
    }

    private func flushExternalErrorBuffer() {
        clearPersistedExternalBuffer() // uploading now; nothing left to recover
        guard !externalBuffer.isEmpty,
              let jsonData = try? JSONSerialization.data(withJSONObject: externalBuffer) else {
            NSLog("🧪[SR-NATIVE-BUFFER] error — nothing buffered to flush")
            return
        }
        let count = externalBuffer.count
        externalBuffer.removeAll()
        let bounds = SessionReplayManager.timestampBounds(jsonData)
        let now = Date().timeIntervalSince1970 * 1000
        let (payload, uncompressedDataSize) = compressReplayPayload(jsonData)
        guard let upload = buildUpload(payload: payload,
                                       uncompressedDataSize: uncompressedDataSize,
                                       firstTimestamp: bounds?.0 ?? now,
                                       lastTimestamp: bounds?.1 ?? now,
                                       isFirstChunk: sessionReplay.isFirstChunk) else {
            return
        }
        NSLog("🧪[SR-NATIVE-BUFFER] flush on error — events=\(count) isFirstChunk=\(sessionReplay.isFirstChunk)")
        sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
        sessionReplay.isFirstChunk = false
    }

    @objc(recordSessionReplayEvents:bufferForErrorMode:)
    public func recordSessionReplayEvents(_ eventsJSON: String, bufferForErrorMode: Bool) -> Bool {
        guard bufferForErrorMode else {
            return uploadSessionReplayEvents(eventsJSON)
        }
        guard let jsonData = eventsJSON.data(using: .utf8),
              let events = (try? JSONSerialization.jsonObject(with: jsonData)) as? [[String: Any]],
              !events.isEmpty else {
            return false
        }
        sessionReplayQueue.async { [self] in
            // After an error the session records in full; upload directly (queued
            // behind the flush on this serial queue, so order is kept).
            if externalErrorTriggered {
                _ = uploadSessionReplayEvents(eventsJSON)
                return
            }
            externalBuffer.append(contentsOf: events)
            pruneExternalBuffer(nowMs: Date().timeIntervalSince1970 * 1000)
            persistExternalBuffer()
        }
        return true
    }

    private func uploadSessionReplayEvents(_ eventsJSON: String) -> Bool {
        // The enable/sampling gate lives in the caller
        // (NewRelicAgentInternal.recordSessionReplayEvents), which drops events
        // unless the config-resolved recording mode is not off. We deliberately
        // do NOT gate on `sessionReplayMode` here: that reflects whether the
        // *native* capture loop is running, which is independent of — and, for
        // externally-produced (e.g. Flutter) frames, intentionally decoupled
        // from — the config-driven decision to record.
        guard let jsonData = eventsJSON.data(using: .utf8), !jsonData.isEmpty else {
            NRLOG_AGENT_DEBUG("recordSessionReplayEvents: empty or invalid JSON.")
            return false
        }

        sessionReplayQueue.async { [self] in
            let bounds = SessionReplayManager.timestampBounds(jsonData)
            let now = Date().timeIntervalSince1970 * 1000
            let (payload, uncompressedDataSize) = compressReplayPayload(jsonData)
            guard let upload = buildUpload(payload: payload,
                                           uncompressedDataSize: uncompressedDataSize,
                                           firstTimestamp: bounds?.0 ?? now,
                                           lastTimestamp: bounds?.1 ?? now,
                                           isFirstChunk: sessionReplay.isFirstChunk) else {
                return
            }
            // TEST-ONLY (2026-09-29, hybrid-app Option C PoC — revert before merge).
            NSLog("🧪[HYBRID-POC] FLUTTER-BRIDGE upload enqueued — isFirstChunk=\(sessionReplay.isFirstChunk)")
            sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            sessionReplay.isFirstChunk = false
        }
        return true
    }

    /// Extracts the min/max `timestamp` (ms) from a serialized rrweb event array,
    /// used to stamp the upload URL. Returns nil if the JSON isn't a non-empty
    /// array of timestamped objects.
    private static func timestampBounds(_ data: Data) -> (TimeInterval, TimeInterval)? {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              !arr.isEmpty else { return nil }
        let ts = arr.compactMap { ($0["timestamp"] as? NSNumber)?.doubleValue }
        guard let lo = ts.min(), let hi = ts.max() else { return nil }
        return (lo, hi)
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
            
            let frameFiles = try FileManager.default.contentsOfDirectory(at: sessionDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("frame_") }
                .sorted { (url1, url2) -> Bool in
                    let name1 = url1.deletingPathExtension().lastPathComponent
                    let name2 = url2.deletingPathExtension().lastPathComponent
                    
                    let number1 = Int(name1.replacingOccurrences(of: "frame_", with: "")) ?? 0
                    let number2 = Int(name2.replacingOccurrences(of: "frame_", with: "")) ?? 0
                    
                    return number1 < number2
                }
            
            if frameFiles.isEmpty {
                NRLOG_AGENT_DEBUG("No frame files found for session ID: \(sessionId)")
                try? FileManager.default.removeItem(at: urlFile)
                try? FileManager.default.removeItem(at: sessionDirectory)
                return
            }
            
            // Read and combine all frame files, starting from the first full frame
            var frameContents: [String] = []
            var foundFirstFullFrame = false

            for frameFile in frameFiles {
                do {
                    // remove outer [] from frameFile if they exist
                    let frameContent = try String(contentsOf: frameFile).trimmingCharacters(in: .whitespacesAndNewlines)

                    var frameContentWithOuterBracketsRemoved = frameContent
                    if frameContent.hasPrefix("[") && frameContent.hasSuffix("]") {
                        frameContentWithOuterBracketsRemoved = String(frameContent.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    }

                    if !frameContentWithOuterBracketsRemoved.isEmpty {
                        // Check if this is a full frame (type = 2) if we haven't found one yet
                        if !foundFirstFullFrame {
                            // Parse the original content (with brackets) to check for full frames
                            if let data = frameContent.data(using: .utf8),
                               let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                                // Check if any frame in this file is a full snapshot (type = 2)
                                let hasFullFrame = jsonArray.contains { frame in
                                    if let type = frame["type"] as? Int {
                                        // NRLOG_AGENT_DEBUG("Frame type found: \(type) in file \(frameFile.lastPathComponent)")
                                        
                                        return type == 2 //  fullSnapshot

                                    }
                                    return false
                                }

                                if hasFullFrame {
                                    foundFirstFullFrame = true
                                    frameContents.append(frameContentWithOuterBracketsRemoved)
                                } else {
                                    NRLOG_AGENT_DEBUG("Skipping frame file \(frameFile.lastPathComponent) - no full snapshot found yet")
                                }
                            } else {
                                NRLOG_AGENT_DEBUG("Failed to parse frame file \(frameFile.lastPathComponent) to check type")
                            }
                        } else {
                            // We've found a full frame, include all subsequent frames
                            frameContents.append(frameContentWithOuterBracketsRemoved)
                        }
                    }
                } catch {
                    NRLOG_AGENT_DEBUG("Failed to read frame file \(frameFile.lastPathComponent): \(error)")
                }
            }
            
            if frameContents.isEmpty {
                if !foundFirstFullFrame {
                    NRLOG_AGENT_DEBUG("No full snapshot frame found for session ID: \(sessionId)")
                } else {
                    NRLOG_AGENT_DEBUG("No valid frame content found for session ID: \(sessionId)")
                }
                try FileManager.default.removeItem(at: sessionDirectory)
                try? FileManager.default.removeItem(at: urlFile)
                return
            }
            
            // Construct JSON array from frame contents
            
            let jsonArrayString = "[" + frameContents.joined(separator: ",") + "]"
            
            guard let jsonData = jsonArrayString.data(using: .utf8) else {
                NRLOG_AGENT_DEBUG("Failed to convert JSON string to data for session ID: \(sessionId)")
                return
            }
            //if let jsonString = String(data: jsonData, encoding: .utf8) {
            //    NRLOG_AGENT_DEBUG(jsonString)
            //\
            //}
            
            // END DATA CONSTRUCTION
            
            var finalData = jsonData
            do {
                let gzippedData = try jsonData.gzipped()
                finalData = gzippedData
            } catch {
                NRLOG_AGENT_DEBUG("Failed to gzip session replay data for session ID \(sessionId): \(error.localizedDescription)")
            }
            
            let upload = SessionReplayData(sessionReplayFramesData: finalData, url: url)
            sessionReplayReporter.enqueueSessionReplayUpload(upload: upload)
            NRLOG_AGENT_DEBUG("Enqueued previous session replay for session ID: \(sessionId)")
            
            // Remove processed files
            try FileManager.default.removeItem(at: sessionDirectory)
            try? FileManager.default.removeItem(at: urlFile)
            
        } catch {
            NRLOG_AGENT_DEBUG("Failed to process session replay file for session ID \(sessionId): \(error)")
        }
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
