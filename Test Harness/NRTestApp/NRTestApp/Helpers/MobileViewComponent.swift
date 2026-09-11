//
//  MobileViewComponent.swift
//  NRTestApp
//
//  The UIKit counterpart to attaching `.NRMobileView(name:attributes:)` to a SwiftUI subview.
//
//  MobileViews has no per-subview UIKit hook: the swizzles are on UIViewController lifecycle, so the
//  smallest thing the agent can see is a view controller. Wrapping a section in a child view
//  controller is therefore how a UIKit screen reports its parts — the existing swizzle emits the
//  section's MobileView event and records its load span as a segment on whatever interaction the host
//  screen opened. That is what puts several `Method/MobileView/<component>` rows into a *single*
//  interaction's breakdown table, instead of the one row naming the screen.
//
//  Components deliberately never open an interaction of their own; they record against the one the
//  host screen already has.
//
//  Names are dot-separated rather than slash-separated on purpose: `/` is one of the characters
//  `+[NewRelicInternalUtils cleanseStringForCollector:]` rewrites to `_`, and it is also the
//  separator in the `Method/<class>/<method>` metric grammar these names land in.
//
//  Names are fixed strings, never per-item: view name is a facet, and unbounded names make it
//  useless. Anything that varies belongs in the attributes instead.
//

import UIKit

/// A section of a screen, reported to New Relic as a MobileView in its own right.
final class MobileViewComponentController: UIViewController {

    private let componentName: String
    private let screenName: String
    private let content: UIView

    init(componentName: String, screenName: String, content: UIView) {
        self.componentName = componentName
        self.screenName = screenName
        self.content = content
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - MobileViews hooks

    @objc func nrMobileViewName() -> String? {
        componentName
    }

    /// Marks the emitted MobileView events as components rather than screens. `viewName` alone
    /// cannot tell them apart — to the agent a component is just another view — so dashboards need
    /// an attribute to facet on.
    @objc func nrMobileViewAttributes() -> [String: Any]? {
        [
            "component": true,
            "componentOf": screenName,
        ]
    }

    // MARK: - Lifecycle

    override func loadView() {
        // The component's view *is* the section, so containment costs no extra layer in the view
        // hierarchy — which matters because Session Replay walks it.
        view = content
    }
}

extension UIViewController {

    /// Adds `content` to `stack` as a child view controller, so it reports as its own MobileView
    /// named `componentName` with `componentOf: screenName`.
    func addMobileViewComponent(_ componentName: String,
                               of screenName: String,
                               content: UIView,
                               to stack: UIStackView) {
        let component = MobileViewComponentController(componentName: componentName,
                                                     screenName: screenName,
                                                     content: content)
        addChild(component)
        stack.addArrangedSubview(component.view)
        component.didMove(toParent: self)
    }

    /// Convenience for the common case: a vertical stack of `views` treated as one component.
    func addMobileViewComponent(_ componentName: String,
                               of screenName: String,
                               views: [UIView],
                               spacing: CGFloat = 8,
                               to stack: UIStackView) {
        let section = UIStackView(arrangedSubviews: views)
        section.axis = .vertical
        section.spacing = spacing
        section.alignment = .fill
        addMobileViewComponent(componentName, of: screenName, content: section, to: stack)
    }
}
