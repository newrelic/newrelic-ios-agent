//
//  MaskedContainerView.swift
//  Agent
//
//  Created by Chris Dillard on 10/10/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 16, *)
struct MaskedContainerView<Content: View>: View {
    let inputEnv: EnvironmentValues
    let content: () -> Content

    init(_ inputEnv: EnvironmentValues,
         inputContent: @escaping () -> Content) {
        self.inputEnv = inputEnv
        self.content = inputContent
    }

    var body: some View {
        // iOS 18+ handles env.
        if #available(iOS 18, *) {
            content()
        }
        else {
            content()
                .environment(\.self, inputEnv)
        }
    }
}
