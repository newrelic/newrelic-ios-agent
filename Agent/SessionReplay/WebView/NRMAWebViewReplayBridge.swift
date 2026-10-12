//
//  NRMAWebViewReplayBridge.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
import WebKit
@_implementationOnly import NewRelicPrivate

/// Captures a WKWebView's own session replay and forwards it to native through a script message
/// handler.
///
/// Flow:
/// 1. `install(on:)` runs from the `WKWebView` init swizzle, before the first navigation, and adds a
///    document-start `navigation` script, a document-end `ready` script, and the `nrWebViewReplay`
///    message handler.
/// 2. `navigation` marks the moment the old page leaves the screen, so the replay drops it right
///    there.
/// 3. At `ready`, if replay is recording in FULL mode, the page is recorded according to
///    `captureStrategy`: by default rrweb's recorder, which snapshots the page immediately
///    (`WebViewReplayRecorder`); optionally the browser agent in observation mode (`injectionScript`).
/// 4. Events arrive as `events` messages. On a background queue their node IDs are remapped into the
///    native ID space (`WebViewReplayRemapper`), and they are buffered on `NRMASessionReplay` until
///    the harvest splices them into the native tree under the WebView's `<iframe>` node
///    (`WebViewReplayChunkBuilder`). After each harvest every recording page is asked for a fresh
///    snapshot, so each chunk starts with a current document.
@available(iOS 13.0, *)
public class NRMAWebViewReplayBridge: NSObject {

    static let shared = NRMAWebViewReplayBridge()

    static let messageHandlerName = "nrWebViewReplay"

    /// License key the injected observation-mode agent advertises. Never used for egress (observation
    /// mode sends nothing); it lets browser agent detection tell a page-owned agent from ours.
    static let observationLicenseKey = "NRWV_OBSERVATION_MODE"

    /// How a page's DOM is recorded.
    enum CaptureStrategy {
        /// rrweb's recorder, injected directly (`WebViewReplayRecorder`). Snapshots the page as soon as
        /// it is parsed, sends changes every second, and can be asked for a fresh snapshot at any time.
        /// Leaves any browser agent on the page untouched.
        case standaloneRecorder
        /// The experimental browser agent in observation mode, forwarding its session_replay
        /// harvests; the recorder takes over for pages it cannot serve. Kept for comparison with the
        /// Android POC. Measured on device, it is the slower and less reliable path: its replay
        /// harvests arrive on a 5s cadence, a resumed session (a same-origin navigation) harvests
        /// mutations without the snapshot they apply to, a fresh snapshot cannot be requested, and
        /// once injected it cannot be removed -- a recorder that takes over alongside it was observed
        /// to capture snapshots but no mutations.
        case browserAgentObservation
    }

    static let captureStrategy: CaptureStrategy = .standaloneRecorder

    /// Posted by `injectionScript` when the page already has a browser agent.
    static let existingAgentReason = "existing-agent"

    /// Posted by `injectionScript` when the observation agent has not produced a FullSnapshot within
    /// `snapshotWatchdogMs` of its hook registering.
    static let noSnapshotReason = "no-snapshot"

    /// On a fresh session the agent's first replay harvest, snapshot included, arrives within a few
    /// hundred ms of the hook registering. Past this, the page falls back to the standalone recorder,
    /// which snapshots immediately.
    static let snapshotWatchdogMs = 1500

    /// When a page shows signs of a browser agent still on its way -- a New Relic or tag manager
    /// script whose agent has not initialized yet -- how long after `load` to wait before deciding.
    /// Such pages load the agent asynchronously or from a tag manager that fires on `load`, so
    /// deciding at document end would miss it and put a second agent on the page. Every other page
    /// is decided immediately, at document end.
    static let agentSettleDelayMs = 1000

    /// Starts anyway if `load` never fires, e.g. a page with a resource that never finishes.
    static let agentLoadBackstopMs = 10000

    /// Experimental browser agent build -- the only one exposing observation_mode and beforeHarvest.
    static let loaderURL = "https://js-agent.newrelic.com/experiments/dev/before-send-hook/nr-loader-spa.min.js"

    /// Set by `NRMASessionReplay` on init.
    weak var sessionReplay: NRMASessionReplay?

