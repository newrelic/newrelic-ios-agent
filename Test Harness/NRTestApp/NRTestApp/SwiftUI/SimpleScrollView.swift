//
//  SimpleScrollView.swift
//  NRTestApp
//
//  Created by GitHub Copilot on 10/23/25.
//

import SwiftUI

struct SimpleScrollView: View {
    @State private var deepMasked: String = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Spacer to push content off-screen initially
                Text("Scroll down to see content")
                    
                Spacer()
                    .frame(height: UIScreen.main.bounds.height)
                    .id("top")
                
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                            
                            Text("Level 2 (no id)")
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            NRConditionalMaskView(sessionReplayIdentifier: "my-masked-id") {

                                Text("Level 3 Explicit Masked")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Level 4 inherits masked ancestor")
                                    TextField("Deep masked field", text: $deepMasked)
                                        .textFieldStyle(.roundedBorder)
                                }
                                .padding(6)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                        .padding(6)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.09))
                .cornerRadius(10)
                .id("content")
                }
            }
            .padding()
        }
        .navigationTitle("Simple Scroll View")
    }
}

#Preview {
    SimpleScrollView()
}
