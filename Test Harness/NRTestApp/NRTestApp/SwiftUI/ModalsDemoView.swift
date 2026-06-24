//
//  ModalsDemoView.swift
//  NRTestApp
//
//  Exercises the MobileViews POC sheet / fullScreenCover / popover wrappers
//  (NRMobileSheet, NRMobileFullScreenCover, NRMobilePopover) so we can verify
//  that presenting modal content emits MobileView events tagged with the
//  view name we pass in.
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
            Text("Modal Presentations")
                .font(.largeTitle)

            Button("Present Sheet (isPresented)") { showSheet = true }
                .buttonStyle(.borderedProminent)

            Button("Present Sheet (item)") {
                selectedDetail = DetailItem(title: "Detail A")
            }
            .buttonStyle(.bordered)

            Button("Present Full-Screen Cover") { showFullScreenCover = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

            Button("Present Popover") { showPopover = true }
                .buttonStyle(.bordered)

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
        .NRTrackView(name: "ModalsDemoView")
        .NRMobileView(name: "ModalsDemoView")
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
