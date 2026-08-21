//
//  MobileViewAttributesViewController.swift
//  NRTestApp
//
//  Demonstrates the `nrMobileViewAttributes` informal hook.
//  Every MobileView event emitted for this VC carries the supplied
//  custom attributes alongside the standard schema.
//
//  Each section of the screen also reports as its own MobileView via a child view controller (see
//  MobileViewComponentController), tagged component: true / componentOf: "Custom Attrs
//  ViewController". Note what the components do NOT inherit: `nrMobileViewAttributes` is read off
//  the view controller the event belongs to, so the screen's userId / experimentVariant attributes
//  appear on the screen's events only. Attributes a component needs are its own to supply.
//

import UIKit

class MobileViewAttributesViewController: UIViewController {

    // Visit counter is bumped each time viewDidAppear runs so successive
    // appearances emit different attribute values.
    private var visitCount = 0

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        Self.screenName
    }

    private static let screenName = "Custom Attrs ViewController"

    /// The sections of this screen, each tracked as a view in its own right. They take no
    /// interaction of their own — each records a load segment against the automatic interaction
    /// covering this screen's push, so that interaction's breakdown table holds a
    /// `Method/MobileView/<component>` row per section instead of one row for the screen.
    ///
    /// Names are dot-separated because `/` is rewritten to `_` by the collector's string cleansing
    /// and is also the separator in the `Method/<class>/<method>` grammar these names land in.
    private enum Component: String {
        case intro      = "CustomAttrs.Intro"
        case attributes = "CustomAttrs.Attributes"
        case footnote   = "CustomAttrs.Footnote"
    }

    @objc func nrMobileViewAttributes() -> [String: Any]? {
        [
            "userId":            "user-42",
            "experimentVariant": "treatment-A",
            "visitCounter":      visitCount,
            "feature":           "mobile-views",
            "isPremium":         true,
        ]
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .systemBackground
#endif
        title = "Custom Attrs (UIKit)"
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        // Bump BEFORE super so the appear event reads the new value.
        visitCount += 1
        super.viewDidAppear(animated)
        refreshAttrsLabel()
    }

    // MARK: - UI

    private let attrsLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        ])

        let intro = UILabel()
        intro.numberOfLines = 0
        intro.text = "This UIViewController implements `nrMobileViewAttributes()` and `nrMobileViewName()`. Every MobileView event emitted for this screen carries the attributes shown below."
        intro.font = .preferredFont(forTextStyle: .body)
        addComponent(.intro, views: [intro], to: stack)

        let header = UILabel()
        header.text = "nrMobileViewAttributes() returns:"
        header.font = .preferredFont(forTextStyle: .headline)
        addComponent(.attributes, views: [header, attrsLabel], to: stack)

        let footnote = UILabel()
        footnote.numberOfLines = 0
        footnote.text = "Tip: pop and re-push this VC to bump `visitCounter` and emit new appear/disappear events. Inspect MobileView events in the New Relic console."
        footnote.font = .preferredFont(forTextStyle: .footnote)
        footnote.textColor = .secondaryLabel
        addComponent(.footnote, views: [footnote], to: stack)

        refreshAttrsLabel()
    }

    private func addComponent(_ component: Component, views: [UIView], to stack: UIStackView) {
        addMobileViewComponent(component.rawValue, of: Self.screenName, views: views, to: stack)
    }

    private func refreshAttrsLabel() {
        guard let dict = nrMobileViewAttributes() else { return }
        let lines = dict.keys.sorted().map { key -> String in
            let value = dict[key] ?? "<nil>"
            return "  \(key) = \(value)"
        }
        attrsLabel.text = "{\n" + lines.joined(separator: "\n") + "\n}"
    }
}
