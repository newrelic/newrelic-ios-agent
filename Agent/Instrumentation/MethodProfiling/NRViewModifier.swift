//
//  NRViewModifier.swift
//  NewRelicAgent
//
//  Created by Mike Bruin on 2/28/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

//
// This is an experimental feature to better track SwiftUI.
//

@_implementationOnly import NewRelicPrivate

#if canImport(SwiftUI)
import SwiftUI

@available(iOS 13, tvOS 13, *)
internal struct NRViewModifier: SwiftUI.ViewModifier {
    
    let name: String
    
    @State private var uniqueInteractionTraceIdentifier: String?
    
    func body(content: Content) -> some View {
        content.onAppear {
            uniqueInteractionTraceIdentifier = NewRelic.startInteraction(withName: name)
        }
        .onDisappear {
            NewRelic.stopCurrentInteraction(uniqueInteractionTraceIdentifier)
        }
    }
}

//
// This is an experimental feature to better track SwiftUI.
//

@available(iOS 13, tvOS 13, *)
public extension SwiftUI.View {
    func NRTrackView(name: String? = nil) -> some View {
        modifier(NRViewModifier(name: name ?? String(describing: type(of: self))))
    }
}

// MARK: - MobileViews: SwiftUI support

/// Feature-flag gate for the SwiftUI MobileView producers.
///
/// MobileView collection is opt-in via `NRFeatureFlag_AutomaticMobileViews`. The UIKit producer is
/// gated at swizzle-install time (see `-[NewRelicAgentInternal initialize]`) and the manual
/// `setCurrentView:` producer is gated at its API boundary (see `+[NewRelic setCurrentView:attributes:]`).
/// The SwiftUI modifiers below are compiled into the host app's view tree, so they must consult the
/// flag at emit time — otherwise merely attaching `.NRMobileView(...)` would send data even with the
/// feature disabled, which is the bug this gate closes. Keeping the decision here means the flag is a
/// true master switch for every SwiftUI entry point (`NRMobileView`, `NRMobileDestination`,
/// `NRMobileSheet`, `NRMobileFullScreenCover`, `NRMobilePopover`, `NRMobileNavigationLink`,
/// `NRMobileTabTracking`).
internal enum NRMobileViewGate {

    /// The master switch for SwiftUI MobileView collection.
    static var isFeatureEnabled: Bool {
        NRMAFlags.shouldEnableAutomaticMobileViews()
    }

    /// Whether a MobileView event should be recorded for this view: only when the feature flag is
    /// enabled, the view is not explicitly ignored, and its name is not on the skip list.
    static func shouldRecord(ignored: Bool, viewName: String) -> Bool {
        guard isFeatureEnabled else { return false }
        if ignored { return false }
        if NRMA_ShouldSkipViewName(viewName) { return false }
        return true
    }
}

/// NRMobileViewModifier emits a MobileView custom event on appear and disappear.
/// Tracks loadTime (onAppear - modifier init), timeVisible (disappear - appear), and
/// viewInstanceId per appearance, matching the UIKit NRMAMobileViewTracker schema.
@available(iOS 13, tvOS 13, *)
internal struct NRMobileViewModifier: SwiftUI.ViewModifier {

    let viewName: String
    let viewClass: String
    let customAttributes: [String: Any]?
    let ignored: Bool

    @State private var appearTime: Date?
    @State private var instanceId: String?
    @State private var hasAppearedBefore: Bool = false

    // Approximation of "load time": modifier creation → onAppear
    private let modifierCreatedAt = Date()

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Master switch: emit (and touch the shared view context) only when the
                // AutomaticMobileViews feature flag is enabled and this view is trackable.
                guard NRMobileViewGate.shouldRecord(ignored: ignored, viewName: viewName) else { return }

                let now = Date()
                let id = UUID().uuidString
                appearTime = now
                instanceId = id

