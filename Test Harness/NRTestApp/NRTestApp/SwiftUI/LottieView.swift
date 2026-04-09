//
//  LottieView.swift
//  New Relic
//
//  Created by Anish Gupta on 24/01/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI
import Lottie

enum LottieFile {
    static let Loader = "Loader.json"
}

enum LottieSpeed: Double {
    case loader = 1.25
}

struct LottieConfig {
    private(set) var fileName: String
    private(set) var speed: LottieSpeed
}

struct Lottie: View {
    private var config: LottieConfig
    
    @Binding private var isAnimating: Bool
    @State private var playbackMode: LottiePlaybackMode
    
    init(isAnimating: Binding<Bool>, config: LottieConfig) {
        self._isAnimating = isAnimating
        _playbackMode = State(initialValue: isAnimating.wrappedValue ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)) : .paused(at: .progress(1)))
        self.config = config
    }
    
    var body: some View {
        LottieView(animation: .named(config.fileName))
            .playbackMode(playbackMode)
            .animationSpeed(config.speed.rawValue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifyIf(!isAnimating) {
                $0.hidden()
            }
            .onAppear {
              playbackMode = isAnimating ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)) : .paused(at: .progress(1))
            }
            .onChange(of: isAnimating) { newValue in
                playbackMode = isAnimating ? .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)) : .paused(at: .progress(1))
            }
    }
}
