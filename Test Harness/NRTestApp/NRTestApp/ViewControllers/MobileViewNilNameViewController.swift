//
//  MobileViewNilNameViewController.swift
//  NRTestApp
//
//  Pins what a nil return from `nrMobileViewName()` does: nothing special. The view is named after
//  its class, exactly as an empty-string return is (see MobileViewRestartedViewController's second
//  child for that one).
//
//  This screen used to demonstrate the opposite. Returning nil was an opt-out -- "ignore this view
//  entirely, emit no MobileView events" -- which meant the natural Swift shape for the hook (compute
//  a name, return nil when there is nothing better) silently dropped the screen. That opt-out is
//  gone; whether views are collected at all is the NRFeatureFlag_AutomaticMobileViews flag's job.
//

import UIKit

class MobileViewNilNameViewController: UIViewController {

    // Returning nil no longer suppresses anything: this screen reports as
    // "MobileViewNilNameViewController".
    @objc func nrMobileViewName() -> String? {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .systemBackground
#endif
        title = "Nil name (UIKit)"
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

        let icon = UIImageView(image: UIImage(systemName: "textformat.abc.dottedunderline"))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .systemBlue
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        stack.addArrangedSubview(icon)

        let title = UILabel()
        title.text = "Named after its class"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textAlignment = .center
        title.numberOfLines = 0
        stack.addArrangedSubview(title)

        let body = UILabel()
        body.numberOfLines = 0
        body.font = .preferredFont(forTextStyle: .body)
        body.text = """
        This UIViewController implements `nrMobileViewName()` and returns nil. \
        Nil and "" both fall back to the demangled class name, so this screen \
        reports as `MobileViewNilNameViewController`.
        """
        stack.addArrangedSubview(body)

        let footnote = UILabel()
        footnote.numberOfLines = 0
        footnote.font = .preferredFont(forTextStyle: .footnote)
        footnote.textColor = .secondaryLabel
        footnote.text = "Tip: tap back to leave, then look for one MobileView event named `MobileViewNilNameViewController`. Returning nil used to suppress it entirely; there is no per-view opt-out any more."
        stack.addArrangedSubview(footnote)
    }
}
