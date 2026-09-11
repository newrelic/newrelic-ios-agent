//
//  MobileViewIgnoredViewController.swift
//  NRTestApp
//
//  Demonstrates the "ignore this view" path: implementing `nrMobileViewName`
//  and returning nil tells NRMAMobileViewTracker to skip this VC entirely —
//  no MobileView events emit on viewDidAppear / viewDidDisappear.
//

import UIKit

class MobileViewIgnoredViewController: UIViewController {

    // Returning nil here is the signal: "ignore this view".
    @objc func nrMobileViewName() -> String? {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .systemBackground
#endif
        title = "Ignored (UIKit)"
        buildUI()
    }

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

        let icon = UIImageView(image: UIImage(systemName: "eye.slash"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .systemRed
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        stack.addArrangedSubview(icon)

        let title = UILabel()
        title.text = "No MobileView events for this screen"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textAlignment = .center
        title.numberOfLines = 0
        stack.addArrangedSubview(title)

        let body = UILabel()
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        body.text = """
        This UIViewController overrides `nrMobileViewName()` and returns nil. \
        That signals NRMAMobileViewTracker to skip the view entirely, so no \
        MobileView event is emitted on viewDidAppear or viewDidDisappear.
        """
        stack.addArrangedSubview(body)

        let footnote = UILabel()
        footnote.numberOfLines = 0
        footnote.font = .preferredFont(forTextStyle: .footnote)
        footnote.textColor = .secondaryLabel
        footnote.text = "Tip: tap back to leave. You should NOT see a MobileView event for `MobileViewIgnoredViewController` in the New Relic console — but the parent screen's appear event should fire when you return."
        stack.addArrangedSubview(footnote)
    }
}