    private final class WeakWebView {
        weak var webView: WKWebView?
        /// The document has posted `ready` but the agent has not been injected into it yet, because
        /// replay was not recording at the time. Injected if recording later switches to FULL.
        var awaitingInjection = false
        /// Used only on `parseQueue`.
        let remapper: WebViewReplayRemapper
        init(_ webView: WKWebView, channelId: Int) {
            self.webView = webView
            self.remapper = WebViewReplayRemapper(channelId: channelId)
        }
    }

    private let lock = NSLock()
    private var channels = [Int: WeakWebView]()

    /// Off the main thread: a replay batch can be megabytes of JSON, and parsing it there would stall
    /// the app. Serial, so batches are wrapped in arrival order.
    private let parseQueue = DispatchQueue(label: "com.newrelic.sessionreplay.webview", qos: .utility)

    private lazy var messageHandler = MessageHandler(bridge: self)

    // MARK: - Installation

    /// Called from the `WKWebView` init swizzle.
    @objc(installOnWebView:)
    public static func install(on webView: WKWebView) {
        shared.install(on: webView)
    }

    func install(on webView: WKWebView) {
        // Apps commonly share one WKUserContentController across WebViews, and registering the same
        // handler name twice raises. Install once per controller; `message.webView` tells the WebViews
        // apart.
        let controller = webView.configuration.userContentController
        if controller.nrWebViewReplayInstalled {
            return
        }
        controller.nrWebViewReplayInstalled = true

        controller.addUserScript(WKUserScript(source: Self.navigationScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true))
        controller.addUserScript(WKUserScript(source: Self.readyScript,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: true))
        controller.add(messageHandler, name: Self.messageHandlerName)

        if isRecordingFull {
            prefetchRecorder()
        }
    }

    /// Downloads the standalone recorder ahead of the first page that needs it, so a page with its
    /// own browser agent starts recording as soon as it is detected rather than after a download.
    private func prefetchRecorder() {
        WebViewReplayRecorderSource.shared.load { _ in }
    }

    // MARK: - Channels

    /// Channels whose WebView is still alive. Safe from any thread.
    func liveChannelIds() -> Set<Int> {
        lock.lock()
        defer { lock.unlock() }
        channels = channels.filter { $0.value.webView != nil }
        embeddedChannels = embeddedChannels.filter { $0.value.view != nil }
        return Set(channels.keys).union(embeddedChannels.keys)
    }

    /// Main thread. Resolves the channel and blocked state through `ViewDetails`, which is also what
    /// assigns the WebView's stable node ID if it has not been captured yet. The channel ID is that
    /// node ID: it is the `<iframe>` node the page's document gets attached to.
    private func channel(for webView: WKWebView) -> (id: Int, isBlocked: Bool, remapper: WebViewReplayRemapper) {
        let details = ViewDetails(view: webView)
        lock.lock()
        defer { lock.unlock() }
        if channels[details.viewId]?.webView !== webView {
            channels[details.viewId] = WeakWebView(webView, channelId: details.viewId)
        }
        let remapper = channels[details.viewId]!.remapper
        return (details.viewId, details.blockView ?? false, remapper)
    }

    private var isRecordingFull: Bool {
        sessionReplay?.recordingMode == .full
    }

