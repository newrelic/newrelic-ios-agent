//
//  ModalsDemoView.swift
//  NRTestApp
//
//  Exercises the MobileViews POC sheet / fullScreenCover / popover wrappers
//  (NRMobileSheet, NRMobileFullScreenCover, NRMobilePopover) so we can verify
//  that presenting modal content emits MobileView events tagged with the
//  view name we pass in.
//
//  Two levels of nesting to keep straight. Each *modal* reports as a view in its own right with
//  "ModalsDemoView" as its referrer, and dismissing it should make ModalsDemoView current again.
//  Each *section* of this screen also reports as a view, but tagged component: true /
//  componentOf: "ModalsDemoView" — a modal is a destination, a component is a part of a screen, and
//  viewName alone cannot tell them apart.
//
//  The screen opts into `startsInteraction: true` so there is one interaction for the section load
//  segments to land in; without it the components would have no breakdown table to populate.
//

import SwiftUI

struct ModalsDemoView: View {
    @State private var showSheet = false
    @State private var showFullScreenCover = false
    @State private var showPopover = false
    @State private var selectedDetail: DetailItem?

    struct DetailItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
    }

    var body: some View {
        VStack(spacing: 16) {
            header.NRMobileView(name: Component.header.rawValue,
                                attributes: Component.attributes)

            sheetTriggers.NRMobileView(name: Component.sheetTriggers.rawValue,
                                       attributes: Component.attributes)

            coverTrigger.NRMobileView(name: Component.coverTrigger.rawValue,
                                      attributes: Component.attributes)

            popoverTrigger.NRMobileView(name: Component.popoverTrigger.rawValue,
                                        attributes: Component.attributes)

            Spacer()
        }
        .padding()
        .navigationTitle("Modals")
        .NRMobileSheet(isPresented: $showSheet, name: "ModalsDemo.Sheet") {
            SheetDetailView(title: "Sheet (isPresented)") { showSheet = false }
        }
        .NRMobileSheet(item: $selectedDetail,
                       name: { "ModalsDemo.Sheet.\($0.title)" }) { item in
            SheetDetailView(title: item.title) { selectedDetail = nil }
        }
        .NRMobileFullScreenCover(isPresented: $showFullScreenCover,
                                 name: "ModalsDemo.FullScreenCover") {
            FullScreenDetailView { showFullScreenCover = false }
        }
        .NRMobilePopover(isPresented: $showPopover,
                         name: "ModalsDemo.Popover") {
            PopoverDetailView { showPopover = false }
        }
        .NRTrackView(name: Self.screenName)
        .NRMobileView(name: Self.screenName, startsInteraction: true)
    }

    // MARK: - Component-level views

    private static let screenName = "ModalsDemoView"

    /// The sections of this screen, each tracked as a view in its own right.
    ///
    /// These take the default `startsInteraction: false`, so they open no trace of their own — each
    /// records a load segment against the interaction the screen opens above, which is what puts
    /// several `Method/MobileView/<component>` rows into a *single* interaction's breakdown table
    /// instead of the one row naming the screen.
    ///
    /// Names are dot-separated rather than slash-separated on purpose: `/` is one of the characters
    /// `+[NewRelicInternalUtils cleanseStringForCollector:]` rewrites to `_`, and it is also the
    /// separator in the `Method/<class>/<method>` metric grammar these names land in.
    ///
    /// They share the `ModalsDemo.` prefix with the modal view names above, and are told apart from
    /// them by the `component` attribute rather than by the name.
    private enum Component: String {
        case header         = "ModalsDemo.Header"
        case sheetTriggers  = "ModalsDemo.SheetTriggers"
        case coverTrigger   = "ModalsDemo.CoverTrigger"
        case popoverTrigger = "ModalsDemo.PopoverTrigger"

        /// Marks the emitted MobileView events as components rather than screens or modals.
        static let attributes: [String: Any] = [
            "component": true,
            "componentOf": ModalsDemoView.screenName,
        ]
    }

    // MARK: - Sections

    private var header: some View {
        Text("Modal Presentations")
            .font(.largeTitle)
    }

    private var sheetTriggers: some View {
        VStack(spacing: 16) {
            Button("Present Sheet (isPresented)") { showSheet = true }
                .buttonStyle(.borderedProminent)

            Button("Present Sheet (item)") {
                selectedDetail = DetailItem(title: "Detail A")
            }
            .buttonStyle(.bordered)
        }
    }

    private var coverTrigger: some View {
        Button("Present Full-Screen Cover") { showFullScreenCover = true }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
    }

    private var popoverTrigger: some View {
        Button("Present Popover") { showPopover = true }
            .buttonStyle(.bordered)
    }
}

private struct SheetDetailView: View {
    let title: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(title).font(.title)
            Text("This view is presented in a sheet and should emit a MobileView event on appear/disappear.")
                .multilineTextAlignment(.center)
                .padding()
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct FullScreenDetailView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [.orange.opacity(0.4), .red.opacity(0.3)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Full-Screen Cover").font(.largeTitle)
                Text("Tracked via NRMobileFullScreenCover.")
                    .multilineTextAlignment(.center)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
            }
            .padding()
        }
    }
}

private struct PopoverDetailView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Popover").font(.headline)
            Text("Tracked via NRMobilePopover.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Close", action: onDismiss)
        }
        .padding()
        .frame(minWidth: 220)
    }
}

struct ModalsDemoView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { ModalsDemoView() }
    }
}
