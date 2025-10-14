//
//  MaskingView.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/2/25.
//

import SwiftUI
import NewRelic

struct MaskingView: View {
    @State private var maskedInput: String = ""
    @State private var unmaskedInput: String = ""
    @State private var deepMasked: String = ""
    @State private var deepUnmasked: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                sectionTitle("Direct Elements (Single Controls)")
                VStack(alignment: .leading, spacing: 12) {
                    NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                        TextField("Masked TextField", text: $maskedInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                        TextField("Unmasked TextField", text: $unmaskedInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    NRConditionalMaskView(maskApplicationText: true) {
                        
                        Text("Masked Text")
                    }

                    NRConditionalMaskView(maskApplicationText: false) {
                        
                        Text("Unmasked Text")
                    }
                }

                sectionTitle("Parent Masked → Children Inherit (no explicit child id)")
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Child Label A")
                            Text("Child Label B")
                            TextField("Implicit masked inheritance?", text: $maskedInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.07))
                        .cornerRadius(8)
                    }
                }

                sectionTitle("Parent Masked → Child Override Unmasked")
                
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Inherited Masked Label")
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                            
                            Text("Explicit Unmasked Override")
                            TextField("Child unmasked override", text: $unmaskedInput)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Parent Unmasked → Child Explicit Masked")
                
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                    
                    VStack(alignment: .leading, spacing: 6) {
                        NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                            
                            Text("Child Masked Explicit")
                            TextField("Masked inside unmasked parent", text: $deepMasked)
                                .textFieldStyle(.roundedBorder)
                        }
                        Text("Sibling Unmasked (inherits parent)")
                    }
                    .padding()
                    .background(Color.green.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Deep Nesting (Mixed Overrides)")

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
                }

                sectionTitle("Sibling Mix (Explicit IDs on Each)")
                HStack {
                    NRConditionalMaskView(sessionReplayIdentifier: "masked-1") {
                        
                        Text("Masked")
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                    NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                        
                        Text("Unmasked")
                            .padding(8)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                    }
                    NRConditionalMaskView(sessionReplayIdentifier: "masked-2") {
                        
                        Text("Masked 2")
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    }
                }

                sectionTitle("Reuse In Subview (Parameter Controlled)")
                
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    
                    MaskableRow(title: "Reusable Row (Masked)", masked: true)
                }
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                    
                    MaskableRow(title: "Reusable Row (Unmasked)", masked: false)
                }

                sectionTitle("NavigationLink Within Masked Parent")
                
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Link inherits mask unless overridden")
                        NavigationLink("Go To TextFieldsView (inherits parent)") {
                            TextFieldsView()
                        }
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                            
                            NavigationLink("Override Unmasked Link") {
                                TextFieldsView()
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Masking Permutations")
        .NRTrackView(name: "MaskingPermutationsView")
    }

    private func sectionTitle(_ text: String) -> some View {
        NRConditionalMaskView(maskApplicationText: false, maskAllUserTouches: false) {
            
            Text(text)
                .font(.headline)
            //            .accessibilityHidden(true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MaskableRow: View {
    let title: String
    let masked: Bool
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: masked ? "eye.slash" : "eye")
        }
        .padding(8)
        .background(masked ? Color.blue.opacity(0.07) : Color.gray.opacity(0.12))
        .cornerRadius(8)
    }
}

#Preview {
    MaskingView()
}
