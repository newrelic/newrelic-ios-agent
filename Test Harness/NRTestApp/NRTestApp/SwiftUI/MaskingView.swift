//
//  MaskingView.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/2/25.
//

import SwiftUI

private extension Color {
    // Expected-outcome colors for the inheritance scenarios: masked is blue, unmasked is green.
    static let maskedColor = Color.blue
    static let unmaskedColor = Color.green
}

struct MaskingView: View {
    // Each TextField gets its own backing state so typing in one field never
    // updates another. (Previously several fields shared maskedInput/unmaskedInput/
    // deepMasked, which caused duplicated values across unrelated rows.)
    @State private var maskedInput: String = ""
    @State private var unmaskedInput: String = ""
    @State private var implicitMaskedInput: String = ""
    @State private var childUnmaskedInput: String = ""
    @State private var maskedInsideUnmaskedInput: String = ""
    @State private var deepMaskedInput: String = ""
    @State private var perPropInput1: String = ""
    @State private var perPropInput2: String = ""
    @State private var threeLevelInput1: String = ""
    @State private var threeLevelInput2: String = ""
    @State private var blockedFieldInput: String = "swiftui-blocked-textfield"
    @State private var blockedEditorInput: String = "swiftui-blocked-texteditor"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // blockView content whose text should never reach the replay, in colors that do or
                // don't contrast with the agent's black block box.
                sectionTitle("Blocked (blockView: true)")
                VStack(alignment: .leading, spacing: 12) {
                    NRConditionalMaskView(blockView: true) {
                        Text("swiftui-blocked-default")
                    }
                    NRConditionalMaskView(blockView: true) {
                        Text("swiftui-blocked-white")
                            .foregroundColor(.white)
                            .background(Color.gray)
                    }
                    NRConditionalMaskView(blockView: true) {
                        Text("swiftui-blocked-red")
                            .foregroundColor(.red)
                    }
                    NRConditionalMaskView(blockView: true) {
                        TextField("Blocked TextField", text: $blockedFieldInput)
                            .textFieldStyle(.roundedBorder)
                    }
                    NRConditionalMaskView(blockView: true) {
                        TextEditor(text: $blockedEditorInput)
                            .foregroundColor(.blue)
                            .frame(height: 44)
                            .border(Color.gray.opacity(0.4))
                    }
                    NRConditionalMaskView(blockView: true) {
                        VStack(alignment: .leading) {
                            Text("swiftui-blocked-container-child")
                                .foregroundColor(.green)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.yellow.opacity(0.3))
                    }
                }

