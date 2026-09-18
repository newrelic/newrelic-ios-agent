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
#if !os(watchOS)
import Combine
import UIKit
#endif

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
    /// enabled and the view's name is not on the skip list (system hosts and containers, which are
    /// not screens).
    ///
    /// There is no per-view opt-out. `.NRMobileView(ignored: true)` used to be one, and it made the
    /// modifier mean two opposite things at the same call site -- an attached modifier that reports
    /// nothing is indistinguishable from an absent one in the data, and the way to not track a
    /// screen is to not attach the modifier to it.
    static func shouldRecord(viewName: String) -> Bool {
        guard isFeatureEnabled else { return false }
        if NRMA_ShouldSkipViewName(viewName) { return false }
        return true
    }
}

/// NRMobileViewModifier emits one MobileView custom event per visit, on disappear.
/// Tracks loadTime (onAppear - modifier init), timeVisible (disappear - appear), and
/// viewInstanceId per appearance, matching the UIKit NRMAMobileViewTracker schema.
///
/// onAppear does the bookkeeping -- it makes the view current in the shared context, measures the
/// construction interval and captures the referrer -- and holds those facts in @State until
/// onDisappear, which is the only site that emits. A visit is not describable before it ends:
/// timeVisible is only knowable then.
@available(iOS 13, tvOS 13, *)
internal struct NRMobileViewModifier: SwiftUI.ViewModifier {

    let viewName: String
    let viewClass: String
    let customAttributes: [String: Any]?

    /// Monotonic seconds, from `NRMAViewContext.monotonicNow()`. Never `Date` — see that method for
    /// why a wall-clock step surfaces here as a fabricated 0 ms rather than as an obvious error.
    @State private var appearTime: Double?
    @State private var instanceId: String?
    /// True once this identity has been through an appear/disappear cycle. Not reported -- it is
    /// how the load outcome tells "SwiftUI preserved this view" from "this view was rebuilt".
    @State private var hasAppearedBefore: Bool = false

    /// The construction outcome measured at onAppear, held until the event is emitted.
    @State private var loadOutcome: NRViewLoadOutcome?
    /// The referrer as of this appearance. Captured at onAppear because by onDisappear the shared
    /// context has moved on -- its "previous view" is then this screen itself.
    @State private var referrerName: String?
    @State private var referrerInstanceId: String?

    // Approximation of "load time": modifier creation → onAppear.
    //
    // The approximation breaks for any view SwiftUI *constructs* long before it *shows*. TabView is
    // the clearest case: it builds every tab's content struct up front to resolve the tab items, so a
    // tab the user selects five minutes later would report a five-minute load. Container views that
    // build their children eagerly behave the same way. kNRMAMaxPlausibleLoadMs is what rejects
    // those, and `hasAppearedBefore` is what rejects the other direction (below).
    private let modifierCreatedAt = NRMAViewContext.monotonicNow()

    func body(content: Content) -> some View {
        content
            .onAppear { openVisit() }
            .onDisappear {
                closeVisit(at: NRMAViewContext.monotonicNow())

                // Marks this identity as one SwiftUI preserved: the next onAppear on this same @State
                // is a re-appearance with nothing rebuilt, so it reports no construction start.
                hasAppearedBefore = true
                // The referrer outlives a visit closed at backgrounding, because the re-opened visit
                // was reached from the same place. It does not outlive a real disappearance.
                referrerName = nil
                referrerInstanceId = nil
            }
            .modifier(NRMobileViewBackgroundBridge(
                onBackground: { closeVisit(at: NRMAViewContext.monotonicNow()) },
                onForeground: { reopenVisit(at: NRMAViewContext.monotonicNow()) }))
    }

