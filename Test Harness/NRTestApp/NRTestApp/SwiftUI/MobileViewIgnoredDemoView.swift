//
//  MobileViewIgnoredDemoView.swift
//  NRTestApp
//
//  Demonstrates the `ignored:` parameter on `.NRMobileView(...)`.
//  When ignored is true, the modifier suppresses both appear and disappear
//  emissions for the view it's attached to.
//

import SwiftUI

struct MobileViewIgnoredDemoView: View {

    @State private var ignoreOuter: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ignored Demo (SwiftUI)")
                    .font(.title2).bold()

                Text("This view is attached with `.NRMobileView(ignored: true)`. With `ignored == true`, the modifier emits NO MobileView events on appear or disappear — useful for skipping shells, splash screens, or any container you don't want measured.")
                    .font(.callout)

                Toggle("ignored = \(ignoreOuter ? "true" : "false")", isOn: $ignoreOuter)

                GroupBox(label: Text("Expected behavior")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(ignoreOuter
                              ? "No MobileView events for THIS view"
                              : "Normal MobileView events emitted",
                              systemImage: ignoreOuter ? "eye.slash" : "eye")
                            .foregroundColor(ignoreOuter ? .red : .green)
                        Text("Tip: change the toggle, then pop and re-push this view from the list to test both modes.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox(label: Text("Nested child (always tracked)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The child below uses the default `ignored: false`, so it emits its own MobileView events even though its parent is ignored. This proves the flag is per-modifier, not propagated.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Text("Tracked nested child")
                            .font(.headline)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                            .NRMobileView(name: "MobileViewIgnoredDemo.Child")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationBarTitle("Ignored", displayMode: .inline)
        .NRMobileView(name: "MobileViewIgnoredDemoView",
                      ignored: ignoreOuter)
    }
}