                sectionTitle("Direct Elements (Single Controls)")
                VStack(alignment: .leading, spacing: 12) {
                    NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                        TextField("Masked TextField", text: $maskedInput)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.maskedColor)
                    }
                    NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                        TextField("Unmasked TextField", text: $unmaskedInput)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.unmaskedColor)
                    }

                    NRConditionalMaskView(maskApplicationText: true) {
                        
                        Text("Masked Text")
                            .foregroundColor(.maskedColor)
                    }

                    NRConditionalMaskView(maskApplicationText: false) {
                        
                        Text("Unmasked Text")
                            .foregroundColor(.unmaskedColor)
                    }
                }

                sectionTitle("Parent Masked → Children Inherit (no explicit child id)")
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Child Label A").foregroundColor(.maskedColor)
                            Text("Child Label B").foregroundColor(.maskedColor)
                            TextField("Implicit masked inheritance?", text: $implicitMaskedInput)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.maskedColor)
                        }
                        .padding()
                        .background(Color.maskedColor.opacity(0.07))
                        .cornerRadius(8)
                    }
                }

                sectionTitle("Parent Masked → Child Unmask (parent wins: child stays masked)")
                
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Inherited Masked Label").foregroundColor(.maskedColor)
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                            
                            Text("Child unmask ignored (expect masked)").foregroundColor(.maskedColor)
                            TextField("Child unmask ignored (expect masked)", text: $childUnmaskedInput)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.maskedColor)
                        }
                    }
                    .padding()
                    .background(Color.maskedColor.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Parent Unmasked → Child Explicit Masked")
                
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                    
                    VStack(alignment: .leading, spacing: 6) {
                        NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                            
                            Text("Child Masked Explicit").foregroundColor(.maskedColor)
                            TextField("Masked inside unmasked parent", text: $maskedInsideUnmaskedInput)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.maskedColor)
                        }
                        Text("Sibling Unmasked (inherits parent)").foregroundColor(.unmaskedColor)
                    }
                    .padding()
                    .background(Color.unmaskedColor.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Deep Nesting (Mixed Overrides)")
                
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                                
                                Text("Level 2 (no id)").foregroundColor(.maskedColor)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                NRConditionalMaskView(sessionReplayIdentifier: "my-masked-id") {

                                    Text("Level 3 Explicit Masked").foregroundColor(.maskedColor)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Level 4 inherits masked ancestor").foregroundColor(.maskedColor)
                                        TextField("Deep masked field", text: $deepMaskedInput)
                                            .textFieldStyle(.roundedBorder)
                                            .foregroundColor(.maskedColor)
                                    }
                                    .padding(6)
                                    .background(Color.maskedColor.opacity(0.08))
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
                            .foregroundColor(.maskedColor)
                            .padding(8)
                            .background(Color.maskedColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                        
                        Text("Unmasked")
                            .foregroundColor(.unmaskedColor)
                            .padding(8)
                            .background(Color.unmaskedColor.opacity(0.1))
                            .cornerRadius(6)
                    }
                    NRConditionalMaskView(sessionReplayIdentifier: "masked-2") {
                        
                        Text("Masked 2")
                            .foregroundColor(.maskedColor)
                            .padding(8)
                            .background(Color.maskedColor.opacity(0.1))
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

                sectionTitle("Per-Property: Masked Parent, Child Unmasks ONE Property (expect all masked)")
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllImages: true, maskAllUserTouches: true) {
                    VStack(alignment: .leading, spacing: 8) {
                        NRConditionalMaskView(maskApplicationText: false) {
                            Text("Child unmask text only").foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskUserInputText: false) {
                            TextField("Child unmask input only", text: $perPropInput1)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskAllImages: false) {
                            Image(systemName: "star.fill").foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskAllUserTouches: false) {
                            Button("Child unmask touches only") {}.foregroundColor(.maskedColor)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Per-Property: Unmasked Parent, Child Masks ONE Property (only that one masked)")
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllImages: false, maskAllUserTouches: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        NRConditionalMaskView(maskApplicationText: true) {
                            Text("Child mask text only").foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskUserInputText: true) {
                            TextField("Child mask input only", text: $perPropInput2)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskAllImages: true) {
                            Image(systemName: "star.fill").foregroundColor(.maskedColor)
                        }
                        NRConditionalMaskView(maskAllUserTouches: true) {
                            Button("Child mask touches only") {}.foregroundColor(.maskedColor)
                        }
                        Text("Sibling stays unmasked").foregroundColor(.unmaskedColor)
                    }
                    .padding()
                    .background(Color.green.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Three Levels: Masked → Unmasked → Unmasked (expect all masked)")
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllImages: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("L1 masked").foregroundColor(.maskedColor)
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllImages: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("L2 unmask (expect masked)").foregroundColor(.maskedColor)
                                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllImages: false) {
                                    Text("L3 unmask (expect masked)").foregroundColor(.maskedColor)
                                    TextField("L3 unmask input (expect masked)", text: $threeLevelInput1)
                                        .textFieldStyle(.roundedBorder)
                                        .foregroundColor(.maskedColor)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Three Levels: Unmasked → Masked → Unmasked (L2 and L3 masked)")
                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("L1 unmasked").foregroundColor(.unmaskedColor)
                        NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("L2 masked").foregroundColor(.maskedColor)
                                NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false) {
                                    Text("L3 unmask (expect masked)").foregroundColor(.maskedColor)
                                    TextField("L3 unmask input (expect masked)", text: $threeLevelInput2)
                                        .textFieldStyle(.roundedBorder)
                                        .foregroundColor(.maskedColor)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Three Levels: Unmasked → Unmasked → Masked (only L3 masked)")
                NRConditionalMaskView(maskApplicationText: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("L1 unmasked").foregroundColor(.unmaskedColor)
                        NRConditionalMaskView(maskApplicationText: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("L2 unmasked").foregroundColor(.unmaskedColor)
                                NRConditionalMaskView(maskApplicationText: true) {
                                    Text("L3 masked").foregroundColor(.maskedColor)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.07))
                    .cornerRadius(8)
                }

                sectionTitle("Unset Child Between Masked Parent and Unmask Leaf (expect masked)")
                NRConditionalMaskView(maskApplicationText: true) {
                    NRConditionalMaskView {
                        NRConditionalMaskView(maskApplicationText: false) {
                            Text("Leaf unmask through unset middle (expect masked)").foregroundColor(.maskedColor)
                        }
                    }
                }

                sectionTitle("Identifier Masking (sessionReplayIdentifier)")
                VStack(alignment: .leading, spacing: 8) {
                    NRConditionalMaskView(maskApplicationText: true) {
                        NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                            Text("Masked parent, unmask id (expect masked)").foregroundColor(.maskedColor)
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: false) {
                        NRConditionalMaskView(sessionReplayIdentifier: "masked-1") {
                            Text("Unmasked parent, mask id (expect masked)").foregroundColor(.maskedColor)
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: true) {
                        NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                            Text("SSN 123-45-6789 (masked parent, unmask id, expect masked)").foregroundColor(.maskedColor)
                        }
                    }
                    NRConditionalMaskView(maskUserInputText: true) {
                        NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                            Text("User input masked parent, unmask id (expect masked)").foregroundColor(.maskedColor)
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: true) {
                        NRConditionalMaskView {
                            NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                                Text("Masked grandparent, unmask id (expect masked)").foregroundColor(.maskedColor)
                            }
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: false) {
                        NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                            Text("Unmasked parent, unmask id (expect unmasked)").foregroundColor(.unmaskedColor)
                        }
                    }
                    NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") {
                        Text("No parent, unmask id (expect unmasked)").foregroundColor(.unmaskedColor)
                    }
                }

                sectionTitle("blockView Combinations")
                VStack(alignment: .leading, spacing: 8) {
                    NRConditionalMaskView(blockView: true) {
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false) {
                            Text("Blocked parent, unmask child (expect blocked)")
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: true) {
                        NRConditionalMaskView(blockView: true) {
                            Text("Masked parent, block child (expect blocked)")
                        }
                    }
                    NRConditionalMaskView(maskApplicationText: false) {
                        NRConditionalMaskView(blockView: true) {
                            Text("Unmasked parent, block child (expect blocked)")
                        }
                    }
                    NRConditionalMaskView(blockView: true) {
                        NRConditionalMaskView(blockView: false) {
                            Text("Blocked parent, blockView false child (expect blocked)")
                        }
                    }
                }

                sectionTitle("UIKit Tags: nr-mask / nr-unmask Inheritance")
                VStack(alignment: .leading, spacing: 8) {
                    UIKitMaskTagCase(parentTag: "nr-mask", childTag: "nr-unmask", text: "nr-mask parent, nr-unmask child (expect masked)", color: .systemBlue)
                        .frame(height: 44)
                    UIKitMaskTagCase(parentTag: "nr-unmask", childTag: "nr-mask", text: "nr-unmask parent, nr-mask child (expect masked)", color: .systemBlue)
                        .frame(height: 44)
                    UIKitMaskTagCase(parentTag: "nr-mask", childTag: nil, text: "nr-mask parent, no child tag (expect masked)", color: .systemBlue)
                        .frame(height: 44)
                    UIKitMaskTagCase(parentTag: "nr-unmask", childTag: nil, text: "nr-unmask parent, no child tag (expect unmasked)", color: .systemGreen)
                        .frame(height: 44)
                    UIKitMaskTagCase(parentTag: nil, childTag: "nr-unmask", text: "No parent tag, nr-unmask child (expect unmasked)", color: .systemGreen)
                        .frame(height: 44)
                    UIKitMaskTagCase(parentTag: "nr-block", childTag: "nr-unmask", text: "nr-block parent, nr-unmask child (expect blocked)", color: .systemRed)
                        .frame(height: 44)
                }

                sectionTitle("NavigationLink Within Masked Parent")
                
                NRConditionalMaskView(maskApplicationText: true, maskUserInputText: true, maskAllUserTouches: true) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Link inherits mask unless overridden").foregroundColor(.maskedColor)
                        NavigationLink("Go To TextFieldsView (inherits parent)") {
                            TextFieldsView()
                        }
                        .foregroundColor(.maskedColor)
                        NRConditionalMaskView(maskApplicationText: false, maskUserInputText: false, maskAllUserTouches: false) {
                            
                            NavigationLink("Child unmask ignored (expect masked)") {
                                TextFieldsView()
                            }
                            .foregroundColor(.maskedColor)
                        }
                    }
                    .padding()
                    .background(Color.maskedColor.opacity(0.08))
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

// A UIKit parent/child pair tagged with accessibility identifiers, to exercise the
// nr-mask / nr-unmask / nr-block tag inheritance in the UIKit capture path.
private struct UIKitMaskTagCase: UIViewRepresentable {
    let parentTag: String?
    let childTag: String?
    let text: String
    let color: UIColor

    func makeUIView(context: Context) -> UIView {
        let parent = UIView()
        parent.backgroundColor = color.withAlphaComponent(0.1)
        parent.accessibilityIdentifier = parentTag
        let child = UILabel()
        child.text = text
        child.font = .preferredFont(forTextStyle: .footnote)
        child.numberOfLines = 2
        child.textColor = color
        child.accessibilityIdentifier = childTag
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.centerYAnchor.constraint(equalTo: parent.centerYAnchor)
        ])
        return parent
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
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
        .foregroundColor(masked ? .maskedColor : .unmaskedColor)
        .padding(8)
        .background((masked ? Color.maskedColor : Color.unmaskedColor).opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    MaskingView()
}