    /// Opens a visit. `onAppear` only -- the app coming back to the foreground goes through
    /// `reopenVisit(at:)`, which has no construction to time and no referrer to look up.
    private func openVisit() {
        // Master switch: emit (and touch the shared view context) only when the
        // AutomaticMobileViews feature flag is enabled and this view is trackable.
        guard NRMobileViewGate.shouldRecord(viewName: viewName) else { return }

        let now = NRMAViewContext.monotonicNow()
        let id = UUID().uuidString
        appearTime = now
        instanceId = id

        // Construction start: modifier init → onAppear, and only on a genuine first
        // construction.
        //
        // `hasAppearedBefore` lives in @State, so it is `true` here precisely when SwiftUI
        // preserved this view's identity — which means the view was *not* rebuilt and has no
        // construction to time. (Had it been rebuilt, @State would have reset and this would
        // read `false`.) That check replaces an earlier "measure from the last time it was
        // hidden" fallback, which reported the interval the user spent on some *other*
        // screen as this screen's load time whenever they came back within the ceiling.
        var loadStart: NSNumber?
        var unavailableReason: String?
        var loadTimeMs: Double = 0

        if hasAppearedBefore {
            unavailableReason = "notRebuilt"
        } else {
            let measured = NRMAViewContext.millisecondsBetween(modifierCreatedAt, and: now)
            if measured <= kNRMAMaxPlausibleLoadMs {
                loadStart  = NSNumber(value: modifierCreatedAt)
                loadTimeMs = measured
            } else {
                unavailableReason = "constructedBeforeAppear"
            }
        }
        let loadIsMeasurable = (loadStart != nil)

        // Make this view current in the shared context so it becomes the referrer for the
        // next view and for breadcrumbs recorded while it is visible. The load start rides
        // along because it is the origin both timeToInitialDisplay and every
        // markViewTiming: on this screen are measured from.
        NRMAViewContext.sharedInstance().transition(
            toView: viewName,
            instanceId: id,
            appearTime: now,
            loadStartTime: loadStart,
            platform: "SwiftUI")

        // The load outcome is a single value rather than two independent attributes, so
        // loadTime and loadTimeUnavailable cannot both be written or both be missed. An
        // absent loadTime is recorded with its reason, so it is diagnosable in NRDB rather
        // than looking like the attribute was never implemented.
        //
        // Held rather than emitted: it rides on the single event this visit produces when
        // the view goes away.
        loadOutcome = loadIsMeasurable
            ? .measured(loadTimeMs)
            : .unavailable(unavailableReason.flatMap { NRViewLoadOutcome.Reason(rawValue: $0) }
                           ?? .noConstructionObserved)

        // The referrer for *this* appearance, read straight after the transition above made
        // this view current. Read at emit time it would name whatever replaced this screen.
        let referrer = NRMAViewContext.sharedInstance().previousViewAttributes()
        referrerName       = referrer["previousView"] as? String
        referrerInstanceId = referrer["previousViewInstanceId"] as? String

        // The out-of-the-box baseline, so MobileViewTiming dashboards populate with no
        // customer instrumentation and customer marks such as timeToFullDisplay share its
        // origin. Derived from the load start and appear time the transition above recorded,
        // not from a number passed in here, so the baseline and those marks cannot end up
        // measured from different instants. No-ops on its own when no construction start was
        // vouched for, which is the same condition that withheld loadTime.
        NRMAViewTiming.sharedInstance().recordInitialDisplayForCurrentView()
    }

