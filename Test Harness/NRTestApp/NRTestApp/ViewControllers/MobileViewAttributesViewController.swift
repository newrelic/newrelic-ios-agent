//
//  MobileViewAttributesViewController.swift
//  NRTestApp
//
//  Demonstrates the `nrMobileViewAttributes` informal hook.
//  Every MobileView event emitted for this VC carries the supplied
//  custom attributes alongside the standard schema.
//

import UIKit

class MobileViewAttributesViewController: UIViewController {

    // Visit counter is bumped each time viewDidAppear runs so successive
    // appearances emit different attribute values.
    private var visitCount = 0

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        "Custom Attrs ViewController"
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
        stack.addArrangedSubview(intro)

        let header = UILabel()
        header.text = "nrMobileViewAttributes() returns:"
        header.font = .preferredFont(forTextStyle: .headline)
        stack.addArrangedSubview(header)

        stack.addArrangedSubview(attrsLabel)

        let footnote = UILabel()
        footnote.numberOfLines = 0
        footnote.text = "Tip: pop and re-push this VC to bump `visitCounter` and emit new appear/disappear events. Inspect MobileView events in the New Relic console."
        footnote.font = .preferredFont(forTextStyle: .footnote)
        footnote.textColor = .secondaryLabel
        stack.addArrangedSubview(footnote)

        refreshAttrsLabel()
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
