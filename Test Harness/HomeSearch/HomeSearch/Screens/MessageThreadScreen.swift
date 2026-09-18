//
//  MessageThreadScreen.swift
//  HomeSearch
//
//  One conversation. Named by the destination closure in InboxTab, so there is no MobileViews call
//  in this file.
//

import SwiftUI

struct MessageThreadScreen: View {

    let threadID: MessageThread.ID

    @Environment(ListingStore.self) private var store
    @State private var draft = ""

    var body: some View {
        Group {
            if let thread = store.thread(threadID) {
                content(for: thread)
            } else {
                ContentUnavailableView(
                    "Conversation unavailable",
                    systemImage: "envelope.badge.questionmark"
                )
            }
        }
    }

    private func content(for thread: MessageThread) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(thread.messages) { message in
                        bubble(for: message, correspondent: thread.correspondent)
                    }
                }
                .padding()
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Message \(thread.correspondent)", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)

                Button {
                    // Local only — this app has no message backend, and sending is not the point.
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .navigationTitle(thread.correspondent)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bubble(for message: MessageThread.Message, correspondent: String) -> some View {
        HStack {
            if !message.fromAgent { Spacer(minLength: 40) }

            VStack(alignment: message.fromAgent ? .leading : .trailing, spacing: 4) {
                Text(message.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        message.fromAgent ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.tint),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(message.fromAgent ? Color.primary : Color.white)

                Text(message.sentAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.fromAgent { Spacer(minLength: 40) }
        }
    }
}
