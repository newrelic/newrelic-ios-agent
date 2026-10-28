//
//  MobileViewCorrelationProbe.swift
//  NRTestApp
//
//  Test-harness-only peek at the agent's internal correlation state, so the demo screens can show
//  exactly what the next MobileView / interaction event will be stamped with.
//
//  NRMAViewContext is agent-private (APrivateHeader.h), so this goes through the ObjC runtime
//  rather than an import. Nothing here belongs in an app — it exists to make the feature visible
//  while exercising it.
//

import Foundation

enum MobileViewCorrelationProbe {

    /// { interactionId, interactionName } for the interaction running right now — what a MobileView
    /// event emitted at this instant would carry. Empty between interactions.
    static func interactionAttributes() -> [String: Any] {
        dictionary(from: "interactionAttributes")
    }

    /// { viewName, viewInstanceId, previousView } for the current view — what the interaction event
    /// will be stamped with when the running trace completes (late binding).
    static func viewAttributes() -> [String: Any] {
        dictionary(from: "viewCorrelationAttributes")
    }

    static func describe(_ attributes: [String: Any]) -> String {
        guard !attributes.isEmpty else { return "—" }
        return attributes.keys.sorted()
            .map { "\($0) = \(attributes[$0] ?? "<nil>")" }
            .joined(separator: "\n")
    }

    // MARK: - Runtime plumbing

    private static var viewContext: NSObject? {
        guard let cls: AnyClass = NSClassFromString("NRMAViewContext") else { return nil }
        let sharedInstance = Selector(("sharedInstance"))
        guard (cls as AnyObject).responds(to: sharedInstance) else { return nil }
        return (cls as AnyObject).perform(sharedInstance)?.takeUnretainedValue() as? NSObject
    }

    private static func dictionary(from selectorName: String) -> [String: Any] {
        guard let context = viewContext else { return [:] }
        let selector = Selector((selectorName))
        guard context.responds(to: selector) else { return [:] }
        return context.perform(selector)?.takeUnretainedValue() as? [String: Any] ?? [:]
    }
}
