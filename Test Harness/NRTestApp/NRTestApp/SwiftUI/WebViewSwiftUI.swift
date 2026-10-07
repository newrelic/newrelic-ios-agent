//
//  WebViewSwiftUI.swift
//  NRTestApp
//
//  Exercises WebView session replay: the agent injects the browser agent in observation mode and
//  merges the page's own rrweb stream into the native replay as nested-player plugin events.
//

#if os(iOS)
import SwiftUI
import WebKit

struct WebViewSwiftUI: View {
    enum Page: String, CaseIterable, Identifiable {
        case local = "Local"
        case example = "example.com"
        case newRelic = "newrelic.com"

        var id: String { rawValue }
    }

    @State private var page: Page = .local

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()
            .accessibilityIdentifier("webViewPagePicker")

            SwiftUIWebView(page: page)
        }
        .navigationTitle("Web View (SwiftUI)")
        .NRTrackView(name: "WebViewSwiftUI")
    }
}

/// A plain WKWebView wrapped for SwiftUI. Nothing replay-specific happens here: the agent's WKWebView
/// instrumentation installs the replay bridge when the view is created.
struct SwiftUIWebView: UIViewRepresentable {
    let page: WebViewSwiftUI.Page

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.accessibilityIdentifier = "swiftUIWebView"
        load(page, into: webView)
        context.coordinator.page = page
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.page != page else { return }
        context.coordinator.page = page
        load(page, into: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var page: WebViewSwiftUI.Page?
    }

    private func load(_ page: WebViewSwiftUI.Page, into webView: WKWebView) {
        switch page {
        case .local:
            // A real https origin, so the browser agent has working storage for its session.
            webView.loadHTMLString(Self.localPage, baseURL: URL(string: "https://example.com/"))
        case .example:
            webView.load(URLRequest(url: URL(string: "https://example.com")!))
        case .newRelic:
            // Carries its own New Relic Browser agent, so replay injection should be skipped.
            webView.load(URLRequest(url: URL(string: "https://newrelic.com")!))
        }
    }

    /// Self-contained page with something to interact with, so the replay has mutations to show.
    static let localPage = """
    <!doctype html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>NR WebView Replay Test</title>
    <style>
      body { font-family: -apple-system, sans-serif; margin: 16px; background: #f4f6f8; color: #1d252c; }
      h1 { font-size: 22px; }
      .card { background: #fff; border-radius: 12px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,.12); }
      button { font-size: 17px; padding: 10px 16px; border: 0; border-radius: 8px; background: #1ce783; color: #1d252c; }
      #count { font-size: 40px; font-weight: 700; }
      li { padding: 6px 0; }
      .flash { animation: flash 1s; }
      @keyframes flash { from { background: #ffe58f; } to { background: transparent; } }
    </style>
    </head>
    <body>
      <h1>WebView Session Replay</h1>
      <div class="card">
        <div id="count">0</div>
        <button id="increment">Tap to increment</button>
      </div>
      <div class="card">
        <input id="name" placeholder="Type something" style="font-size:17px;padding:8px;width:90%">
        <p>You typed: <span id="echo"></span></p>
      </div>
      <div class="card">
        <button id="add">Add item</button>
        <ul id="items"></ul>
      </div>
      <div class="card">Clock: <span id="clock"></span></div>
      <script>
        var count = 0;
        document.getElementById('increment').onclick = function () {
          count++;
          var el = document.getElementById('count');
          el.textContent = count;
          el.className = 'flash';
          setTimeout(function () { el.className = ''; }, 1000);
        };
        document.getElementById('name').oninput = function (e) {
          document.getElementById('echo').textContent = e.target.value;
        };
        document.getElementById('add').onclick = function () {
          var li = document.createElement('li');
          li.textContent = 'Item ' + (document.querySelectorAll('#items li').length + 1);
          document.getElementById('items').appendChild(li);
        };
        setInterval(function () {
          document.getElementById('clock').textContent = new Date().toLocaleTimeString();
        }, 1000);
      </script>
    </body>
    </html>
    """
}
#endif
