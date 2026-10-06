//
//  WebViewCorpusSwiftUI.swift
//  NRTestApp
//
//  Real third-party pages for WebView session replay: large documents, heavy mutation, shadow DOM,
//  canvas, and a page with its own browser agent. Each opens full screen in a plain WKWebView, with
//  the page's size measured on load and an optional auto-scroll to keep it producing changes.
//

#if os(iOS)
import SwiftUI
import WebKit

struct CorpusPage: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case news = "News"
        case shopping = "Shopping"
        case singlePage = "Single-page apps"
        case longDocument = "Long documents"
        case heavyMutation = "Ad-heavy / infinite scroll"
        case shadowDOM = "Shadow DOM / web components"
        case canvas = "Map / canvas"
        case ownAgent = "Page with its own NR agent"
        case captured = "Captured snapshots (multi-MB, local)"

        var id: String { rawValue }
    }

    let id: String
    let title: String
    let url: URL
    let category: Category
    /// What the page exercises in the replay.
    let note: String

    /// Where `Tests/WebViewReplayBench/corpus/serve.sh` serves the captured snapshots.
    static let capturedHost = "http://localhost:8765"

    private static func captured(_ id: String, _ title: String, _ note: String) -> CorpusPage {
        CorpusPage(id: "cap-\(id)", title: title, url: URL(string: "\(capturedHost)/\(id).html")!, category: .captured, note: note)
    }

    static let all: [CorpusPage] = [
        .init(id: "cnn", title: "CNN", url: URL(string: "https://www.cnn.com")!, category: .news,
              note: "Large homepage, autoplay video, ad slots"),
        .init(id: "guardian", title: "The Guardian", url: URL(string: "https://www.theguardian.com/international")!, category: .news,
              note: "Long front page, many images, consent banner"),
        .init(id: "amazon", title: "Amazon search", url: URL(string: "https://www.amazon.com/s?k=usb+c+cable")!, category: .shopping,
              note: "Dense product grid, carousels, inline styles"),
        .init(id: "allbirds", title: "Allbirds (Shopify)", url: URL(string: "https://www.allbirds.com/collections/mens")!, category: .shopping,
              note: "Shopify storefront, lazy-loaded collection"),
        .init(id: "airbnb", title: "Airbnb search", url: URL(string: "https://www.airbnb.com/s/New-York--NY/homes")!, category: .singlePage,
              note: "React SPA, client-side routing, map + list"),
        .init(id: "youtube", title: "YouTube (mobile)", url: URL(string: "https://m.youtube.com")!, category: .singlePage,
              note: "Polymer SPA, constant thumbnail mutations"),
        .init(id: "wikipedia", title: "Wikipedia: Falcon 9 launches",
              url: URL(string: "https://en.wikipedia.org/wiki/List_of_Falcon_9_and_Falcon_Heavy_launches")!, category: .longDocument,
              note: "Huge static document: tens of thousands of nodes"),
        .init(id: "mdn", title: "MDN: HTML elements", url: URL(string: "https://developer.mozilla.org/en-US/docs/Web/HTML/Element")!,
              category: .longDocument, note: "Long reference page, large stylesheets"),
        .init(id: "dailymail", title: "Daily Mail", url: URL(string: "https://www.dailymail.co.uk/home/index.html")!, category: .heavyMutation,
              note: "Very large DOM, heavy ads, endless page"),
        .init(id: "reddit", title: "Reddit r/popular", url: URL(string: "https://www.reddit.com/r/popular/")!, category: .shadowDOM,
              note: "shreddit web components with shadow roots, infinite scroll"),
        .init(id: "googlemaps", title: "Google Maps", url: URL(string: "https://www.google.com/maps/@40.7128,-74.006,13z")!, category: .canvas,
              note: "WebGL/canvas map; canvas isn't recorded, so expect it blank"),
        .init(id: "newrelic", title: "newrelic.com", url: URL(string: "https://newrelic.com")!, category: .ownAgent,
              note: "Runs its own browser agent: the existing-agent path"),
        captured("wikipedia-falcon9", "Wikipedia: Falcon 9 launches", "4.6 MB, ~24k elements, huge tables"),
        captured("guardian-front", "The Guardian front page", "3 MB, inlined images and CSS"),
        captured("github-linux", "GitHub: torvalds/linux", "6.3 MB, app-style markup and embedded data"),
        captured("stackoverflow-q", "Stack Overflow question", "6.8 MB, ~11k elements, many code blocks"),
        captured("amazon-usb-c", "Amazon search results", "9.8 MB, ~12k elements, inline styles"),
        captured("dailymail-home", "Daily Mail home", "15.5 MB, ~9k elements, ads and images"),
        captured("cnn-home", "CNN home (extreme)", "106 MB of inlined media: far past any chunk cap"),
    ]
}

