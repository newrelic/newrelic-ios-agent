//
//  MobileViewModalsViewController.swift
//  NRTestApp
//
//  The UIKit counterpart to SwiftUI/ModalsDemoView.swift.
//
//  Modally presented view controllers need no special handling to be tracked: NRMAMobileViewTracker
//  swizzles UIViewController lifecycle, so a presented VC gets its MobileView events from
//  viewDidAppear / viewDidDisappear exactly like a pushed one. What this screen exists to show is
//  what happens to the *presenter* underneath, which is not uniform:
//
//    .fullScreen              → the presenter's viewDidDisappear DOES run, so the presenter emits a
//                               disappear event (with timeVisible) when it is covered.
//    .pageSheet / .formSheet  → the presenter's viewDidDisappear does NOT run. It stays "appeared"
//    / .popover                 as far as the tracker is concerned, so no disappear event fires and
//                               the time spent under the modal accumulates into the presenter's own
//                               timeVisible, which is only reported when it finally goes away.
//
//  Either way the modal's own appear event carries the presenter as its `previousView` referrer.
//  The live counters below make the asymmetry observable: present each style and watch whether this
//  screen's disappear count moves.
//

#if os(iOS)
import UIKit

class MobileViewModalsViewController: UIViewController {

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        "Modals (UIKit)"
    }

    // MARK: - Lifecycle counters
    //
    // One MobileView event is emitted per lifecycle call, so these counters are a direct readout of
    // how many appear / disappear events this screen has produced.

    private var appearCount = 0
    private var disappearCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Modals (UIKit)"
        buildUI()
        refreshCounters()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearCount += 1
        refreshCounters()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disappearCount += 1
        // Not visible while it happens — read it on the way back in.
        refreshCounters()
    }

    // MARK: - Presentation

    private func presentModal(style: UIModalPresentationStyle, named name: String, from source: UIView?) {
        let modal = MobileViewPresentedModalViewController(styleName: name)
        modal.modalPresentationStyle = style

        if style == .popover {
            // Without this a popover collapses to a sheet on iPhone, which would make this button a
            // duplicate of the pageSheet one rather than a distinct presentation to observe.
            modal.popoverPresentationController?.sourceView = source ?? view
            modal.popoverPresentationController?.sourceRect = source?.bounds ?? view.bounds
            modal.popoverPresentationController?.delegate = modal
        }

        append("present(.\(name)) — modal emits an appear event; watch whether THIS screen's disappear count moves")
        present(modal, animated: true)
    }

    @objc private func pageSheetTapped(_ sender: UIButton) {
        presentModal(style: .pageSheet, named: "pageSheet", from: sender)
    }

    @objc private func formSheetTapped(_ sender: UIButton) {
        presentModal(style: .formSheet, named: "formSheet", from: sender)
    }

    @objc private func popoverTapped(_ sender: UIButton) {
        presentModal(style: .popover, named: "popover", from: sender)
    }

    @objc private func fullScreenTapped(_ sender: UIButton) {
        presentModal(style: .fullScreen, named: "fullScreen", from: sender)
    }

    // MARK: - UI

    private let counterLabel = MobileViewModalsViewController.monospacedLabel()
    private let logLabel = MobileViewModalsViewController.monospacedLabel()
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
            A presented view controller is tracked like any other — the swizzle keys off \
            viewDidAppear. What differs is the presenter underneath: .fullScreen sends this screen \
            through viewDidDisappear (so it emits a disappear event and closes out its timeVisible), \
            while .pageSheet, .formSheet and .popover do not. Present each style and watch the \
            counters.
            """
        stack.addArrangedSubview(intro)

        stack.addArrangedSubview(sectionHeader("This screen's lifecycle (= its MobileView events)"))
        stack.addArrangedSubview(counterLabel)

        stack.addArrangedSubview(sectionHeader("Present modally"))
        stack.addArrangedSubview(button("pageSheet — presenter should NOT disappear", #selector(pageSheetTapped)))
        stack.addArrangedSubview(button("formSheet — presenter should NOT disappear", #selector(formSheetTapped)))
        stack.addArrangedSubview(button("popover — presenter should NOT disappear", #selector(popoverTapped)))
        stack.addArrangedSubview(button("fullScreen — presenter SHOULD disappear", #selector(fullScreenTapped)))

        stack.addArrangedSubview(sectionHeader("Call log (most recent first)"))
        stack.addArrangedSubview(logLabel)
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
        button.titleLabel?.numberOfLines = 0
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func refreshCounters() {
        counterLabel.text = """
            viewDidAppear    = \(appearCount)   (appeared=true events)
            viewDidDisappear = \(disappearCount)   (appeared=false events, carry timeVisible)
            """
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 8 { log.removeLast() }
        logLabel.text = log.joined(separator: "\n")
    }
}

// MARK: - The presented screen

/// The modal itself. Named via `nrMobileViewName()` so each presentation style is distinguishable in
/// the event stream, and tagged with the style through `nrMobileViewAttributes()`.
class MobileViewPresentedModalViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    private let styleName: String

    init(styleName: String) {
        self.styleName = styleName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc func nrMobileViewName() -> String? {
        "Modals · Presented \(styleName)"
    }

    @objc func nrMobileViewAttributes() -> [String: Any]? {
        ["presentationStyle": styleName, "presentedModally": true]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        preferredContentSize = CGSize(width: 320, height: 260)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])

        let titleLabel = UILabel()
        titleLabel.text = ".\(styleName)"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        stack.addArrangedSubview(titleLabel)

        let body = UILabel()
        body.numberOfLines = 0
        body.textAlignment = .center
        body.font = .preferredFont(forTextStyle: .body)
        body.text = """
            This modal emits its own MobileView events as \
            "Modals · Presented \(styleName)", with the presenting screen recorded as its \
            previousView referrer.
            """
        stack.addArrangedSubview(body)

        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        stack.addArrangedSubview(dismissButton)
    }

    @objc private func dismissTapped() {
        dismiss(animated: true)
    }

    // Keep .popover a real popover on iPhone rather than letting it adapt into a sheet.
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
#endif
