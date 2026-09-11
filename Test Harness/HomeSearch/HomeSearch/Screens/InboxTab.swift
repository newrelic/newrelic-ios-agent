//
//  InboxTab.swift
//  HomeSearch
//
//  Agent conversations. This is where dynamic view naming is exercised: each thread reports as
//  "Message Thread — <correspondent>" rather than a single shared name.
//
//  Cardinality is bounded by the thread fixture, which is the condition that makes dynamic naming
//  reasonable. Listing Detail takes the opposite approach for the opposite reason — see the note in
//  ViewName.
//

import SwiftUI
import NewRelic

struct InboxTab: View {

    @Environment(ListingStore.self) private var store

    @State private var path: [InboxRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.threads.isEmpty {
                    ContentUnavailableView(
                        "No messages",
                        systemImage: "envelope",
                        description: Text("Agents you contact will reach you here.")
                    )
                } else {
                    List(store.threads) { thread in
                        Button {
                            path.append(.thread(thread.id))
                        } label: {
                            ThreadRow(thread: thread)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Inbox")
            .NRMobileView(name: ViewName.inbox.rawValue)
            // The name closure resolves the thread and names the view after the correspondent, so
            // this one destination declaration produces four distinct view names.
            .NRMobileDestination(for: InboxRoute.self, name: { route in
                switch route {
                case .thread(let id):
                    let correspondent = store.thread(id)?.correspondent ?? "Unknown"
                    return ViewName.messageThread(with: correspondent)
                }
            }) { route in
                switch route {
                case .thread(let id):
                    MessageThreadScreen(threadID: id)
                }
            }
        }
    }
}

private struct ThreadRow: View {

    let thread: MessageThread

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Text(thread.correspondent
                        .split(separator: " ")
                        .compactMap(\.first)
                        .map(String.init)
                        .joined())
                        .font(.subheadline.weight(.semibold))
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.correspondent)
                        .font(.subheadline.weight(thread.unread ? .bold : .regular))
                    if thread.unread {
                        Circle().fill(.blue).frame(width: 7, height: 7)
                    }
                    Spacer()
                }
                Text(thread.brokerage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(thread.preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