struct WebViewCorpusSwiftUI: View {
    @State private var customURL = ""

    var body: some View {
        List {
            ForEach(CorpusPage.Category.allCases) { category in
                Section(category.rawValue) {
                    ForEach(CorpusPage.all.filter { $0.category == category }) { page in
                        NavigationLink(destination: WebViewCorpusPageView(page: page)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(page.title)
                                Text(page.note).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .accessibilityIdentifier("corpusPage-\(page.id)")
                    }
                }
            }
            Section("Custom URL") {
                TextField("https://…", text: $customURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("corpusCustomURL")
                if let page = customPage {
                    NavigationLink(destination: WebViewCorpusPageView(page: page)) {
                        Text("Open \(page.url.host ?? page.url.absoluteString)")
                    }
                    .accessibilityIdentifier("corpusOpenCustomURL")
                }
            }
        }
        .navigationTitle("Web View Corpus")
        .NRTrackView(name: "WebViewCorpusSwiftUI")
    }

    private var customPage: CorpusPage? {
        let text = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let url = URL(string: text.contains("://") ? text : "https://" + text),
              url.host != nil else {
            return nil
        }
        return CorpusPage(id: "custom", title: url.host ?? "Custom", url: url, category: .news, note: "")
    }
}

/// One corpus page, full screen.
struct WebViewCorpusPageView: View {
    let page: CorpusPage
    @StateObject private var model = CorpusWebViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Text(model.summary)
                .font(.caption.monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .accessibilityIdentifier("corpusMetrics")
            CorpusWebView(url: page.url, model: model)
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(model.isAutoScrolling ? "Stop" : "Scroll") { model.toggleAutoScroll() }
                    .accessibilityIdentifier("corpusAutoScroll")
                Button("Measure") { model.measure() }
                    .accessibilityIdentifier("corpusMeasure")
                Button { model.reload() } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityIdentifier("corpusReload")
            }
        }
        .onDisappear { model.stopAutoScroll() }
        // One name per page, so each is easy to find in the replay timeline.
        .NRTrackView(name: "WebViewCorpus-\(page.id)")
    }
}

/// A plain WKWebView. Nothing replay-specific happens here: the agent's WKWebView instrumentation
/// installs the replay bridge when the view is created.
private struct CorpusWebView: UIViewRepresentable {
    let url: URL
    let model: CorpusWebViewModel

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.accessibilityIdentifier = "corpusWebView"
        webView.allowsBackForwardNavigationGestures = true
        model.attach(webView)
        model.load(url)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

final class CorpusWebViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var summary = "Loading…"
    @Published private(set) var isAutoScrolling = false

    private weak var webView: WKWebView?
    private var autoScrollTimer: Timer?

