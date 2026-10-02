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

/// Captures a WKWebView's own session replay by running the New Relic Browser agent inside it in
/// observation mode -- building every payload it would send, sending none -- and forwarding its
/// `session_replay` payloads to native through a script message handler.
///
/// Flow:
/// 1. `install(on:)` runs from the `WKWebView` init swizzle, before the first navigation, and adds a
///    document-end user script plus the `nrWebViewReplay` message handler.
/// 2. At document end the page posts `ready`. If replay is recording in FULL mode, native evaluates
///    `injectionScript`, which loads the experimental loader and registers a `beforeHarvest` hook.
/// 3. The hook posts each `session_replay` body as `events`; they are wrapped per channel on a
///    background queue and buffered on `NRMASessionReplay` until the next harvest.
@available(iOS 13.0, *)
public class NRMAWebViewReplayBridge: NSObject {

    static let shared = NRMAWebViewReplayBridge()

    static let messageHandlerName = "nrWebViewReplay"

    /// License key the injected observation-mode agent advertises. Never used for egress (observation
    /// mode sends nothing); it lets browser agent detection tell a page-owned agent from ours.
    static let observationLicenseKey = "NRWV_OBSERVATION_MODE"

    /// Experimental browser agent build -- the only one exposing observation_mode and beforeHarvest.
    static let loaderURL = "https://js-agent.newrelic.com/experiments/dev/before-send-hook/nr-loader-spa.min.js"

    /// Set by `NRMASessionReplay` on init.
    weak var sessionReplay: NRMASessionReplay?

    private final class WeakWebView {
        weak var webView: WKWebView?
        /// The document has posted `ready` but the agent has not been injected into it yet, because
        /// replay was not recording at the time. Injected if recording later switches to FULL.
        var awaitingInjection = false
        init(_ webView: WKWebView) { self.webView = webView }
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

        controller.addUserScript(WKUserScript(source: Self.readyScript,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: true))
        controller.add(messageHandler, name: Self.messageHandlerName)
    }

    // MARK: - Channels

    /// Channels whose WebView is still alive. Safe from any thread.
    func liveChannelIds() -> Set<Int> {
        lock.lock()
        defer { lock.unlock() }
        channels = channels.filter { $0.value.webView != nil }
        return Set(channels.keys)
    }

    /// Main thread. Resolves the channel and blocked state through `ViewDetails`, which is also what
    /// assigns the WebView's stable node ID if it has not been captured yet.
    private func channel(for webView: WKWebView) -> (id: Int, isBlocked: Bool) {
        let details = ViewDetails(view: webView)
        lock.lock()
        if channels[details.viewId]?.webView !== webView {
            channels[details.viewId] = WeakWebView(webView)
        }
        lock.unlock()
        return (details.viewId, details.blockView ?? false)
    }

    private var isRecordingFull: Bool {
        sessionReplay?.recordingMode == .full
    }