    /// Recording switched to FULL: inject into documents that loaded while it wasn't.
    func recordingBecameFull() {
        prefetchRecorder()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let waiting = self.channels.values.filter { $0.awaitingInjection }.compactMap { $0.webView }
            self.lock.unlock()
            waiting.forEach { self.inject(into: $0) }
            self.requestEmbeddedFullSnapshots()
        }
    }

    /// Asks every recording page for a fresh FullSnapshot. Called after each native harvest: the next
    /// chunk then gets a current document within about a second, instead of relying on an old one
    /// plus a history of changes that grows every chunk. Pages under the observation agent have no
    /// way to request one and ignore this.
    func requestFreshDocuments() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRecordingFull else { return }
            self.lock.lock()
            let webViews = self.channels.values.compactMap { $0.webView }
            self.lock.unlock()
            for webView in webViews {
                webView.evaluateJavaScript(WebViewReplayRecorder.takeFullSnapshotScript, completionHandler: nil)
            }
            self.requestEmbeddedFullSnapshots()
        }
    }

    // MARK: - Embedded renderers (Flutter)

    /// Posted, with the renderer's view as `object`, when its next events should start with a fresh
    /// FullSnapshot: after every harvest (so each chunk gets a current document), when recording
    /// becomes FULL, and when events arrive with no document to attach them to.
    public static let embeddedFullSnapshotRequest = Notification.Name("com.newrelic.sessionReplay.requestFullSnapshot")

    private final class EmbeddedChannel {
        weak var view: UIView?
        /// Used only on `parseQueue`.
        let remapper: WebViewReplayRemapper
        var lastSnapshotRequest: TimeInterval = 0
        init(_ view: UIView, channelId: Int) {
            self.view = view
            self.remapper = WebViewReplayRemapper(channelId: channelId)
        }
    }

    private var embeddedChannels = [Int: EmbeddedChannel]()

    /// Main thread. The channel is the view's stable node ID: the `<iframe>` node
    /// `EmbeddedRendererThingy` records for it, which the renderer's document is grafted under.
    private func embeddedChannel(for view: UIView) -> (id: Int, isBlocked: Bool, channel: EmbeddedChannel) {
        let details = ViewDetails(view: view)
        let channelId = EmbeddedRendererThingy.channelId(forViewId: details.viewId)
        lock.lock()
        defer { lock.unlock() }
        if embeddedChannels[channelId]?.view !== view {
            embeddedChannels[channelId] = EmbeddedChannel(view, channelId: channelId)
        }
        return (channelId, details.blockView ?? false, embeddedChannels[channelId]!)
    }

    /// Main thread.
    private func requestEmbeddedFullSnapshots() {
        lock.lock()
        let views = embeddedChannels.values.compactMap { $0.view }
        lock.unlock()
        for view in views {
            NotificationCenter.default.post(name: Self.embeddedFullSnapshotRequest, object: view)
        }
    }

    /// rrweb events (a JSON array) produced by a renderer that draws `view` itself. Main thread.
    /// FULL mode only, like WebViews.
    @objc(recordEmbeddedEvents:forView:)
    public static func recordEmbeddedEvents(_ text: String, for view: UIView) -> Bool {
        return shared.receiveEmbeddedEvents(text, from: view)
    }

    private func receiveEmbeddedEvents(_ text: String, from view: UIView) -> Bool {
        guard isRecordingFull else { return false }
        let embedded = embeddedChannel(for: view)
        guard !embedded.isBlocked else { return false }
        let receivedAt = (Date().timeIntervalSince1970 * 1000).rounded()
        parseQueue.async { [weak self] in
            guard let events = WebViewReplayPayloadParser.extractEvents(from: text), !events.isEmpty else {
                return
            }
            let translated = embedded.channel.remapper.translate(events, receivedAt: receivedAt)
            if translated.isEmpty {
                // Incrementals with no document yet (e.g. the renderer's snapshot was sent before
                // recording became FULL). Ask for one, at most every 2 s.
                if receivedAt - embedded.channel.lastSnapshotRequest > 2000 {
                    embedded.channel.lastSnapshotRequest = receivedAt
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Self.embeddedFullSnapshotRequest, object: view)
                    }
                }
                return
            }
            self?.sessionReplay?.addWebViewReplayEvents(translated)
        }
        return true
    }

    // MARK: - Messages

    fileprivate func didReceive(_ message: WKScriptMessage) {
        guard let webView = message.webView,
              let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else {
            return
        }

        switch kind {
        case "navigation":
            let timestamp = (body["ts"] as? NSNumber)?.doubleValue ?? (Date().timeIntervalSince1970 * 1000).rounded()
            documentCommitted(in: webView, at: timestamp)
        case "ready":
            documentReady(in: webView)
        case "events":
            guard let events = body["body"] as? String else { return }
            receiveEvents(events, from: webView)
        case "hooked":
            NRLOG_AGENT_DEBUG("[NR-WV-SR] beforeHarvest hook registered")
            NRMASupportMetricHelper.enqueueWebViewReplayMetric("Injected")
        case "skipped":
            let reason = body["reason"] as? String ?? "unknown"
            // Whatever stopped the observation agent -- the page's own agent, a loader blocked by CSP,
            // a build without beforeHarvest, or no snapshot forthcoming -- the page is still recorded,
            // by the standalone recorder, which leaves any browser agent on the page alone.
            NRLOG_AGENT_DEBUG("[NR-WV-SR] observation agent not used (\(reason)); recording with the standalone recorder")
            NRMASupportMetricHelper.enqueueWebViewReplayMetric(reason == Self.existingAgentReason ? "ExistingAgent" : "InjectionSkipped")
            startRecorder(in: webView)
        case "recording":
            NRLOG_AGENT_DEBUG("[NR-WV-SR] standalone recorder started")
            NRMASupportMetricHelper.enqueueWebViewReplayMetric("RecorderStarted")
        case "observed":
            NRLOG_AGENT_DEBUG("[NR-WV-SR] \(body["info"] as? String ?? "")")
        default:
            break
        }
    }

    /// `webView` replaced its document -- a navigation, a reload, or the app loading new content.
    /// Main thread; posted at document start, the moment the old page leaves the screen.
    ///
    /// On the parse queue so it lands between the old document's events and the new one's. It both
    /// forgets the old document's IDs and tells the harvest to take the old page off the iframe right
    /// here, rather than showing it until the new page's snapshot replaces it.
    private func documentCommitted(in webView: WKWebView, at timestamp: TimeInterval) {
        let channel = channel(for: webView)
        parseQueue.async { [weak self] in
            let navigation = channel.remapper.navigation(at: timestamp)
            self?.sessionReplay?.addWebViewReplayEvents([navigation])
        }
    }

    /// A new document in `webView` finished parsing. Main thread.
    private func documentReady(in webView: WKWebView) {
        let channel = channel(for: webView)

        guard isRecordingFull, !channel.isBlocked else {
            // Not an error: a page can finish loading before the collector's connect response has
            // settled the replay mode. Injected if recording switches to FULL later.
            setAwaitingInjection(true, channelId: channel.id)
            return
        }
        inject(into: webView)
    }

    private func inject(into webView: WKWebView) {
        let channel = channel(for: webView)
        guard isRecordingFull, !channel.isBlocked else { return }
        setAwaitingInjection(false, channelId: channel.id)

        if Self.captureStrategy == .standaloneRecorder {
            startRecorder(in: webView)
            return
        }

        // The script is sentinel-guarded, so a second evaluation into the same document is a no-op.
        webView.evaluateJavaScript(Self.injectionScript) { _, error in
            if let error = error {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] injection script failed: \(error.localizedDescription)")
            }
        }
    }

    /// Starts the standalone recorder in a page that has its own browser agent. Main thread.
    private func startRecorder(in webView: WKWebView) {
        guard isRecordingFull, !channel(for: webView).isBlocked else { return }
        let expectedURL = webView.url
        // Resolved per page, so a masking configuration change applies from the next page load.
        let masking = WebViewReplayMasking(viewDetails: ViewDetails(view: webView))
        WebViewReplayRecorderSource.shared.load { [weak self, weak webView] source in
            guard let self = self, let webView = webView, self.isRecordingFull else { return }
            guard let source = source else {
                NRMASupportMetricHelper.enqueueWebViewReplayMetric("RecorderUnavailable")
                return
            }
            // The first download can take a moment; don't start recording a page the WebView has
            // since navigated away from. The new page reports in with its own `ready`.
            guard webView.url == expectedURL else { return }
            let script = WebViewReplayRecorder.bootstrapScript(source: source, handlerName: Self.messageHandlerName, masking: masking)
            webView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    NRLOG_AGENT_DEBUG("[NR-WV-SR] recorder script failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func setAwaitingInjection(_ awaiting: Bool, channelId: Int) {
        lock.lock()
        channels[channelId]?.awaitingInjection = awaiting
        lock.unlock()
    }

    private func receiveEvents(_ text: String, from webView: WKWebView) {
        // FULL mode only. ERROR mode's sliding-window prune deletes frames by age, which could drop the
        // chunk carrying a WebView's document while mutations that depend on it survive.
        guard isRecordingFull else { return }
        let channel = channel(for: webView)
        guard !channel.isBlocked else { return }

        let receivedAt = (Date().timeIntervalSince1970 * 1000).rounded()
        parseQueue.async { [weak self] in
            guard let events = WebViewReplayPayloadParser.extractEvents(from: text), !events.isEmpty else {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] replay batch (\(text.utf8.count) bytes) contained no rrweb events")
                return
            }
            let translated = channel.remapper.translate(events, receivedAt: receivedAt)
            if translated.isEmpty {
                // Usually incrementals with no document to apply to: the page's snapshot never arrived.
                NRLOG_AGENT_DEBUG("[NR-WV-SR] dropped a batch of \(events.count) event(s) with no document to attach to")
                return
            }
            if let document = translated.first(where: { $0.isDocument }),
               let latency = channel.remapper.takeCaptureLatency(for: document) {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] page captured \(Int(latency)) ms after navigation")
            }
            self?.sessionReplay?.addWebViewReplayEvents(translated)
        }
    }

    // MARK: - Scripts

    /// Posts `navigation` as each main-frame document starts, stamped with the page's own clock.
    static let navigationScript = #"""
    (function(){try{window.webkit.messageHandlers.nrWebViewReplay.postMessage({kind:'navigation',ts:Date.now()});}catch(e){}})();
    """#

    /// Posts `ready` once per main-frame document.
    static let readyScript = #"""
    (function(){try{window.webkit.messageHandlers.nrWebViewReplay.postMessage({kind:'ready'});}catch(e){}})();
    """#

    /// Injects the browser agent in observation mode and registers a beforeHarvest hook that forwards
    /// session_replay payloads to native. Sentinel-guarded, so repeat evaluations are no-ops.
    ///
    /// Configuration that is load-bearing (all found on Android devices):
    /// - `session_trace` must stay enabled: replay couples to trace through session identity, and with
    ///   trace disabled replay never records.
    /// - `page_view_event` must stay enabled: its postHarvestCleanup triggers
    ///   activateWithSyntheticRumResponse, the only source of the srs/sr flags replay waits on.
    /// - `harvest.interval` is 5s: at the default 30s the first replay harvest looks like a failure.
    /// - `inline_stylesheet` stays on while fonts and images are shed: the player cannot reach the
    ///   customer's origin, so without inlined stylesheets the page would replay unstyled.
    ///
    /// The hook never returns null. Per the beforeHarvest contract null CANCELS the harvest, while
    /// undefined sends the original unmodified, so every exit returns the payload or undefined.
    ///
    /// A binary body is refused rather than forwarded: JSON.stringify silently expands a typed array
    /// into one key per byte, so a compressing agent build would otherwise flood the bridge.
    static let injectionScript = """
    (function(){
    var H=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.\(messageHandlerName);
    if(!H){return;}
    var post=function(m){try{H.postMessage(m);}catch(e){}};
    if(window.__nrWvScheduled){return;}
    window.__nrWvScheduled=true;
    var foreignAgent=function(){return !!(window.NREUM&&window.NREUM.info&&window.NREUM.info.licenseKey!=='\(observationLicenseKey)');};
    var started=false;
    var start=function(){
    if(started){return;}
    started=true;
    try{
    if(window.__nrWvInjected){return;}
    if(window.NREUM||window.newrelic){post({kind:'skipped',reason:'\(existingAgentReason)'});return;}
    window.__nrWvInjected=true;
    window.NREUM=window.NREUM||{};
    window.NREUM.info={beacon:'bam.nr-data.net',errorBeacon:'bam.nr-data.net',licenseKey:'\(observationLicenseKey)',applicationID:'0',sa:1};
    window.NREUM.loader_config={licenseKey:'\(observationLicenseKey)',applicationID:'0',agentID:'0',trustKey:'0'};
    window.NREUM.init={observation_mode:{enabled:true},harvest:{interval:5},session_trace:{enabled:true},
    session_replay:{enabled:true,sampling_rate:100,error_sampling_rate:100,inline_stylesheet:true,collect_fonts:false,inline_images:false}};
    var hookSeen=false;var srSeen=false;var yielded=false;var documentSeen=false;
    var yieldTo=function(reason){if(yielded){return;}yielded=true;post({kind:'skipped',reason:reason});};
    var hasDocument=function(body){
    try{
    var events=typeof body==='string'?JSON.parse(body):body;
    if(events&&!Array.isArray(events)&&Array.isArray(events.body)){events=events.body;}
    if(!Array.isArray(events)){return false;}
    for(var i=0;i<events.length;i++){if(events[i]&&events[i].type===2){return true;}}
    }catch(e){}
    return false;
    };
    var passThrough=function(h){return (h&&h.payload!=null)?h.payload:undefined;};
    var isBinary=function(v){try{
    if(!v||typeof v!=='object'){return false;}
    if(typeof Blob!=='undefined'&&v instanceof Blob){return true;}
    if(typeof ArrayBuffer==='undefined'){return false;}
    return (v instanceof ArrayBuffer)||!!(ArrayBuffer.isView&&ArrayBuffer.isView(v));
    }catch(e){return false;}};
    var hook=function(h){
    try{
    if(!hookSeen){hookSeen=true;post({kind:'observed',info:'first harvest: feature='+(h&&h.feature)});}
    if(foreignAgent()){yieldTo('\(existingAgentReason)');}
    if(yielded){return passThrough(h);}
    if(!h||h.feature!=='session_replay'){return passThrough(h);}
    var pl=h.payload;var body=(pl&&typeof pl==='object')?pl.body:null;var out=null;var shape='json';
    try{
    if(isBinary(pl)||isBinary(body)){shape='binary';}
    else if(typeof body==='string'){out=body;}
    else if(body){out=JSON.stringify(body);}
    else{out=JSON.stringify(pl);}
    }catch(e){out=null;shape='error:'+(e&&e.message);}
    if(!srSeen){srSeen=true;post({kind:'observed',info:'first session_replay harvest: shape='+shape+' chars='+(out?out.length:-1)});}
    if(out&&!documentSeen){documentSeen=hasDocument(body||pl);}
    if(out){post({kind:'events',body:out});}
    else{post({kind:'skipped',reason:'replay-body-unreadable ('+shape+')'});}
    }catch(e){}
    return passThrough(h);
    };
    var register=function(n){
    try{
    if(window.newrelic&&typeof window.newrelic.beforeHarvest==='function'){
    window.newrelic.beforeHarvest(hook);post({kind:'hooked'});
    // The agent does not always deliver a snapshot: resuming a session on a same-origin navigation it
    // harvests only mutations, which have no document to attach to. Don't wait on it.
    setTimeout(function(){if(!documentSeen){yieldTo('\(noSnapshotReason)');}},\(snapshotWatchdogMs));
    return;}
    if(n>=100){post({kind:'skipped',reason:'beforeHarvest-unavailable (typeof newrelic='+(typeof window.newrelic)+')'});return;}
    setTimeout(function(){register(n+1);},50);
    }catch(e){}
    };
    var s=document.createElement('script');
    s.src='\(loaderURL)';
    s.type='text/javascript';
    s.onerror=function(){post({kind:'skipped',reason:'loader-load-failed'});};
    (document.head||document.documentElement).appendChild(s);
    register(0);
    }catch(e){}
    };
    var agentMayBeLoading=function(){
    var scripts=document.scripts;
    for(var i=0;i<scripts.length;i++){
    var sc=scripts[i];
    if(sc.src){if(/js-agent[.]newrelic[.]com|nr-loader|googletagmanager[.]com|tealium|ensighten|segment[.](com|io)/.test(sc.src)){return true;}}
    else if(sc.textContent&&sc.textContent.indexOf('NREUM')>=0){return true;}
    }
    return false;
    };
    if(window.NREUM||window.newrelic||document.readyState==='complete'||!agentMayBeLoading()){start();}
    else{
    window.addEventListener('load',function(){setTimeout(start,\(agentSettleDelayMs));});
    setTimeout(start,\(agentLoadBackstopMs));
    }
    })();
    """
}

/// The content controller retains its handlers strongly, so the handler holds the bridge weakly and
/// holds no WebView at all.
@available(iOS 13.0, *)
private final class MessageHandler: NSObject, WKScriptMessageHandler {
    weak var bridge: NRMAWebViewReplayBridge?

    init(bridge: NRMAWebViewReplayBridge) {
        self.bridge = bridge
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        bridge?.didReceive(message)
    }
}

fileprivate var associatedWebViewReplayInstalledKey: String = "NRWebViewReplayInstalled"

private extension WKUserContentController {
    var nrWebViewReplayInstalled: Bool {
        set {
            withUnsafePointer(to: &associatedWebViewReplayInstalledKey) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
        get {
            withUnsafePointer(to: &associatedWebViewReplayInstalledKey) {
                (objc_getAssociatedObject(self, $0) as? Bool) ?? false
            }
        }
    }
}
#endif