                // Make this view current in the shared context so it becomes the referrer for the
                // next view and for breadcrumbs recorded while it is visible.
                NRMAViewContext.sharedInstance().transition(
                    toView: viewName,
                    instanceId: id,
                    appearTime: now.timeIntervalSinceReferenceDate,
                    platform: "SwiftUI")

                // loadTime (ms): modifier creation (≈ view body evaluation) → onAppear
                let loadTimeMs = NRMAViewContext.millisecondsBetween(
                    modifierCreatedAt.timeIntervalSinceReferenceDate,
                    and: now.timeIntervalSinceReferenceDate)

                var attrs: [String: Any] = customAttributes ?? [:]
                // Referrer for this appearance (previousView / previousViewInstanceId).
                attrs.merge(NRMAViewContext.sharedInstance().previousViewAttributes()) { _, new in new }
                // Reserved keys overwrite any caller-supplied values to keep the event schema stable.
                attrs["viewClass"]      = viewClass
                attrs["viewName"]       = viewName
                attrs["viewInstanceId"] = id
                attrs["restarted"]      = NSNumber(value: hasAppearedBefore)
                attrs["loadTime"]       = NSNumber(value: loadTimeMs)
                attrs["appeared"]       = NSNumber(value: true)
                attrs["uiPlatform"]     = "SwiftUI"
                attrs["agentName"]      = "iOS"
                // Recorded on both appear and disappear, carrying different things. This one is
                // the only event that can hold loadTime (measured above); the disappear event
                // carries timeVisible instead.
                NewRelic.recordCustomEvent("MobileView", attributes: attrs)
            }
            .onDisappear {
                // Master switch: honor the AutomaticMobileViews feature flag here too, so a view
                // never emits a disappear event while the feature is disabled.
                guard NRMobileViewGate.shouldRecord(ignored: ignored, viewName: viewName) else { return }

                let disappearTime = Date()
                guard let appeared = appearTime, let id = instanceId else { return }

                // timeVisible (ms): onAppear → onDisappear. loadTime is only included on appear.
                let timeVisibleMs = NRMAViewContext.millisecondsBetween(
                    appeared.timeIntervalSinceReferenceDate,
                    and: disappearTime.timeIntervalSinceReferenceDate)

                var attrs: [String: Any] = customAttributes ?? [:]
                attrs["viewClass"]      = viewClass
                attrs["viewName"]       = viewName
                attrs["viewInstanceId"] = id
                attrs["restarted"]      = NSNumber(value: hasAppearedBefore)
                attrs["timeVisible"]    = NSNumber(value: timeVisibleMs)
                attrs["uiPlatform"]     = "SwiftUI"
                attrs["appeared"]       = NSNumber(value: false)
                attrs["agentName"]      = "iOS"
                NewRelic.recordCustomEvent("MobileView", attributes: attrs)

                // Tell the shared context this instance is gone. This is the SwiftUI-specific half
                // of the fix: popping a NavigationStack back to a view does not re-fire its
                // onAppear, so if this disappearance uncovered something, the context synthesizes
                // the appear event SwiftUI never delivers. Called before `instanceId` is cleared,
                // since that is the key the stack is keyed by.
                NRMAViewContext.sharedInstance().viewDidDisappearNamed(viewName, instanceId: id)

                hasAppearedBefore = true
                appearTime = nil
                instanceId = nil
            }
    }
}

/// Attach this modifier to SwiftUI views to emit MobileView events.
/// Enable via NRFeatureFlag_AutomaticMobileViews.
///
/// - Parameters:
///   - name: Display name for the view. Defaults to the SwiftUI view type name.
///   - attributes: Optional custom attributes merged into every MobileView event emitted
///     for this view. Reserved keys (viewClass, viewName, viewInstanceId, restarted,
///     loadTime, timeVisible, appeared, uiPlatform, agentName) are not overridden.
///   - ignored: When true, no MobileView events are emitted for this view. Default false.
@available(iOS 13, tvOS 13, *)
public extension SwiftUI.View {
    func NRMobileView(name: String? = nil,
                      attributes: [String: Any]? = nil,
                      ignored: Bool = false) -> some View {
        // String(reflecting:) produces a noisy generic modifier stack when views are chained
        // (e.g. "SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<...>>"), so we use
        // String(describing:) for a clean simple name, or the caller-supplied name if given.
        let simpleName = String(describing: type(of: self))
        let resolved   = name ?? simpleName
        return modifier(NRMobileViewModifier(
            viewName:          resolved,
            viewClass:         resolved,
            customAttributes:  attributes,
            ignored:           ignored
        ))
    }
    
