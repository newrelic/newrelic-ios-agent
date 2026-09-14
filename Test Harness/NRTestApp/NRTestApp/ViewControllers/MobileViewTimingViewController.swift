//
//  MobileViewTimingViewController.swift
//  NRTestApp
//
//  Exercises the MobileViewTiming API: +[NewRelic markViewTiming:] and
//  +[NewRelic recordViewTiming:milliseconds:].
//
//  Why this screen exists: the agent's own `loadTime` (and the timeToInitialDisplay timing projected
//  from it) is fixed at viewDidAppear, which for a screen like this one is when the *skeleton* is on
//  screen — not the content. This screen deliberately stages its load so the gap is visible:
//
//      viewDidAppear      skeleton rows, nothing real          -> agent records timeToInitialDisplay
//      +600ms             data "arrives", real content shown   -> markViewTiming("timeToFullDisplay")
//      +250ms             controls enabled, screen usable      -> markViewTiming("timeToInteractive")
//
//  The difference between the first and second is the "lie window": how long this screen looked
//  finished while showing nothing of value. Only the marks make it measurable.
//
//  timeToFirstByte is recorded with recordViewTiming:milliseconds: instead, because its zero point
//  is when the request went out, not when the view appeared — which is exactly the case the
//  caller-supplied overload exists for.
//
//  The log at the bottom shows each call's return value, including the rejections: the reserved
//  timeToInitialDisplay name, a non-finite duration, and the per-view cap.
//
//  Requires NRFeatureFlag_AutomaticMobileViews or NRFeatureFlag_ManualMobileViews (enabled in
//  AppDelegate).
//

import UIKit
import NewRelic

class MobileViewTimingViewController: UIViewController {

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        Self.screenName
    }

    private static let screenName = "View Timing (UIKit)"

    // MARK: - Staged-load simulation

    /// Stand-in for the network: when the payload lands, and when the screen becomes usable.
    private static let contentDelay: TimeInterval = 0.6
    private static let interactiveDelay: TimeInterval = 0.25

    /// A real TTFB the app measured itself. Hard-coded here because there is no real request; in an
    /// app this would come from URLSessionTaskMetrics.
    private static let simulatedFirstByteMs: Double = 214

    private var loadWorkItems: [DispatchWorkItem] = []
    private var logLines: [String] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .systemBackground
