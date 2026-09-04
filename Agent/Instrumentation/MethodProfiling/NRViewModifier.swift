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
    /// When this view was last hidden. A re-appearance measures its load from here rather than from
    /// struct creation, which by then may be many minutes in the past.
    @State private var lastHiddenAt: Date?

    // Approximation of "load time": modifier creation → onAppear.
    //
    // The approximation breaks for any view SwiftUI *constructs* long before it *shows*. TabView is
    // the clearest case: it builds every tab's content struct up front to resolve the tab items, so a
    // tab the user selects five minutes later would report a five-minute load. Container views that
    // build their children eagerly behave the same way.
    private let modifierCreatedAt = Date()

    /// Above this, a measured load is treated as unmeasurable rather than slow.
    ///
    /// This interval covers body evaluation and layout, which are synchronous and fast -- real work
    /// (fetching, decoding) happens *after* onAppear, which is what timeToFullDisplay exists to
    /// capture. So a large value here does not mean a slow screen; it means the struct was built long
    /// before it was shown, and the number is an artifact. Following the UIKit producer, which omits
    /// loadTime when viewDidLoad was never observed, the attribute is omitted rather than reported --
    /// a fabricated number silently skews every percentile computed over it.
    private static let maxPlausibleLoadMs: Double = 1500

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

                // loadTime (ms): the later of modifier creation and the last time this view was
                // hidden → onAppear. Using the last hide keeps a re-selected tab from reporting the
                // whole interval since the app built it.
                let loadStart = max(modifierCreatedAt.timeIntervalSinceReferenceDate,
                                    lastHiddenAt?.timeIntervalSinceReferenceDate ?? 0)
                let loadTimeMs = NRMAViewContext.millisecondsBetween(
                    loadStart, and: now.timeIntervalSinceReferenceDate)
                let loadIsMeasurable = loadTimeMs <= Self.maxPlausibleLoadMs

                var attrs: [String: Any] = customAttributes ?? [:]
                // Referrer for this appearance (previousView / previousViewInstanceId).
                attrs.merge(NRMAViewContext.sharedInstance().previousViewAttributes()) { _, new in new }
                // Reserved keys overwrite any caller-supplied values to keep the event schema stable.
                attrs["viewClass"]      = viewClass
                attrs["viewName"]       = viewName
                attrs["viewInstanceId"] = id
                attrs["restarted"]      = NSNumber(value: hasAppearedBefore)
                if loadIsMeasurable {
                    attrs["loadTime"]   = NSNumber(value: loadTimeMs)
                } else {
                    // Recorded explicitly so an absent loadTime is diagnosable in NRDB rather than
                    // looking like the attribute was never implemented.
                    attrs["loadTimeUnavailable"] = "constructedBeforeAppear"
                }
                attrs["appeared"]       = NSNumber(value: true)
                attrs["uiPlatform"]     = "SwiftUI"
                attrs["agentName"]      = "iOS"
                // Recorded on both appear and disappear, carrying different things. This one is
                // the only event that can hold loadTime (measured above); the disappear event
                // carries timeVisible instead.
                NewRelic.recordCustomEvent("MobileView", attributes: attrs)

                // Project the same number as the out-of-the-box timeToInitialDisplay timing, so
                // MobileViewTiming dashboards populate with no customer instrumentation and customer
                // marks such as timeToFullDisplay land on the same axis as the agent's baseline.
                // Only when the load was actually measurable. timeToInitialDisplay is a projection
                // of loadTime, so emitting it here when loadTime itself was withheld would move the
                // artifact into a second series instead of dropping it.
                if loadIsMeasurable {
                    NRMAViewTiming.sharedInstance().recordInitialDisplay(
                        forViewNamed: viewName,
                        instanceId: id,
                        previousView: attrs["previousView"] as? String,
                        platform: "SwiftUI",
                        milliseconds: loadTimeMs)
                }
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
                // A visible lifetime this short is construction churn, not something the user saw --
                // SwiftUI produces it on every TabView switch. The events are still recorded (hiding
                // data is worse than labelling it), but this marks them so screen-view counts can
                // exclude the duplicate visit: `WHERE churn IS NULL`.
                if timeVisibleMs < kNRMAMinDwellMs {
                    attrs["churn"]      = NSNumber(value: true)
                }
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

                // Zero point for the next appearance of this view.
                lastHiddenAt = disappearTime

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

    /// The tab currently reported as selected. Needed to close it out when the selection moves on --
    /// without it a tab has an appear event and never a disappear, so its dwell time is unknowable.
    @State private var openTabName: String?
    @State private var openTabInstance: String?
    @State private var openTabSince: Date?

    /// Tabs selected at least once, so re-selecting one reports restarted: true the way every other
    /// producer does.
    @State private var seenTabs: Set<String> = []

    func body(content: Content) -> some View {
        content
            .task(id: selection) {
                // Master switch: don't track tab switches while AutomaticMobileViews is disabled.
                guard NRMobileViewGate.isFeatureEnabled else { return }
                // cancelled if selection changes again within dwell window
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch { return }

                let now = Date()
                let id = UUID().uuidString
                let viewName = name(selection)
                let restarted = seenTabs.contains(viewName)

                // Make the tab current *before* closing the previous one. Two reasons: the new tab
                // then lands on top of the visible stack, so the outgoing tab is buried by the time it
                // is removed and cannot synthesize a phantom re-appearance; and previousViewAttributes
                // below resolves to the tab just left, which is what makes tab-to-tab navigation
                // visible at all. Previously this modifier never touched the context, so every tab
                // event had no previousView and read as a fresh session entry point.
                NRMAViewContext.sharedInstance().transition(
                    toView: viewName,
                    instanceId: id,
                    appearTime: now.timeIntervalSinceReferenceDate,
                    platform: "SwiftUI")

                var attrs: [String: Any] = [:]
                attrs.merge(NRMAViewContext.sharedInstance().previousViewAttributes()) { _, new in new }
                attrs["viewName"]       = viewName
                attrs["viewClass"]      = String(describing: Tag.self)
                attrs["viewInstanceId"] = id
                attrs["uiPlatform"]     = "SwiftUI"
                attrs["navigationKind"] = "tab"
                attrs["restarted"]      = NSNumber(value: restarted)
                // No loadTime: selecting a tab constructs nothing measurable here. Omitted rather
                // than zeroed so it does not drag load-time aggregates toward 0.
                attrs["appeared"]       = NSNumber(value: true)
                attrs["agentName"]      = "iOS"
                NewRelic.recordCustomEvent("MobileView", attributes: attrs)

                closeOpenTab(at: now)

                openTabName     = viewName
                openTabInstance = id
                openTabSince    = now
                seenTabs.insert(viewName)
            }
            // The whole TabView going away must still close the tab that was open, or the last tab of
            // every session silently loses its timeVisible.
            .onDisappear {
                guard NRMobileViewGate.isFeatureEnabled else { return }
                closeOpenTab(at: Date())
                openTabName     = nil
                openTabInstance = nil
                openTabSince    = nil
            }
    }

    /// Emits the disappear half for whichever tab is currently open.
    private func closeOpenTab(at when: Date) {
        guard let priorName = openTabName,
              let priorId = openTabInstance,
              let priorSince = openTabSince else { return }

        let timeVisibleMs = NRMAViewContext.millisecondsBetween(
            priorSince.timeIntervalSinceReferenceDate,
            and: when.timeIntervalSinceReferenceDate)

        NewRelic.recordCustomEvent("MobileView", attributes: [
            "viewName":       priorName,
            "viewClass":      String(describing: Tag.self),
            "viewInstanceId": priorId,
            "uiPlatform":     "SwiftUI",
            "navigationKind": "tab",
            "timeVisible":    NSNumber(value: timeVisibleMs),
            "appeared":       NSNumber(value: false),
            "agentName":      "iOS",
        ])

        NRMAViewContext.sharedInstance().viewDidDisappearNamed(priorName, instanceId: priorId)
    }
}

#endif