    /// Ends the current visit and records its one event.
    ///
    /// Two callers, and the difference between them is why this is a method rather than the body of
    /// `onDisappear`. `onDisappear` means "this view is gone"; the background bridge means "the app
    /// is gone, with this view still on screen". The visit ended either way, and ended at `endTime`.
    ///
    /// A no-op when there is no open visit: the view never appeared, or a background flush already
    /// closed this one and no foreground has re-opened it. That is what keeps a background followed
    /// by a real `onDisappear` from reporting the same visit twice.
    private func closeVisit(at endTime: Double) {
        // Master switch: honor the AutomaticMobileViews feature flag here too, so a view
        // never emits an event while the feature is disabled.
        guard NRMobileViewGate.shouldRecord(viewName: viewName) else { return }

        guard let appeared = appearTime, let id = instanceId else { return }

        // timeVisible (ms): the appearance that opened this visit → whatever ended it.
        let timeVisibleMs = NRMAViewContext.millisecondsBetween(appeared, and: endTime)

        // The whole visit, in one event: identity and referrer from the appearance, loadTime
        // measured then, timeVisible measured now.
        //
        // Emitted however brief the visible lifetime was. SwiftUI delivers an
        // appear/disappear pair milliseconds apart on every TabView switch; those pairs are
        // reported like any other rather than being suppressed or labelled by the agent.
        MobileViewRecord(viewName: viewName,
                         viewClass: viewClass,
                         instanceId: id,
                         platform: .swiftUI,
                         referrer: .explicit(name: referrerName,
                                             instanceId: referrerInstanceId),
                         load: loadOutcome,
                         timeVisibleMs: timeVisibleMs,
                         custom: customAttributes).emit()

        // Tell the shared context this instance is gone, so whatever this view was covering
        // becomes current again -- popping a NavigationStack back to a view does not re-fire its
        // onAppear, so nothing else would. Called before `instanceId` is cleared, since that is
        // the key the visible stack is keyed by.
        NRMAViewContext.sharedInstance().viewDidDisappearNamed(viewName, instanceId: id)

        // Clearing the appear time is what marks the visit closed, so a later onDisappear for
        // a view already flushed at background finds nothing to report.
        appearTime = nil
        instanceId = nil
        loadOutcome = nil
    }

    /// Starts a new visit for a view that is still on screen after the app came back.
    ///
    /// SwiftUI does not re-fire `onAppear` on foregrounding -- from its point of view the view never
    /// went anywhere -- so without this the time the user spends here after returning belongs to no
    /// visit, and the shared context's visible stack keeps a hole where this view still is.
    ///
    /// Nothing was rebuilt, so there is no construction to time: `notRebuilt`, the same outcome a
    /// preserved identity reports. The referrer is the one captured when the view really appeared.
    private func reopenVisit(at startTime: Double) {
        guard NRMobileViewGate.shouldRecord(viewName: viewName) else { return }
        // Only re-open what backgrounding closed. A view that was already gone must stay gone.
        guard appearTime == nil, instanceId == nil else { return }

        let id = UUID().uuidString
        appearTime  = startTime
        instanceId  = id
        loadOutcome = .unavailable(.notRebuilt)

        NRMAViewContext.sharedInstance().transition(
            toView: viewName,
            instanceId: id,
            appearTime: startTime,
            loadStartTime: nil,
            platform: "SwiftUI")
    }
}

/// Delivers app background / foreground to the MobileView modifier.
///
/// A separate modifier rather than two `onReceive` calls inline, because the notifications only exist
/// off watchOS and `#if` inside a `some View` chain does not compose cleanly. On watchOS this is the
/// identity modifier: nothing observes backgrounding, so a watchOS SwiftUI view's last visit of a
/// session still goes unreported.
@available(iOS 13, tvOS 13, *)
private struct NRMobileViewBackgroundBridge: SwiftUI.ViewModifier {

    let onBackground: () -> Void
    let onForeground: () -> Void

    func body(content: Content) -> some View {
#if os(watchOS)
        content
#else
        content
            // didEnterBackground, not willResignActive: the app being *fully* backgrounded is what
            // ends a visit. Resigning active covers interruptions the user comes straight back from
            // -- a notification banner, Control Center, an incoming call -- and treating those as
            // the end of a visit would split one screen view into several.
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.didEnterBackgroundNotification)) { _ in onBackground() }
            .onReceive(NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification)) { _ in onForeground() }
#endif
    }
}

