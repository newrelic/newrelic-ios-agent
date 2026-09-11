//
//  MobileViewRestartedViewController.swift
//  NRTestApp
//
//  Exercises two documented behaviors that nothing else in the harness reaches: the `restarted`
//  attribute, and the empty-string return from `nrMobileViewName()`.
//
//  ─── Why a retained instance ─────────────────────────────────────────────────────────────────
//
//  `restarted` is per *instance*, not per class or per view name — the tracker records it as an
//  associated object on the view controller itself. An ordinary push → pop → push allocates a fresh
//  view controller each time, so each one is on its first appearance and every event reports
//  restarted = false. This screen therefore holds ONE child instance and pushes that same object
//  repeatedly, which is what a re-appearance actually looks like to the tracker.
//
//  What to expect from the child's events, per push:
//
//    push #1  appear     no `restarted` key at all — the UIKit producer only puts it on disappear
//             disappear  restarted = false, loadTime = the real viewDidLoad → viewDidAppear span
//
//    push #2+ appear     `loadTime` is OMITTED, not zero. viewDidLoad does not run again, and the
//                        load timestamp was cleared on the previous disappear, so there is no span
//                        to report — "never observed" rather than "took no time". For the same
//                        reason no MobileView/<viewName> segment is added to the covering
//                        interaction's breakdown on a re-appearance.
//             disappear  restarted = true, loadTime = 0
//
//  ─── Why an empty name ──────────────────────────────────────────────────────────────────────
//
//  `nrMobileViewName()` has three distinct return values and the harness only covered two of them:
//  a non-empty string renames the view, and nil ignores it entirely (see
//  MobileViewIgnoredViewController). An empty string is the third: it falls back to the demangled
//  class name, the pre-hook behavior. The second child here returns "" so that fallback is
//  observable — its events should arrive named "MobileViewLegacyNamedViewController".
//

#if os(iOS)
import UIKit

class MobileViewRestartedViewController: UIViewController {

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        "Restarted (UIKit)"
    }

    // MARK: - The children
    //
    // Retained for the lifetime of this screen. Pushing the same object again is what produces a
    // re-appearance; allocating a new one would not.

    private lazy var retainedChild = MobileViewRestartedChildViewController()
    private lazy var legacyNamedChild = MobileViewLegacyNamedViewController()

    private var pushCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Restarted (UIKit)"
        buildUI()
        refreshReadout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Coming back from the child — the readout should reflect the push that just ended.
        refreshReadout()
    }

    // MARK: - Actions

    @objc private func pushRetainedTapped() {
        pushCount += 1
        let expectation = pushCount == 1
            ? "expect: appear carries a real loadTime; disappear restarted=false"
            : "expect: appear omits loadTime (no reload); disappear restarted=true, loadTime=0"
        append("push #\(pushCount) of the same instance — \(expectation)")
        navigationController?.pushViewController(retainedChild, animated: true)
    }

    @objc private func pushLegacyNamedTapped() {
        append("push legacy-named child — nrMobileViewName() returns \"\", so events should be named after the class")
        navigationController?.pushViewController(legacyNamedChild, animated: true)
    }

    // MARK: - UI

    private let readoutLabel = MobileViewRestartedViewController.monospacedLabel()
    private let logLabel = MobileViewRestartedViewController.monospacedLabel()
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
            `restarted` is tracked per view-controller instance, so pushing a freshly allocated \
            screen always reports restarted = false. Push the retained child below more than once \
            to see it flip to true — and to see loadTime disappear from the appear event, because \
            viewDidLoad does not run a second time.
            """
        stack.addArrangedSubview(intro)

        stack.addArrangedSubview(sectionHeader("Child lifecycle (recorded by the child itself)"))
        stack.addArrangedSubview(readoutLabel)

        stack.addArrangedSubview(sectionHeader("Push the same instance again"))
        stack.addArrangedSubview(button("Push retained child (restarted / loadTime)", #selector(pushRetainedTapped)))

        stack.addArrangedSubview(sectionHeader("Empty nrMobileViewName() → class-name fallback"))
        stack.addArrangedSubview(button("Push legacy-named child (returns \"\")", #selector(pushLegacyNamedTapped)))

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

    private func refreshReadout() {
        readoutLabel.text = """
            viewDidLoad     = \(retainedChild.loadCount)   (only ever 1 — the instance is reused)
            viewDidAppear   = \(retainedChild.appearCount)
            expected restarted on next disappear = \(retainedChild.appearCount > 1)
            """
    }

    private func append(_ line: String) {
        log.insert(line, at: 0)
        if log.count > 8 { log.removeLast() }
        logLabel.text = log.joined(separator: "\n")
    }
}

// MARK: - The reused child

/// Pushed repeatedly as the same object, so its second and later appearances are re-appearances as
/// far as NRMAMobileViewTracker is concerned. Counts its own lifecycle calls so the parent can show
/// that viewDidLoad runs exactly once no matter how many times the screen is shown.
class MobileViewRestartedChildViewController: UIViewController {

    private(set) var loadCount = 0
    private(set) var appearCount = 0

    @objc func nrMobileViewName() -> String? {
        "Restarted · Reused Child"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCount += 1
        view.backgroundColor = .systemBackground
        title = "Reused Child"
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        appearCount += 1
        refresh()
    }

    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private func buildUI() {
        let intro = UILabel()
        intro.numberOfLines = 0
        intro.font = .preferredFont(forTextStyle: .body)
        intro.translatesAutoresizingMaskIntoConstraints = false
        intro.text = """
            This is the same object each time. Go back and push again: viewDidLoad stays at 1, so on \
            the second and later appearances the agent has no load span to report — the appear event \
            omits loadTime entirely, and the disappear event reports restarted = true.
            """
        view.addSubview(intro)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            intro.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            intro.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            intro.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 24),
        ])
    }

    private func refresh() {
        label.text = """
            viewDidLoad   = \(loadCount)
            viewDidAppear = \(appearCount)
            this appearance is a restart: \(appearCount > 1)
            """
    }
}

// MARK: - The empty-name child

/// Returns an empty string from `nrMobileViewName()`, which is neither a rename nor an opt-out: it
/// falls back to the demangled class name. Its MobileView events should be named
/// "MobileViewLegacyNamedViewController".
class MobileViewLegacyNamedViewController: UIViewController {

    @objc func nrMobileViewName() -> String? {
        // Not nil (that would ignore the view) and not a name — the documented fallback signal.
        ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Legacy Named"

        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = """
            `nrMobileViewName()` returns "" here. An empty string is not an opt-out — it selects the \
            legacy behavior, so this screen's MobileView events should carry viewName = \
            "MobileViewLegacyNamedViewController", the demangled class name, exactly as if the hook \
            were not implemented at all.
            """
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])
    }
}
#endif
