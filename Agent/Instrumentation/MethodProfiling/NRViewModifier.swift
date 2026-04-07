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
                let now = Date()
                let id = UUID().uuidString
                appearTime = now
                instanceId = id

                // loadTime: modifier creation (≈ view body evaluation) → onAppear
                let loadTimeSec = now.timeIntervalSince(modifierCreatedAt)

                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewClass":      viewClass,
                    "viewName":       viewName,
                    "viewInstanceId": id,
                    "restarted":      NSNumber(value: hasAppearedBefore),
                    "loadTime":       NSNumber(value: max(loadTimeSec, 0.0)),
                    "timeVisible":    NSNumber(value: 0.0), // placeholder until disappear
                    "platform":       "SwiftUI",
                ])
            }
            .onDisappear {
                let disappearTime = Date()
                guard let appeared = appearTime, let id = instanceId else { return }

                let timeVisibleSec = disappearTime.timeIntervalSince(appeared)
                let loadTimeSec    = appeared.timeIntervalSince(modifierCreatedAt)

                NewRelic.recordCustomEvent("MobileView", attributes: [
                    "viewClass":      viewClass,
                    "viewName":       viewName,
                    "viewInstanceId": id,
                    "restarted":      NSNumber(value: hasAppearedBefore),
                    "loadTime":       NSNumber(value: max(loadTimeSec, 0.0)),
                    "timeVisible":    NSNumber(value: max(loadTimeSec, 0.0)),
                    "platform":       "SwiftUI",
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
        let typeName = String(describing: type(of: self))
        return modifier(NRMobileViewModifier(
            viewName:  name ?? typeName,
            viewClass: typeName
        ))
    }
}

#endif