    /// Recording switched to FULL: inject into documents that loaded while it wasn't.
    func recordingBecameFull() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let waiting = self.channels.values.filter { $0.awaitingInjection }.compactMap { $0.webView }
            self.lock.unlock()
            waiting.forEach { self.inject(into: $0) }
        }
    }

    /// Asks the observation agent in every WebView for a fresh FullSnapshot. Called when the native
    /// harvest produces a full snapshot: the replayed WebView then gets a current document instead of
    /// the one from when its page loaded. The recorder harvests a Meta + FullSnapshot immediately
    /// rather than on its interval, so it reaches native within moments.
    func requestFullSnapshots() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isRecordingFull else { return }
            self.lock.lock()
            let webViews = self.channels.values.compactMap { $0.webView }
            self.lock.unlock()
            for webView in webViews where !self.channel(for: webView).isBlocked {
                webView.evaluateJavaScript(Self.takeFullSnapshotScript, completionHandler: nil)
            }
        }
    }

    // MARK: - Messages

    fileprivate func didReceive(_ message: WKScriptMessage) {
        guard let webView = message.webView,
              let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else {
            return
        }

        switch kind {
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
            NRLOG_AGENT_DEBUG("[NR-WV-SR] injection skipped: \(reason)")
            NRMASupportMetricHelper.enqueueWebViewReplayMetric("InjectionSkipped")
        case "observed":
            NRLOG_AGENT_DEBUG("[NR-WV-SR] \(body["info"] as? String ?? "")")
        default:
            break
        }
    }

    /// A new document in `webView`. Main thread.
    private func documentReady(in webView: WKWebView) {
        let channel = channel(for: webView)

        // The previous document is gone. Without this its cached copy would be re-emitted into the next
        // chunk, showing the old page until the new one's first snapshot arrives.
        sessionReplay?.resetWebViewChannel(channel.id)

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

        // The script is sentinel-guarded, so a second evaluation into the same document is a no-op.
        webView.evaluateJavaScript(Self.injectionScript) { _, error in
            if let error = error {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] injection script failed: \(error.localizedDescription)")
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
            let envelopes = WebViewReplayPayloadParser.envelopes(fromBridgeBody: text,
                                                                 channelId: channel.id,
                                                                 receivedAt: receivedAt)
            if envelopes.isEmpty {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] replay batch (\(text.utf8.count) bytes) contained no rrweb events")
                return
            }
            self?.sessionReplay?.addWebViewReplayEvents(envelopes)
        }
    }

    // MARK: - Scripts

    /// Posts `ready` once per main-frame document.
    static let readyScript = #"""
    (function(){try{window.webkit.messageHandlers.nrWebViewReplay.postMessage({kind:'ready'});}catch(e){}})();
    """#

    /// Calls `takeFullSnapshot()` on the session replay recorder of the agent this bridge injected.
    /// Never touches a page-owned agent: it runs only in documents we injected into, and skips any
    /// agent advertising a license key other than ours. The recorder's own method is a no-op unless
    /// it is recording.
    static let takeFullSnapshotScript = """
    (function(){try{
    if(!window.__nrWvInjected){return;}
    var agents=window.NREUM&&window.NREUM.initializedAgents;if(!agents){return;}
    Object.keys(agents).forEach(function(id){try{
    var a=agents[id];var key=a&&a.info&&a.info.licenseKey;
    if(key&&key!=='\(observationLicenseKey)'){return;}
    var sr=a.features&&a.features.session_replay;var r=sr&&sr.featAggregate&&sr.featAggregate.recorder;
    if(r&&typeof r.takeFullSnapshot==='function'){r.takeFullSnapshot();}
    }catch(e){}});
    }catch(e){}})();
    """

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
    try{
    if(window.__nrWvInjected){return;}
    if(window.NREUM||window.newrelic){post({kind:'skipped',reason:'existing-agent'});return;}
    window.__nrWvInjected=true;
    window.NREUM=window.NREUM||{};
    window.NREUM.info={beacon:'bam.nr-data.net',errorBeacon:'bam.nr-data.net',licenseKey:'\(observationLicenseKey)',applicationID:'0',sa:1};
    window.NREUM.loader_config={licenseKey:'\(observationLicenseKey)',applicationID:'0',agentID:'0',trustKey:'0'};
    window.NREUM.init={observation_mode:{enabled:true},harvest:{interval:5},session_trace:{enabled:true},
    session_replay:{enabled:true,sampling_rate:100,error_sampling_rate:100,inline_stylesheet:true,collect_fonts:false,inline_images:false}};
    var hookSeen=false;var srSeen=false;
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
    if(!h||h.feature!=='session_replay'){return passThrough(h);}
    var pl=h.payload;var body=(pl&&typeof pl==='object')?pl.body:null;var out=null;var shape='json';
    try{
    if(isBinary(pl)||isBinary(body)){shape='binary';}
    else if(typeof body==='string'){out=body;}
    else if(body){out=JSON.stringify(body);}
    else{out=JSON.stringify(pl);}
    }catch(e){out=null;shape='error:'+(e&&e.message);}
    if(!srSeen){srSeen=true;post({kind:'observed',info:'first session_replay harvest: shape='+shape+' chars='+(out?out.length:-1)});}
    if(out){post({kind:'events',body:out});}
    else{post({kind:'skipped',reason:'replay-body-unreadable ('+shape+')'});}
    }catch(e){}
    return passThrough(h);
    };
    var register=function(n){
    try{
    if(window.newrelic&&typeof window.newrelic.beforeHarvest==='function'){window.newrelic.beforeHarvest(hook);post({kind:'hooked'});return;}
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
