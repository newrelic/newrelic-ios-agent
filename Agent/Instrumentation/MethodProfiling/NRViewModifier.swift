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

// MARK: - MobileViews POC: SwiftUI support

/// NRMobileViewModifier emits a MobileView custom event on appear and disappear.
/// Tracks loadTime (onAppear - modifier init), timeVisible (disappear - appear), and
/// viewInstanceId per appearance, matching the UIKit NRMAMobileViewTracker schema.
@available(iOS 13, tvOS 13, *)
internal struct NRMobileViewModifier: SwiftUI.ViewModifier {
    
    let viewName: String
    let viewClass: String
    
    @State private var appearTime: Date?
    @State private var instanceId: String?
    @State private var hasAppearedBefore: Bool = false
    
    // Approximation of "load time": modifier creation → onAppear
    private let modifierCreatedAt = Date()
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if NRMA_ShouldSkipViewName(viewName) { return }

                let now = Date()
                let id = UUID().uuidString
                appearTime = now
                instanceId = id
                
                //                // loadTime: modifier creation (≈ view body evaluation) → onAppear
                                let loadTimeSec = now.timeIntervalSince(modifierCreatedAt)
                //
                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewClass":      viewClass,
                    "viewName":       viewName,
                    "viewInstanceId": id,
                    "restarted":      NSNumber(value: hasAppearedBefore),
                    "loadTime":       NSNumber(value: max(loadTimeSec, 0.0)),
                    "appeared":       NSNumber(value: true),
                    //"timeVisible":    NSNumber(value: 0.0), // placeholder until disappear
                    "uiPlatform":       "SwiftUI",
                ])
            }
            .onDisappear {
                if NRMA_ShouldSkipViewName(viewName) { return }

                let disappearTime = Date()
                guard let appeared = appearTime, let id = instanceId else { return }
                
                let timeVisibleSec = disappearTime.timeIntervalSince(appeared)
               // let loadTimeSec    = appeared.timeIntervalSince(modifierCreatedAt)
                
                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewClass":      viewClass,
                    "viewName":       viewName,
                    "viewInstanceId": id,
                    "restarted":      NSNumber(value: hasAppearedBefore),
//                    "loadTime":       NSNumber(value: max(loadTimeSec, 0.0)),
                    "timeVisible":    NSNumber(value: max(timeVisibleSec, 0.0)),
                    "uiPlatform":       "SwiftUI",
                    "appeared":       NSNumber(value: false),
                ])
                
                hasAppearedBefore = true
                appearTime = nil
                instanceId = nil
            }
    }
}

/// Attach this modifier to SwiftUI views to emit MobileView events.
/// Enable via NRFeatureFlag_MobileViews.
@available(iOS 13, tvOS 13, *)
public extension SwiftUI.View {
    func NRMobileView(name: String? = nil) -> some View {
        // String(reflecting:) produces a noisy generic modifier stack when views are chained
        // (e.g. "SwiftUI.ModifiedContent<SwiftUI.ModifiedContent<...>>"), so we use
        // String(describing:) for a clean simple name, or the caller-supplied name if given.
        let simpleName = String(describing: type(of: self))
        let resolved   = name ?? simpleName
        return modifier(NRMobileViewModifier(
            viewName:  resolved,
            viewClass: resolved
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
                // cancelled if selection changes again within dwell window
                do {
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch { return }
                //emitDisappearIfNeeded()
                let id = UUID().uuidString
                lastFiredAt = Date()
                lastInstance = id
                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewName": name(selection),
                    "viewClass": String(describing: Tag.self),
                    "viewInstanceId": id,
                    "uiPlatform": "SwiftUI",
                    "navigationKind": "tab",
                    "dwellThreshold": 0.5,
                    // loadTime ≈ 0 for tab switches; semantics caveat in docs
                ])
            }
    }
    // emitDisappearIfNeeded() fires a closing event with timeVisible
}

#endif