#endif
        title = "View Timing"
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start the staged load only once the view is on screen, so the marks measure from the same
        // zero point the agent used for timeToInitialDisplay.
        startStagedLoad()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        cancelStagedLoad()
    }

    // MARK: - The interesting part

    private func startStagedLoad() {
        cancelStagedLoad()
        logLines.removeAll()
        contentLabel.text = "▓▓▓▓▓▓▓▓  ▓▓▓▓▓▓\n▓▓▓▓▓  ▓▓▓▓▓▓▓▓▓▓\n▓▓▓▓▓▓▓▓▓▓  ▓▓▓"
        contentLabel.textColor = .secondaryLabel
        actionButton.isEnabled = false
        log("skeleton on screen — the agent's timeToInitialDisplay stops here")

        // TTFB: measured elsewhere, so the duration is supplied rather than derived from appear time.
        let tookFirstByte = NewRelic.recordViewTiming("timeToFirstByte",
                                                     milliseconds: Self.simulatedFirstByteMs)
        log("recordViewTiming(timeToFirstByte, \(Int(Self.simulatedFirstByteMs))ms) -> \(tookFirstByte)")

        let showContent = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.contentLabel.text = """
                Mars Rover · Curiosity
                Sol 4102 · 3 new images
                Battery 71% · Uplink OK
                """
            self.contentLabel.textColor = .label

            // The real headline: content is actually on screen now.
            let took = NewRelic.markViewTiming("timeToFullDisplay")
            self.log("markViewTiming(timeToFullDisplay) -> \(took)")
        }

        let becomeInteractive = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.actionButton.isEnabled = true

            let took = NewRelic.markViewTiming("timeToInteractive")
            self.log("markViewTiming(timeToInteractive) -> \(took)")
            self.log("— reload to run it again, or exercise the guardrails below")
        }

        loadWorkItems = [showContent, becomeInteractive]
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.contentDelay, execute: showContent)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.contentDelay + Self.interactiveDelay,
                                      execute: becomeInteractive)
    }

    private func cancelStagedLoad() {
        loadWorkItems.forEach { $0.cancel() }
        loadWorkItems.removeAll()
    }

    // MARK: - Guardrails, shown rather than described

    @objc private func exerciseGuardrails() {
        log("")
        log("--- guardrails ---")

        // Reserved: the agent owns this series, so customer writes to it are refused.
        let reserved = NewRelic.markViewTiming("timeToInitialDisplay")
        log("markViewTiming(timeToInitialDisplay) -> \(reserved)  (reserved)")

        // Non-finite: a single NaN would poison every average() over MobileViewTiming.
        let notANumber = NewRelic.recordViewTiming("nanTiming", milliseconds: Double.nan)
        log("recordViewTiming(nanTiming, NaN) -> \(notANumber)  (not finite)")

        // Seconds passed where milliseconds were expected.
        let tooBig = NewRelic.recordViewTiming("hugeTiming", milliseconds: 60 * 60 * 1000)
        log("recordViewTiming(hugeTiming, 1 hour) -> \(tooBig)  (over the ceiling)")

        let empty = NewRelic.recordViewTiming("", milliseconds: 10)
        log("recordViewTiming(\"\", 10ms) -> \(empty)  (empty name)")
    }

    /// Records well past the per-view cap so the drop is observable rather than theoretical.
    @objc private func exerciseCap() {
        log("")
        log("--- per-view cap ---")
        var accepted = 0
        var rejected = 0
        for i in 0..<20 {
            if NewRelic.recordViewTiming("capProbe\(i)", milliseconds: Double(i + 1)) {
                accepted += 1
            } else {
                rejected += 1
            }
        }
        log("20 timings on one view -> \(accepted) accepted, \(rejected) dropped")
        log("(earlier marks on this view count toward the same cap)")
    }

    @objc private func reload() {
        startStagedLoad()
    }

    // MARK: - UI

    private let contentLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        return l
    }()

    private let logLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        l.textColor = .secondaryLabel
        return l
    }()

    private lazy var actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Primary action (enabled at TTI)", for: .normal)
        return b
    }()

    private func buildUI() {
        let intro = UILabel()
        intro.numberOfLines = 0
        intro.font = .preferredFont(forTextStyle: .footnote)
        intro.textColor = .secondaryLabel
        intro.text = "This screen shows a skeleton first, then content \(Int(Self.contentDelay * 1000))ms later. "
            + "The agent's timeToInitialDisplay stops at the skeleton; markViewTiming(\"timeToFullDisplay\") "
            + "stops at the content. The gap between them is the lie window."

        let reloadButton = UIButton(type: .system)
        reloadButton.setTitle("Reload (re-run the staged load)", for: .normal)
        reloadButton.addTarget(self, action: #selector(reload), for: .touchUpInside)

        let guardrailsButton = UIButton(type: .system)
        guardrailsButton.setTitle("Exercise guardrails (all rejected)", for: .normal)
        guardrailsButton.addTarget(self, action: #selector(exerciseGuardrails), for: .touchUpInside)

        let capButton = UIButton(type: .system)
        capButton.setTitle("Exceed the per-view cap", for: .normal)
        capButton.addTarget(self, action: #selector(exerciseCap), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            intro, contentLabel, actionButton, reloadButton, guardrailsButton, capButton, logLabel,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -16),
        ])
    }

    private func log(_ line: String) {
        logLines.append(line)
        logLabel.text = logLines.joined(separator: "\n")
    }
}
