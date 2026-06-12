import SwiftUI

struct MessagesView: View {
    @EnvironmentObject var appState: AppState
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appState.messages) { msg in
                            HStack {
                                if msg.fromUser { Spacer() }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(msg.body)
                                        .padding(10)
                                        .background(msg.fromUser ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(msg.timeLabel).font(.caption2).foregroundStyle(.secondary)
                                }
                                if !msg.fromUser { Spacer() }
                            }
                        }
                    }
                    .padding()
                }
                HStack {
                    TextField("Message Support", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        guard !draft.isEmpty else { return }
                        appState.messages.append(
                            ChatMessage(fromUser: true, body: draft, timeLabel: "Now")
                        )
                        draft = ""
                    }
                }
                .padding()
            }
            .navigationTitle("Support")
        }
    }
}
