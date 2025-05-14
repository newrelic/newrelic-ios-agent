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

#endif
