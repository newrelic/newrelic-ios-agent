//
//  SessionFlowDiagramViewController.swift
//  NRTestApp
//
//  Renders the agent's session flow diagram as an SVG.
//
//  The agent accumulates a screen-flow graph for the session as MobileView events go by and hands it
//  back as Mermaid source (+[NewRelic currentSessionFlowDiagram]) — the runtime equivalent of running
//  scripts/mobileview_flow.py over an event dump. This screen is where you see that Mermaid become a
//  picture: mermaid.js runs in a WKWebView and produces the SVG.
//
//  Two things to know while using it:
//
//    * The diagram is of the session *in progress*, so it grows as you navigate. Come back after
//      wandering through the app and hit Refresh.
//    * Backgrounding the app ends the session (and creates the MobileSession event), which archives
//      the diagram. Switch the source control to a session id to read one back after the fact.
//

#if os(iOS)
import UIKit
import WebKit
import NewRelic

class SessionFlowDiagramViewController: UIViewController {

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        "Session Diagram"
    }

    // MARK: - State

    /// Which session's diagram is on screen. `.live` follows the session in progress; the archived
    /// case holds a session id handed out by the agent.
    private enum Source: Equatable {
        case live
        case archived(String)
    }

    private var source: Source = .live
    /// Session ids the agent has archived, refreshed each time the picker is opened so a session that
    /// ended while this screen was open shows up.
    private var archivedSessionIds: [String] = []
    /// Renders are dropped until mermaid.js has loaded; didFinish issues one itself, so nothing is
    /// lost by ignoring an early request.
    private var webViewIsReady = false
    /// Web view size the diagram on screen was fitted to, so a layout pass that changed nothing does
    /// not re-fit, and a rotation does.
    private var fittedSize: CGSize = .zero

    // MARK: - Views

    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // The page is local and self-contained; nothing here needs to reach the network.
        configuration.suppressesIncrementalRendering = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.accessibilityIdentifier = "session_flow_webview"
        return webView
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.accessibilityIdentifier = "session_flow_status"
        return label
    }()

    private lazy var componentsSwitch = makeSwitch(identifier: "session_flow_components")
    private lazy var breadcrumbsSwitch = makeSwitch(identifier: "session_flow_breadcrumbs")

    private lazy var sourceButton: UIButton = {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = "Live"
        configuration.buttonSize = .small
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = "session_flow_source"
        button.addTarget(self, action: #selector(chooseSource), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Session Diagram"
        view.backgroundColor = .systemBackground

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "session_flow_refresh"

        webView.navigationDelegate = self
        layout()
        loadHostPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rotation and split view change the box the diagram has to fit into. The page keeps its own
        // pan/zoom state, so this only re-derives the fit scale rather than re-rendering.
        let size = viewportSize
        guard webViewIsReady, size.width > 0, size != fittedSize else { return }
        fittedSize = size
        webView.callAsyncJavaScript("return refitDiagram(width, height);",
                                    arguments: ["width": Double(size.width),
                                                "height": Double(size.height)],
                                    in: nil,
                                    in: .page) { [weak self] result in
            if case .success(let value) = result { self?.applyScales(from: value) }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-render on every appearance: this screen's own MobileView event has just been recorded,
        // so the diagram is already one transition out of date by the time it is visible.
        refresh()
    }

    private func makeSwitch(identifier: String) -> UISwitch {
        let toggle = UISwitch()
        toggle.accessibilityIdentifier = identifier
        toggle.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return toggle
    }

    private func labelled(_ text: String, _ control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }

    private func layout() {
        let controls = UIStackView(arrangedSubviews: [
            sourceButton,
            labelled("Comp", componentsSwitch),
            labelled("Crumbs", breadcrumbsSwitch),
            UIView(),
        ])
        controls.axis = .horizontal
        controls.spacing = 10
        controls.alignment = .center

        let root = UIStackView(arrangedSubviews: [controls, webView, statusLabel])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            root.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            root.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            root.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
    }

    private func loadHostPage() {
        guard let html = Bundle.main.url(forResource: "session-flow", withExtension: "html") else {
            statusLabel.text = "session-flow.html is missing from the app bundle."
            return
        }
        // Read access to the whole directory, because the page pulls mermaid.min.js in beside itself.
        webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }

    // MARK: - Rendering

    private var currentOptions: NRSessionFlowDiagramOptions {
        let options = NRSessionFlowDiagramOptions.default()
        options.includeComponents = componentsSwitch.isOn
        options.includeBreadcrumbs = breadcrumbsSwitch.isOn
        options.title = {
            switch source {
            case .live: return "Live session"
            case .archived(let id): return "Session \(id.prefix(8))"
            }
        }()
        return options
    }

    private func currentMermaid() -> String? {
        switch source {
        case .live:
            return NewRelic.currentSessionFlowDiagram(with: currentOptions)
        case .archived(let sessionId):
            return NewRelic.flowDiagram(forSessionId: sessionId, options: currentOptions)
        }
    }

    /// The web view's size in CSS px — the box the diagram has to fit into. Points map 1:1 to CSS px
    /// at page scale 1, so the view's own bounds are the numbers the page needs; it cannot work them
    /// out itself once it has rewritten its viewport to the diagram's width.
    private var viewportSize: CGSize {
        let size = webView.bounds.size
        return size.width > 0 && size.height > 0 ? size : view.bounds.size
    }

    /// Pins the page to the scales fitViewport() just wrote into the viewport meta.
    ///
    /// WebKit adopts a new `initial-scale` on a fresh load but not when only the scale limits change:
    /// after an empty state, or a refresh taken at some other zoom, it keeps the scale it had and the
    /// diagram opens part way in. Setting the scale here is what makes "opens fully zoomed out" true
    /// on every render. `minimumZoomScale`/`maximumZoomScale` are widened first because the new
    /// viewport may not have been applied yet, and the old bounds would clamp the value away.
    private func applyScales(from jsResult: Any?) {
        guard let record = jsResult as? [String: Any],
              let fit = record["fit"] as? Double, fit > 0 else { return }
        let scrollView = webView.scrollView
        let fitScale = CGFloat(fit)
        if let max = record["max"] as? Double {
            scrollView.maximumZoomScale = CGFloat(max)
        }
        scrollView.minimumZoomScale = min(scrollView.minimumZoomScale, fitScale)
        scrollView.setZoomScale(fitScale, animated: false)
    }

    @objc private func refresh() {
        guard webViewIsReady else { return }
        let mermaid = currentMermaid() ?? ""
        let size = viewportSize
        fittedSize = size
        // callAsyncJavaScript, not evaluateJavaScript: renderDiagram is async, and evaluateJavaScript
        // cannot marshal the Promise it returns (it fails with "unsupported type" even though the
        // render itself succeeded). This awaits the promise and gets the real status back. Passing the
        // source as an argument also keeps it out of the script text, so view names containing quotes
        // or newlines need no escaping.
        webView.callAsyncJavaScript("return await renderDiagram(source, width, height);",
                                    arguments: ["source": mermaid,
                                                "width": Double(size.width),
                                                "height": Double(size.height)],
                                    in: nil,
                                    in: .page) { [weak self] result in
            guard let self else { return }
            let outcome: String
            switch result {
            case .success(let value):
                outcome = ((value as? [String: Any])?["status"] as? String) ?? "ok"
                self.applyScales(from: value)
            case .failure(let error):
                outcome = "js error: \(error.localizedDescription)"
            }
            self.updateStatus(mermaid: mermaid, outcome: outcome)
        }
    }

    private func updateStatus(mermaid: String, outcome: String) {
        let sourceName: String
        switch source {
        case .live: sourceName = "live session"
        case .archived(let id): sourceName = "session \(id.prefix(8))…"
        }
        // Counted off the node/edge syntax rather than by substring: breadcrumbs are also nodes
        // (`b3(["..."])`) with their own dashed links, and lumping them in overstated both numbers.
        // Screens declare as `vN["..."]`; a real transition's target is a `vN` or the start node.
        let lines = mermaid.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let screens = lines.filter { line in
            guard line.hasPrefix("v"), let bracket = line.firstIndex(of: "[") else { return false }
            return line[line.index(after: line.startIndex)..<bracket].allSatisfy(\.isNumber)
        }.count
        let transitions = lines.filter { line in
            guard line.contains("-->") || line.contains("-.->") else { return false }
            // `class vN slow;` has no arrow, but a breadcrumb link (`v2 -.-> b1`) does.
            return !(line.components(separatedBy: " ").last ?? "").hasPrefix("b")
        }.count
        statusLabel.text = "\(sourceName) · \(screens) screens · \(transitions) transitions · "
            + "\(mermaid.count) chars of Mermaid · render: \(outcome)"
    }

    // MARK: - Source picker

    @objc private func chooseSource() {
        archivedSessionIds = NewRelic.archivedFlowDiagramSessionIds()

        let sheet = UIAlertController(title: "Diagram source",
                                      message: archivedSessionIds.isEmpty
                                        ? "No sessions have ended yet. Background the app to end one."
                                        : nil,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Live session", style: .default) { [weak self] _ in
            self?.select(.live)
        })
        // Newest first: the session that just ended is the one you came here to look at.
        for sessionId in archivedSessionIds.reversed() {
            let title = "Archived · \(sessionId.isEmpty ? "(no id)" : String(sessionId.prefix(8)))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.select(.archived(sessionId))
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = sourceButton
        sheet.popoverPresentationController?.sourceRect = sourceButton.bounds
        present(sheet, animated: true)
    }

    private func select(_ newSource: Source) {
        source = newSource
        var configuration = sourceButton.configuration
        switch newSource {
        case .live:
            configuration?.title = "Live"
        case .archived(let id):
            configuration?.title = id.isEmpty ? "(no id)" : String(id.prefix(8))
        }
        sourceButton.configuration = configuration
        refresh()
    }
}

// MARK: - WKNavigationDelegate

extension SessionFlowDiagramViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewIsReady = true
        refresh()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        statusLabel.text = "Host page failed to load: \(error.localizedDescription)"
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        statusLabel.text = "Host page failed to load: \(error.localizedDescription)"
    }
}

#endif