    // NavigationStack / NavigationLink + navigationDestination(for:)
    @available(iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func NRMobileDestination<D: Hashable, C: View>(
        for data: D.Type,
        name: @escaping (D) -> String = { String(describing: $0) },
        @ViewBuilder destination: @escaping (D) -> C
    ) -> some View {
        return navigationDestination(for: D.self) { value in
            destination(value).NRMobileView(name: name(value))
        }
        
    }
    
    // sheet(isPresented:)
    func NRMobileSheet<C: View>(
        isPresented: Binding<Bool>,
        name: String,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            content().NRMobileView(name: name)
        }
    }
    
    // sheet(item:)
    func NRMobileSheet<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        name: @escaping (Item) -> String = { String(describing: $0) },
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { value in
            content(value).NRMobileView(name: name(value))
        }
    }
    
    // Same shape for .fullScreenCover and .popover
    func NRMobileFullScreenCover<C: View>(
        isPresented: Binding<Bool>, name: String,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            content().NRMobileView(name: name)
        }
    }
    #if os(iOS) || targetEnvironment(macCatalyst)
    func NRMobilePopover<C: View>(
        isPresented: Binding<Bool>, name: String,
        attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
        popover(isPresented: isPresented, attachmentAnchor: attachmentAnchor) {
            content().NRMobileView(name: name)
        }
    }
    #endif
}

// NavigationLink helper (value-less destination form).
// Uses the pre-iOS 16 NavigationLink(destination:label:) initializer so the
// wrapper is usable anywhere NavigationLink is, not just in iOS 16 stacks.
@available(iOS 13, tvOS 13, *)
public struct NRMobileNavigationLink<Label: View, Destination: View>: View {
    let name: String
    @ViewBuilder let destination: () -> Destination
    @ViewBuilder let label: () -> Label

    public init(
        name: String,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.name = name
        self.destination = destination
        self.label = label
    }

    public var body: some View {
        NavigationLink(destination: destination().NRMobileView(name: name)) {
            label()
        }
    }
}

// TabView tracking
@available(iOS 15, tvOS 15, *)
public extension SwiftUI.View {
    func NRMobileTabTracking<Tag: Hashable>(
        selection: Binding<Tag>,
        name: @escaping (Tag) -> String = { String(describing: $0) }
    ) -> some View {
        modifier(NRMobileTabTrackingModifier(selection: selection, name: name))
    }
}

@available(iOS 15, tvOS 15, *)
private struct NRMobileTabTrackingModifier<Tag: Hashable>: ViewModifier {
    @Binding var selection: Tag
    let name: (Tag) -> String
    @State private var lastFiredAt: Date?
    @State private var lastInstance: String?

    func body(content: Content) -> some View {
        content
            .task(id: selection) {
                // Master switch: don't track tab switches while AutomaticMobileViews is disabled.
                guard NRMobileViewGate.isFeatureEnabled else { return }
                // cancelled if selection changes again within dwell window
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch { return }
                let id = UUID().uuidString
                lastFiredAt = Date()
                lastInstance = id
                let viewName = name(selection)
                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewName": viewName,
                    "viewClass": String(describing: Tag.self),
                    "viewInstanceId": id,
                    "uiPlatform": "SwiftUI",
                    "navigationKind": "tab",
                    // loadTime ≈ 0 for tab switches; semantics caveat in docs
                    "appeared":       NSNumber(value: true),
                    "agentName": "iOS",
                ])
            }
    }
}

#endif
