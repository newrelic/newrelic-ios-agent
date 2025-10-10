//
//  NRCMView.swift
//  Agent
//
//  Created by Chris Dillard on 10/10/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 16, *)
public struct NRConditionalMaskView<Content: View>: View {
    private let maskApplicationText: Bool
    private let maskUserInputText: Bool
    private let maskAllImages: Bool
    private let maskAllUserTouches: Bool
    
    private let sessionReplayIdentifier: Int?
    
    private let activated: Bool
    
    private let content: () -> Content
    
    public init(maskApplicationText: Bool = true,
                maskUserInputText: Bool = true,
                maskAllImages: Bool = true,
                maskAllUserTouches: Bool = false,
                sessionReplayIdentifier: Int? = nil,
                
                activated: Bool = true,
                @ViewBuilder content: @escaping () -> Content) {
        self.maskApplicationText = maskApplicationText
        self.maskUserInputText = maskUserInputText
        self.maskAllImages = maskAllImages
        self.maskAllUserTouches = maskAllUserTouches
        self.sessionReplayIdentifier = sessionReplayIdentifier
        self.activated = activated
        self.content = content
    }
    
    public var body: some View {
        // TODO: Check conditions this should be evaaluated enabled? Previews?
        if activated {
            NRMaskedViewRepresentable(maskApplicationText: self.maskApplicationText,
                                      maskUserInputText: self.maskUserInputText,
                                      maskAllImages: self.maskAllImages,
                                      maskAllUserTouches: self.maskAllUserTouches,
                                      activated: true,
                                      sessionReplayIdentifier: sessionReplayIdentifier,
                                      content: content
            )
        }
        else {
            content()
        }
    }
    
    
}


