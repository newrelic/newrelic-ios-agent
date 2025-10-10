//
//  MaskingView.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/2/25.
//

import SwiftUI

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
                    TextField("Masked TextField", text: $maskedInput)
                        .textFieldStyle(.roundedBorder)
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                        .id("nr-mask")

                    TextField("Unmasked TextField", text: $unmaskedInput)
                        .textFieldStyle(.roundedBorder)
                        //.accessibilityIdentifier("nr-unmask")
                        .nrUnmasked()
                        .id("nr-unmask")

                    Text("Masked Text")
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                        .id("nr-mask")

                    Text("Unmasked Text")
                       // .accessibilityIdentifier("nr-unmask")
                        .nrUnmasked()
                }

                sectionTitle("Parent Masked → Children Inherit (no explicit child id)")
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
                    //.accessibilityIdentifier("nr-mask")
                    .nrMasked()
                }

                sectionTitle("Parent Masked → Child Override Unmasked")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Inherited Masked Label")
                    Text("Explicit Unmasked Override")
                        .accessibilityIdentifier("nr-unmask")
                        .nrUnmasked()
                    TextField("Child unmasked override", text: $unmaskedInput)
                        .textFieldStyle(.roundedBorder)
                        //.accessibilityIdentifier("nr-unmask")
                        .nrUnmasked()
                }
                .padding()
                .background(Color.purple.opacity(0.07))
                .cornerRadius(8)
                //.accessibilityIdentifier("nr-mask")
                .nrMasked()

                sectionTitle("Parent Unmasked → Child Explicit Masked")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Child Masked Explicit")
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                    TextField("Masked inside unmasked parent", text: $deepMasked)
                        .textFieldStyle(.roundedBorder)
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                    Text("Sibling Unmasked (inherits parent)")
                }
                .padding()
                .background(Color.green.opacity(0.07))
                .cornerRadius(8)
                .accessibilityIdentifier("nr-unmask")
                .nrUnmasked()

                sectionTitle("Deep Nesting (Mixed Overrides)")
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Level 2 (no id)")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Level 3 Explicit Masked")
                                //.accessibilityIdentifier("nr-mask")
                                .nrMasked()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Level 4 inherits masked ancestor")
                                TextField("Deep masked field", text: $deepMasked)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(6)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(6)
                        }
                        .padding(6)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.09))
                .cornerRadius(10)
                .accessibilityIdentifier("nr-unmask")
                .nrUnmasked()

                sectionTitle("Sibling Mix (Explicit IDs on Each)")
                HStack {
                    Text("Masked")
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                    Text("Unmasked")
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                        .accessibilityIdentifier("nr-unmask")
                        .nrUnmasked()
                    Text("Masked 2")
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        //.accessibilityIdentifier("nr-mask")
                        .nrMasked()
                }

                sectionTitle("Reuse In Subview (Parameter Controlled)")
                MaskableRow(title: "Reusable Row (Masked)", masked: true)
                MaskableRow(title: "Reusable Row (Unmasked)", masked: false)

                sectionTitle("NavigationLink Within Masked Parent")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link inherits mask unless overridden")
                    NavigationLink("Go To TextFieldsView (inherits parent)") {
                        TextFieldsView()
                    }
                    .accessibilityIdentifier("inherited-link")
                    .nrMaskingIdentifier("inherited-link")
                    
                    NavigationLink("Override Unmasked Link") {
                        TextFieldsView()
                    }
                    .accessibilityIdentifier("nr-unmask")
                    .nrUnmasked()
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .cornerRadius(8)
                //.accessibilityIdentifier("nr-mask")
                .nrMasked()
            }
            .padding()
        }
        .navigationTitle("Masking Permutations")
        .NRTrackView(name: "MaskingPermutationsView")
        .onAppear {
            let _ = ViewBodyTracker.track(self)  // ← At top level view
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityIdentifier(masked ? "nr-mask" : "nr-unmask")
        .nrMasking(masked)
    }
}

#Preview {
    MaskingView()
}