    /// How often auto-scroll moves the page. Each step triggers the page's lazy loading and scroll
    /// handlers, so the recorder keeps producing changes.
    static let autoScrollInterval: TimeInterval = 1.5

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
    }

    func load(_ url: URL) {
        webView?.load(URLRequest(url: url))
    }

    func reload() {
        webView?.reload()
    }

    /// Measures the page now. Done on load and on request only, never on a timer: walking every
    /// node is work in the page that would skew the replay's own cost.
    func measure() {
        webView?.evaluateJavaScript(Self.metricsScript) { [weak self] result, error in
            guard let self = self else { return }
            if let metrics = result as? [String: Any] {
                self.summary = Self.describe(metrics)
            } else if let error = error {
                self.summary = "Couldn't measure: \(error.localizedDescription)"
            }
        }
    }

    func toggleAutoScroll() {
        isAutoScrolling ? stopAutoScroll() : startAutoScroll()
    }

    private func startAutoScroll() {
        stopAutoScroll()
        isAutoScrolling = true
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: Self.autoScrollInterval, repeats: true) { [weak self] _ in
            self?.webView?.evaluateJavaScript(Self.scrollScript, completionHandler: nil)
        }
    }

    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        isAutoScrolling = false
    }

    deinit {
        autoScrollTimer?.invalidate()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        summary = "Loading \(webView.url?.host ?? "")…"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        measure()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        summary = "Failed: \(error.localizedDescription)"
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        summary = "Failed: \(error.localizedDescription)"
    }

    // MARK: - Scripts

    /// Scrolls most of a screen down, back to the top at the end of a finite page.
    static let scrollScript = """
    (function(){var y=window.scrollY+window.innerHeight;
    if(y>=document.documentElement.scrollHeight-2){window.scrollTo(0,0);}
    else{window.scrollBy(0,Math.round(window.innerHeight*0.7));}})();
    """

    /// The page's size as the replay sees it. `transferBytes` undercounts: cross-origin resources
    /// without Timing-Allow-Origin, and cached ones, report 0. `pageAgent` ignores the observation
    /// agent the replay bridge itself may inject.
    static let metricsScript = """
    (function(){
    var all=document.getElementsByTagName('*');var shadow=0;
    for(var i=0;i<all.length;i++){if(all[i].shadowRoot){shadow++;}}
    var res=performance.getEntriesByType('resource');var bytes=0;
    for(var j=0;j<res.length;j++){bytes+=res[j].transferSize||0;}
    var nav=performance.getEntriesByType('navigation')[0];if(nav){bytes+=nav.transferSize||0;}
    var key=window.NREUM&&window.NREUM.info&&window.NREUM.info.licenseKey;
    return {nodes:all.length,htmlBytes:document.documentElement.outerHTML.length,transferBytes:bytes,
    iframes:document.getElementsByTagName('iframe').length,canvases:document.getElementsByTagName('canvas').length,
    shadowRoots:shadow,loadMs:(nav&&nav.loadEventEnd>0)?Math.round(nav.loadEventEnd):-1,
    pageAgent:!!(key&&key!=='NRWV_OBSERVATION_MODE')};
    })();
    """

    private static func describe(_ metrics: [String: Any]) -> String {
        func int(_ key: String) -> Int { (metrics[key] as? NSNumber)?.intValue ?? 0 }
        func mb(_ bytes: Int) -> String { String(format: "%.1f MB", Double(bytes) / 1_000_000) }
        var parts = ["\(int("nodes").formatted()) nodes",
                     "HTML \(mb(int("htmlBytes")))",
                     "≥\(mb(int("transferBytes"))) transferred"]
        let loadMs = int("loadMs")
        if loadMs > 0 {
            parts.append(String(format: "load %.1f s", Double(loadMs) / 1000))
        }
        parts.append("\(int("iframes")) iframes · \(int("canvases")) canvas · \(int("shadowRoots")) shadow roots")
        if (metrics["pageAgent"] as? NSNumber)?.boolValue == true {
            parts.append("page has its own NR agent")
        }
        return parts.joined(separator: " · ")
    }
}
#endif