/// Attach this modifier to SwiftUI views to emit MobileView events.
/// Enable via NRFeatureFlag_AutomaticMobileViews.
///
/// - Parameters:
///   - name: Display name for the view. Defaults to the SwiftUI view type name.
///   - attributes: Optional custom attributes merged into the MobileView event emitted
///     for this view. Reserved keys (viewClass, viewName, viewInstanceId, loadTime,
///     timeVisible, uiFramework, previousView) are not overridden.
///
/// To not track a screen, do not attach this modifier to it. There is no `ignored` parameter: an
/// attached modifier that reports nothing looks exactly like an absent one in the data, so it was a
/// way to write instrumentation that appeared to work and did not.
@available(iOS 13, tvOS 13, *)
public extension SwiftUI.View {
    func NRMobileView(name: String? = nil,
                      attributes: [String: Any]? = nil) -> some View {
        // String(reflecting:) produces a noisy generic modifier stack when views are chained
        // (e.g. "SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<...>>"), so we use
        // String(describing:) for a clean simple name, or the caller-supplied name if given.
        let simpleName = String(describing: type(of: self))
        let resolved   = name ?? simpleName
        return modifier(NRMobileViewModifier(
            viewName:          resolved,
            viewClass:         resolved,
            customAttributes:  attributes
        ))
    }
}
//
//    // NavigationStack / NavigationLink + navigationDestination(for:)
//    @available(iOS 16.0, tvOS 16.0, watchOS 9.0, *)
//    func NRMobileDestination<D: Hashable, C: View>(
//        for data: D.Type,
//        name: @escaping (D) -> String = { String(describing: $0) },
//        @ViewBuilder destination: @escaping (D) -> C
//    ) -> some View {
//        return navigationDestination(for: D.self) { value in
//            destination(value).NRMobileView(name: name(value))
//        }
//        
//    }
//    
//    // sheet(isPresented:)
//    func NRMobileSheet<C: View>(
//        isPresented: Binding<Bool>,
//        name: String,
//        onDismiss: (() -> Void)? = nil,
//        @ViewBuilder content: @escaping () -> C
//    ) -> some View {
//        sheet(isPresented: isPresented, onDismiss: onDismiss) {
//            content().NRMobileView(name: name)
//        }
//    }
//    
//    // sheet(item:)
//    func NRMobileSheet<Item: Identifiable, C: View>(
//        item: Binding<Item?>,
//        name: @escaping (Item) -> String = { String(describing: $0) },
//        onDismiss: (() -> Void)? = nil,
//        @ViewBuilder content: @escaping (Item) -> C
//    ) -> some View {
//        sheet(item: item, onDismiss: onDismiss) { value in
//            content(value).NRMobileView(name: name(value))
//        }
//    }
//    
//    // Same shape for .fullScreenCover and .popover
//    func NRMobileFullScreenCover<C: View>(
//        isPresented: Binding<Bool>, name: String,
//        onDismiss: (() -> Void)? = nil,
//        @ViewBuilder content: @escaping () -> C
//    ) -> some View {
//        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
//            content().NRMobileView(name: name)
//        }
//    }
//    #if os(iOS) || targetEnvironment(macCatalyst)
//    func NRMobilePopover<C: View>(
//        isPresented: Binding<Bool>, name: String,
//        attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds),
//        arrowEdge: Edge = .top,
//        @ViewBuilder content: @escaping () -> C
//    ) -> some View {
//        popover(isPresented: isPresented, attachmentAnchor: attachmentAnchor) {
//            content().NRMobileView(name: name)
//        }
//    }
//    #endif
//}
//
//// NavigationLink helper (value-less destination form).
//// Uses the pre-iOS 16 NavigationLink(destination:label:) initializer so the
//// wrapper is usable anywhere NavigationLink is, not just in iOS 16 stacks.
//@available(iOS 13, tvOS 13, *)
//public struct NRMobileNavigationLink<Label: View, Destination: View>: View {
//    let name: String
//    @ViewBuilder let destination: () -> Destination
//    @ViewBuilder let label: () -> Label
//
//    public init(
//        name: String,
//        @ViewBuilder destination: @escaping () -> Destination,
//        @ViewBuilder label: @escaping () -> Label
//    ) {
//        self.name = name
//        self.destination = destination
//        self.label = label
//    }
//
//    public var body: some View {
//        NavigationLink(destination: destination().NRMobileView(name: name)) {
//            label()
//        }
//    }
//}
//
//// TabView tracking
//@available(iOS 15, tvOS 15, *)
//public extension SwiftUI.View {
//    func NRMobileTabTracking<Tag: Hashable>(
//        selection: Binding<Tag>,
//        name: @escaping (Tag) -> String = { String(describing: $0) }
//    ) -> some View {
//        modifier(NRMobileTabTrackingModifier(selection: selection, name: name))
//    }
//}
//
//@available(iOS 15, tvOS 15, *)
//private struct NRMobileTabTrackingModifier<Tag: Hashable>: ViewModifier {
//    @Binding var selection: Tag
//    let name: (Tag) -> String
//
//    /// The tab currently reported as selected. Needed to close it out when the selection moves on --
//    /// without it a tab has an appear event and never a disappear, so its time on screen is
//    /// unknowable.
//    @State private var openTabName: String?
//    @State private var openTabInstance: String?
//    /// Monotonic seconds, from `NRMAViewContext.monotonicNow()`.
//    @State private var openTabSince: Double?
//    /// The tab that was open before this one -- the referrer, captured when the switch happened
//    /// because the single event is emitted later, once this tab is closed out.
//    @State private var openTabReferrer: String?
//
//
//    func body(content: Content) -> some View {
//        content
//            .task(id: selection) {
//                // Master switch: don't track tab switches while AutomaticMobileViews is disabled.
//                guard NRMobileViewGate.isFeatureEnabled else { return }
//
//                // Reported as soon as the selection changes. There is no settling delay: flicking
//                // through tabs to reach a distant one records every tab passed through, because the
//                // agent no longer decides which selections were "real" on the customer's behalf.
//                let now = NRMAViewContext.monotonicNow()
//                let id = UUID().uuidString
//                let viewName = name(selection)
//
//                // Make the tab current *before* closing the previous one: the new tab then lands on
//                // top of the visible stack, so the outgoing tab is buried by the time it is removed
//                // and cannot uncover a phantom re-appearance. The referrer is the tab just left,
//                // carried on that tab's own event rather than read from the context at emit time.
//                // loadStartTime is nil: selecting a tab constructs nothing, so there is no
//                // construction start to time. That withholds the timeToInitialDisplay baseline for
//                // tab switches and makes marks on a tab measure from the appear instant.
//                NRMAViewContext.sharedInstance().transition(
//                    toView: viewName,
//                    instanceId: id,
//                    appearTime: now,
//                    loadStartTime: nil,
//                    platform: "SwiftUI")
//
//                let outgoingTab = openTabName
//                closeOpenTab(at: now)
//
//                openTabName     = viewName
//                openTabInstance = id
//                openTabSince    = now
//                openTabReferrer = outgoingTab
//            }
//            // The whole TabView going away must still close the tab that was open, or the last tab of
//            // every session silently loses its timeVisible.
//            .onDisappear {
//                guard NRMobileViewGate.isFeatureEnabled else { return }
//                closeOpenTab(at: NRMAViewContext.monotonicNow())
//                openTabName     = nil
//                openTabInstance = nil
//                openTabSince    = nil
//                openTabReferrer = nil
//            }
//    }
//
//    /// Emits the event for whichever tab is currently open.
//    private func closeOpenTab(at when: Double) {
//        guard let priorName = openTabName,
//              let priorId = openTabInstance,
//              let priorSince = openTabSince else { return }
//
//        let timeVisibleMs = NRMAViewContext.millisecondsBetween(priorSince, and: when)
//
//        // No loadTime: selecting a tab constructs nothing measurable, so the pair is omitted
//        // rather than zeroed and the reason is recorded instead.
//        MobileViewRecord(viewName: priorName,
//                         viewClass: String(describing: Tag.self),
//                         instanceId: priorId,
//                         platform: .swiftUI,
//                         referrer: .explicit(name: openTabReferrer, instanceId: nil),
//                         load: .unavailable(.noConstructionObserved),
//                         timeVisibleMs: timeVisibleMs,
//                         navigationKind: "tab").emit()
//
//        NRMAViewContext.sharedInstance().viewDidDisappearNamed(priorName, instanceId: priorId)
//    }
//}
//
#endif
