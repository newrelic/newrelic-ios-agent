//
//  NRCMView.swift
//  Agent
//
//  Created by Chris Dillard on 10/10/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

public struct NRConditionalMaskView<Content: View>: View {
    private let maskApplicationText: Bool?
    private let maskUserInputText: Bool?
    private let maskAllImages: Bool?
    private let maskAllUserTouches: Bool?
    private let blockView: Bool?
    
    private let sessionReplayIdentifier: String?
    
    private let activated: Bool
    
    private let content: () -> Content
    
    public init(maskApplicationText: Bool? = nil,
                maskUserInputText: Bool? = nil,
                maskAllImages: Bool? = nil,
                maskAllUserTouches: Bool? = nil,
                blockView: Bool? = nil,
                sessionReplayIdentifier: String? = nil,
                
                activated: Bool = true,
                @ViewBuilder content: @escaping () -> Content) {
        self.maskApplicationText = maskApplicationText
        self.maskUserInputText = maskUserInputText
        self.maskAllImages = maskAllImages
        self.maskAllUserTouches = maskAllUserTouches
        self.blockView = blockView
        self.sessionReplayIdentifier = sessionReplayIdentifier
        self.activated = activated
        self.content = content
    }
    
    public var body: some View {
        
        let iOS15 = ProcessInfo.processInfo.operatingSystemVersion.majorVersion <= 15
        if activated && !iOS15 {
            NRMaskedViewRepresentable(maskApplicationText: self.maskApplicationText,
                                      maskUserInputText: self.maskUserInputText,
                                      maskAllImages: self.maskAllImages,
                                      maskAllUserTouches: self.maskAllUserTouches,
                                      blockView: self.blockView,
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
