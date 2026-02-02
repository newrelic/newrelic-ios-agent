//
//  NRWKWebViewRRWebRecorder.swift
//  NewRelic
//
//  Created by Chris Dillard on 1/26/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import WebKit
@_implementationOnly import NewRelicPrivate

@objc public class NRWKWebViewRRWebRecorder: NSObject {
    
    // Check if the script has been injected already
    private static let scriptMessageHandlerName = "rrwebEvent"
    
    @objc public static func injectRRWeb(into webView: WKWebView) {
        
        // Only inject if recording is enabled (check SessionReplayManager via Bridge or shared instance if available)
        // For now, we follow the pattern of injecting and controlling via JS.
        // Actually, we should check if we are capturing.
        
        // Load rrweb.min.js
        guard let rrwebPath = NewRelicBundle.bundle().path(forResource: "rrweb.min", ofType: "js") else {
             // Fallback or log error. 
             // Since we might be in a different bundle structure during dev, try main bundle too.
             return
        }
        
        do {
            let rrwebContent = try String(contentsOfFile: rrwebPath, encoding: .utf8)
            
            // Initialization script
            // matches Android logic:
            // 1. Check if already initialized
            // 2. record() with emit function sending to message handler
            let initScript = """
            (function() {
              if (window.rrwebRecorder) return;
              if (typeof rrweb === 'undefined') return;

              window.rrwebRecorder = rrweb.record({
                emit: function(event) {
                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.rrwebEvent) {
                      window.webkit.messageHandlers.rrwebEvent.postMessage(JSON.stringify(event));
                  }
                },
                checkoutEveryNms: 10000,
                // maskAllInputs: true, // TODO: Configurable
                inlineStylesheet: true,
                inlineImages: false,
                sampling: {
                  mousemove: true,
                  mouseInteraction: true,
                  scroll: 150,
                  input: 'last'
                }
              });
              console.log("New Relic Session Replay - WebView Recorder started");
            })();
            """
            
            let fullScript = rrwebContent + "\n" + initScript
            
            let userScript = WKUserScript(source: fullScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            
            webView.configuration.userContentController.addUserScript(userScript)
            
            // Add Message Handler
            let handler = NRWKWebViewScriptMessageHandler()
            webView.configuration.userContentController.add(handler, name: scriptMessageHandlerName)
            
        } catch {
            print("New Relic: Failed to load rrweb script: \(error)")
        }
    }
}

class NRWKWebViewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "rrwebEvent", let jsonString = message.body as? String else {
            return
        }

        let agent = NewRelicAgentInternal.sharedInstance()

        // Pass the webview reference along with the JSON event
        if let webView = message.webView {
            agent?.recordSessionReplayEvent(jsonString, from: webView)
        }
    }
}

// Helper to find the bundle (placeholder)
class NewRelicBundle {
    static func bundle() -> Bundle {
        // Implementation depends on how the bundle is built. 
        // For now returning Bundle(for: self) or main.
        return Bundle(for: NewRelic.self)
    }
}
