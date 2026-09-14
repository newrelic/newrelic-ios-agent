//
//  ViewsAndInteractionsViewController.swift
//  NRTestApp
//
//  Exercises the correlation between MobileView events and interaction (activity) traces.
//
//  What to watch: the live readout below refreshes 4x/second. Pushing this screen starts an
//  automatic interaction ("Display NRTestApp.ViewsAndInteractionsViewController"), so
//  `interactionId` appears — that is the id stamped on this screen's MobileView appear event.
//  Roughly half a second after the traced work stops, the trace machine's healthy timeout completes
//  the interaction and the id clears: the interaction event has been emitted, carrying this screen's
//  viewName / viewInstanceId (late binding).
//
//  Each section of the screen also reports as its own MobileView (component: true,
//  componentOf: "Views & Interactions (UIKit)"), so this screen's interaction breakdown holds a
//  MobileView row per section rather than one row for the whole screen.
//
//  Requires NRFeatureFlag_AutomaticMobileViews (and NRFeatureFlag_NewEventSystem for the view
//  attributes to reach the interaction event) — both enabled in AppDelegate.
//

import UIKit
import NewRelic

class ViewsAndInteractionsViewController: UIViewController {

    private var refreshTimer: Timer?

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        Self.screenName
    }

    private static let screenName = "Views & Interactions (UIKit)"

    // MARK: - Component-level views

    /// The sections of this screen, each tracked as a view in its own right via a child view
    /// controller (see MobileViewComponentController).
    ///
    /// None of them opens an interaction — each records a load segment against the interaction
    /// already covering this screen, which is the automatic one the method profiler starts for the
    /// push. That is what puts several `Method/MobileView/<component>` rows into a *single*
    /// interaction's breakdown table, instead of the one row naming the screen.
    private enum Component: String {
        case intro          = "ViewsAndInteractions.Intro"
        case forwardReadout = "ViewsAndInteractions.ForwardReadout"
        case reverseReadout = "ViewsAndInteractions.ReverseReadout"
        case actions        = "ViewsAndInteractions.Actions"
        case callLog        = "ViewsAndInteractions.CallLog"
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .systemBackground
#endif
        title = "Views × Interactions"
        buildUI()

        // Traced work during the screen load, so the automatic interaction accumulates nodes and
        // clears activity_trace_min_utilization — otherwise the trace payload (the code-level
        // detail) is dropped and only the interaction event survives.
        doTracedWork()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refreshReadout()
        }
        refreshReadout()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Actions

    /// Runs work through instrumented classes (JSONSerialization) plus a network request, both of
    /// which become child nodes of whichever interaction is currently open.
    private func doTracedWork() {
        for index in 0..<25 {
            let payload: [String: Any] = ["index": index, "screen": "views-and-interactions"]
            if let data = try? JSONSerialization.data(withJSONObject: payload) {
                _ = try? JSONSerialization.jsonObject(with: data)
            }
        }

        guard let url = URL(string: "https://www.newrelic.com") else { return }
        URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
    }

    @objc private func tracedWorkTapped() {
        doTracedWork()
        append("traced work (JSON x25 + 1 request)")
    }

    @objc private func startCustomInteractionTapped() {
        NewRelic.startInteraction(withName: "Checkout Flow")
        doTracedWork()
        append("startInteraction(\"Checkout Flow\") — readout should show its new id")
    }

    @objc private func breadcrumbTapped() {
        _ = NewRelic.recordBreadcrumb("cta_tapped", attributes: ["cta": "buy-now"])
        append("recordBreadcrumb — carries currentView/previousView")
    }

    @objc private func setCurrentViewTapped() {
        NewRelic.setCurrentView("Checkout", attributes: ["source": "views-and-interactions-demo"])
        append("setCurrentView(\"Checkout\") — MobileView event carries the running interactionId")
    }

    // MARK: - UI

    private let interactionLabel = ViewsAndInteractionsViewController.monospacedLabel()
    private let viewLabel = ViewsAndInteractionsViewController.monospacedLabel()
    private let logLabel = ViewsAndInteractionsViewController.monospacedLabel()
    private var log: [String] = []

    private static func monospacedLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        return label
    }

    private func buildUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -12),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        let intro = UILabel()
        intro.numberOfLines = 0
        intro.font = .preferredFont(forTextStyle: .callout)
        intro.text = """
            This screen's MobileView events carry the id of the interaction that was running when \
            they were emitted, and that interaction's event carries this screen's viewName and \
            viewInstanceId — read at completion, so a screen load is attributed to the screen that \
            loaded rather than the one being left.
            """
        addComponent(.intro, views: [intro], to: stack)

        addComponent(.forwardReadout,
                     views: [sectionHeader("On MobileView events (forward)"), interactionLabel],
                     to: stack)

        addComponent(.reverseReadout,
                     views: [sectionHeader("On the interaction event at completion (reverse)"), viewLabel],
                     to: stack)

        addComponent(.actions, views: [
            button("Do traced work", #selector(tracedWorkTapped)),
            button("Start custom interaction", #selector(startCustomInteractionTapped)),
            button("Record breadcrumb", #selector(breadcrumbTapped)),
            button("setCurrentView(\"Checkout\")", #selector(setCurrentViewTapped)),
        ], to: stack)

        addComponent(.callLog,
                     views: [sectionHeader("Call log (most recent first)"), logLabel],
                     to: stack)
    }

    private func addComponent(_ component: Component, views: [UIView], to stack: UIStackView) {
        addMobileViewComponent(component.rawValue, of: Self.screenName, views: views, to: stack)
    }

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func refreshReadout() {
        interactionLabel.text = MobileViewCorrelationProbe.describe(
            MobileViewCorrelationProbe.interactionAttributes())
        viewLabel.text = MobileViewCorrelationProbe.describe(
            MobileViewCorrelationProbe.viewAttributes())
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 8 { log.removeLast() }
        logLabel.text = log.joined(separator: "\n")
        refreshReadout()
    }
}
