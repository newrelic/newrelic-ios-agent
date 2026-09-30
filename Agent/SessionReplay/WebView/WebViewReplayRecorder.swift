//
//  WebViewReplayRecorder.swift
//  Agent_iOS
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation

#if os(iOS)
import CryptoKit
@_implementationOnly import NewRelicPrivate

/// Records a page that already runs its own New Relic Browser agent.
///
/// Injecting our observation-mode agent there is off the table: two agents on one page would fight
/// over `NREUM` and corrupt the customer's own browser data. The page's agent cannot be borrowed
/// either -- production builds have no `beforeHarvest` hook, and whether they record replay at all
/// is decided server side. So these pages get a bare rrweb recorder instead: the same recording
/// library the browser agent wraps, emitting the same events through the same bridge message, so
/// everything downstream (remapping, grafting under the WebView's iframe) is unchanged. It touches
/// no `NREUM` state, so the page's own agent is unaffected.
enum WebViewReplayRecorder {

    /// Pinned. The recorder runs inside customer pages, so what executes must be exactly what was
    /// reviewed: the download is refused unless it matches `sha256`.
    ///
    /// @rrweb/record 2.1.6, not the 2.0.0 alphas: in 2.0.0-alpha.4 a `blockSelector` made the mutation
    /// observer throw on text nodes and drop every batch, so pages recorded a snapshot and then never
    /// changed.
    static let sourceURL = URL(string: "https://cdn.jsdelivr.net/npm/@rrweb/record@2.1.6/umd/record.min.js")!
    static let sha256 = "fde9a5c5c38fc23c9f8d6429b4e74c8996156e1632f132693b68e32509dc92f0"

    /// How often buffered events cross the bridge. Short, so a page's changes reach the replay close to
    /// when they happened: batches that land after a native harvest are clamped to the next chunk's
    /// start. A document is flushed immediately regardless (see `bootstrapScript`).
    static let flushIntervalMs = 1000

    /// Asks a recording page for a fresh FullSnapshot. Evaluated after every native harvest, so each
    /// chunk gets a current document instead of an old one plus an ever-growing history of changes.
    /// A no-op on pages the recorder isn't running in.
    static let takeFullSnapshotScript = "window.__nrWvTakeFullSnapshot&&window.__nrWvTakeFullSnapshot();"

    /// Flush early rather than let one message grow without bound.
    static let maxBufferedEvents = 500

    /// The recorder's source, if `data` is the pinned build.
    static func verifiedSource(_ data: Data) -> String? {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest == sha256 else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// The script that starts recording, around the recorder's `source`.
    ///
    /// Evaluated with `evaluateJavaScript`, which a page's Content-Security-Policy does not restrict,
    /// so pages that would block a third-party `<script>` tag still record. The recorder is a UMD
    /// bundle; `module`, `exports` and `define` are shadowed inside our function so it always hands
    /// its export back to us -- never to the page's `window`, and never to a page's AMD loader.
    ///
    /// Privacy options mirror the browser agent's session replay defaults: all text and inputs
    /// masked, and its block/mask/ignore selectors honored, so a page is no more exposed here than it
    /// would be under its own agent.
    static func bootstrapScript(source: String, handlerName: String) -> String {
        return """
        (function(){
        var H=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.\(handlerName);
        if(!H||window.__nrWvRecording){return;}
        window.__nrWvRecording=true;
        var post=function(m){try{H.postMessage(m);}catch(e){}};
        try{
        var rrwebRecord=(function(){
        var module={exports:{}};var exports=module.exports;var define=undefined;
        \(source)
        ;
        return module.exports.record;
        })();
        var buffer=[];
        var flush=function(){
        if(!buffer.length){return;}
        var batch=buffer;buffer=[];
        try{post({kind:'events',body:JSON.stringify(batch)});}catch(e){}
        };
        rrwebRecord({
        emit:function(event){
        buffer.push(event);
        // A document is what makes the page visible in the replay; don't hold it for the interval.
        if(event.type===2){setTimeout(flush,0);}
        else if(buffer.length>=\(maxBufferedEvents)){flush();}
        },
        maskAllInputs:true,
        maskTextSelector:'*',
        blockSelector:'[data-nr-block]',
        blockClass:'nr-block',
        maskTextClass:'nr-mask',
        ignoreClass:'nr-ignore',
        inlineStylesheet:true,
        inlineImages:false,
        collectFonts:false,
        recordCanvas:false
        });
        window.__nrWvTakeFullSnapshot=function(){try{rrwebRecord.takeFullSnapshot(true);}catch(e){}};
        setInterval(flush,\(flushIntervalMs));
        window.addEventListener('pagehide',flush);
        post({kind:'recording'});
        }catch(e){post({kind:'skipped',reason:'recorder-failed ('+(e&&e.message)+')'});}
        })();
        """
    }
}

/// Downloads the recorder once per process and hands it to every WebView that needs it.
final class WebViewReplayRecorderSource {
    static let shared = WebViewReplayRecorderSource()

    private let lock = NSLock()
    private var source: String?
    private var waiting = [(String?) -> Void]()
    private var isLoading = false
    /// A failed or tampered download is not retried in this process: every attempt would fail the
    /// same way, and each costs a request per page load.
    private var failed = false

    /// Calls `completion` on the main queue with the verified source, or nil if it is unavailable.
    func load(_ completion: @escaping (String?) -> Void) {
        lock.lock()
        if let source = source {
            lock.unlock()
            DispatchQueue.main.async { completion(source) }
            return
        }
        if failed {
            lock.unlock()
            DispatchQueue.main.async { completion(nil) }
            return
        }
        waiting.append(completion)
        let shouldStart = !isLoading
        isLoading = true
        lock.unlock()

        guard shouldStart else { return }
        let task = URLSession.shared.dataTask(with: WebViewReplayRecorder.sourceURL) { [weak self] data, response, error in
            var verified: String?
            if let data = data, (response as? HTTPURLResponse)?.statusCode == 200 {
                verified = WebViewReplayRecorder.verifiedSource(data)
                if verified == nil {
                    NRLOG_AGENT_ERROR("[NR-WV-SR] recorder download did not match its pinned hash; refusing to run it")
                }
            } else {
                NRLOG_AGENT_DEBUG("[NR-WV-SR] recorder download failed: \(error?.localizedDescription ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")")
            }
            self?.finish(verified)
        }
        task.resume()
    }

    private func finish(_ loaded: String?) {
        lock.lock()
        source = loaded
        failed = loaded == nil
        isLoading = false
        let completions = waiting
        waiting.removeAll()
        lock.unlock()
        DispatchQueue.main.async {
            completions.forEach { $0(loaded) }
        }
    }
}
#endif
