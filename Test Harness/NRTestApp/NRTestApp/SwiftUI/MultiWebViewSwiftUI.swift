//
//  MultiWebViewSwiftUI.swift
//  NRTestApp
//
//  Exercises WebView session replay with four WebViews on screen at once: each is its own `<iframe>`
//  in the native replay, with its own page attached under it.
//

#if os(iOS)
import SwiftUI
import WebKit

struct MultiWebViewSwiftUI: View {
    /// The top pair shares one configuration, and so one WKUserContentController: the replay bridge
    /// installs its message handler once per controller and tells the two WebViews apart by
    /// `message.webView`. The bottom pair each get their own.
    @State private var sharedConfiguration = WKWebViewConfiguration()
    /// Bumped by "Reload all", which navigates every WebView at the same moment.
    @State private var reloadToken = 0

    private static let colors = ["#ffd6d6", "#d6f5d6", "#d6e4ff", "#fff1c2"]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                cell(0, configuration: sharedConfiguration)
                cell(1, configuration: sharedConfiguration)
            }
            HStack(spacing: 8) {
                cell(2, configuration: WKWebViewConfiguration())
                cell(3, configuration: WKWebViewConfiguration())
            }
        }
        .padding(8)
        .navigationTitle("Multiple Web Views")
        .toolbar {
            Button("Reload all") { reloadToken += 1 }
                .accessibilityIdentifier("multiWebViewReloadAll")
        }
        .NRTrackView(name: "MultiWebViewSwiftUI")
    }

    private func cell(_ index: Int, configuration: WKWebViewConfiguration) -> some View {
        MultiWebViewCell(html: Self.page(number: index + 1, color: Self.colors[index]),
                         configuration: configuration,
                         reloadToken: reloadToken)
            .accessibilityIdentifier("multiWebView-\(index + 1)")
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// A self-contained page that changes on its own every second and on every tap, so each WebView
    /// has a stream of mutations of its own. The color tells the four apart in the replay, where text
    /// is masked.
    static func page(number: Int, color: String) -> String {
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>WebView \(number)</title>
        <style>
          body { font-family: -apple-system, sans-serif; margin: 12px; background: \(color); color: #1d252c; }
          h1 { font-size: 18px; margin: 0 0 8px; }
          .big { font-size: 32px; font-weight: 700; }
          button { font-size: 15px; padding: 8px 12px; border: 0; border-radius: 8px; background: #1d252c; color: #fff; }
        </style>
        </head>
        <body>
          <h1>WebView \(number)</h1>
          <div>Ticks: <span id="ticks" class="big">0</span></div>
          <p><button id="tap">Tap</button> <span id="taps">0</span> taps</p>
          <p>Loaded at <span id="loaded"></span></p>
          <script>
            var ticks = 0, taps = 0;
            document.getElementById('loaded').textContent = new Date().toLocaleTimeString();
            setInterval(function () { document.getElementById('ticks').textContent = ++ticks; }, 1000);
            document.getElementById('tap').onclick = function () { document.getElementById('taps').textContent = ++taps; };
          </script>
        </body>
        </html>
        """
    }
}

/// A plain WKWebView showing `html`, reloaded whenever `reloadToken` changes.
private struct MultiWebViewCell: UIViewRepresentable {
    let html: String
    let configuration: WKWebViewConfiguration
    let reloadToken: Int

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        load(into: webView)
        context.coordinator.reloadToken = reloadToken
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.reloadToken != reloadToken else { return }
        context.coordinator.reloadToken = reloadToken
        load(into: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var reloadToken = 0
    }

    private func load(into webView: WKWebView) {
        // A real https origin, as in WebViewSwiftUI, so the page has working storage.
        webView.loadHTMLString(html, baseURL: URL(string: "https://example.com/"))
    }
}
#endif
