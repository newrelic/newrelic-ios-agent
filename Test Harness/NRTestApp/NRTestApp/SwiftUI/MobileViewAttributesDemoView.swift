//
//  MobileViewAttributesDemoView.swift
//  NRTestApp
//
//  Demonstrates the `attributes:` parameter on `.NRMobileView(...)`.
//  Every MobileView event emitted (appear/disappear) carries the supplied
//  custom attributes alongside the standard schema.
//

import SwiftUI

struct MobileViewAttributesDemoView: View {

    // Bumping any of these causes SwiftUI to re-evaluate the body, which
    // recreates the modifier with the new attribute values. The next
    // appear/disappear emits will reflect them.
    @State private var userId: String = "user-42"
    @State private var experimentVariant: String = "control"
    @State private var visitCounter: Int = 1

    private var customAttrs: [String: Any] {
        [
            "userId":            userId,
            "experimentVariant": experimentVariant,
            "visitCounter":      visitCounter,
            "feature":           "mobile-views",
            "isPremium":         true,
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Custom Attributes Demo (SwiftUI)")
                    .font(.title2).bold()

                Text("This view attaches custom attributes via `.NRMobileView(attributes:)`. Each MobileView event emitted on appear/disappear includes these key/value pairs alongside the standard schema (viewClass, viewName, viewInstanceId, etc.).")
                    .font(.callout)

                GroupBox(label: Text("Attributes being sent")) {
                    VStack(alignment: .leading, spacing: 6) {
                        attrRow("userId", userId)
                        attrRow("experimentVariant", experimentVariant)
                        attrRow("visitCounter", "\(visitCounter)")
                        attrRow("feature", "mobile-views")
                        attrRow("isPremium", "true")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Picker("Variant", selection: $experimentVariant) {
                    Text("control").tag("control")
                    Text("treatment-A").tag("treatment-A")
                    Text("treatment-B").tag("treatment-B")
                }
                .pickerStyle(.segmented)

                HStack {
                    Button("user-42") { userId = "user-42" }
                    Button("user-99") { userId = "user-99" }
                    Spacer()
                    Stepper("visitCounter: \(visitCounter)", value: $visitCounter, in: 0...999)
                }

                Text("Tip: pop this view (back) and re-enter to emit a fresh appear/disappear pair containing the most recent values. Inspect the New Relic console for `MobileView` events.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationBarTitle("Custom Attrs", displayMode: .inline)
        .NRMobileView(name: "MobileViewAttributesDemoView",
                      attributes: customAttrs)
    }

    private func attrRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(.footnote, design: .monospaced))
            Spacer()
            Text(value).font(.system(.footnote, design: .monospaced)).foregroundColor(.blue)
        }
    }
}
