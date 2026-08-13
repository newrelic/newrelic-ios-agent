import SwiftUI

struct CaptureViewerView: View {
    @ObservedObject private var store = NRCaptureServer.shared
    @State private var verifySummary: NRCaptureServer.VerifySummary?

    var body: some View {
        NavigationView {
            Group {
                if store.captures.isEmpty {
                    emptyState
                } else {
                    captureList
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Verify All") {
                            store.verifyAll { summary in
                                verifySummary = summary
                            }
                        }
                        .disabled(store.captures.isEmpty)
                        Button("Clear") { store.captures.removeAll() }
                            .disabled(store.captures.isEmpty)
                    }
                }
            }
            .alert("Verification Results", isPresented: .init(
                get: { verifySummary != nil },
                set: { if !$0 { verifySummary = nil } }
            )) {
                Button("OK") { verifySummary = nil }
            } message: {
                if let s = verifySummary {
                    Text(alertMessage(for: s))
                }
            }
        }
    }

    private func alertMessage(for s: NRCaptureServer.VerifySummary) -> String {
        var lines: [String] = ["Verified \(s.total) capture\(s.total == 1 ? "" : "s")"]
        lines.append("\(s.passed) passed  ·  \(s.failed) failed")
        if s.duplicates > 0 {
            lines.append("\(s.duplicates) duplicate\(s.duplicates == 1 ? "" : "s") detected")
        }
        if s.unverified > 0 {
            lines.append("\(s.unverified) without a verifier (unknown endpoint)")
        }
        return lines.joined(separator: "\n")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("Waiting for agent uploads…")
                .foregroundColor(.secondary)
            Text("Capture mode must be enabled in NRAPI-Info.plist")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var captureList: some View {
        List(store.captures) { capture in
            NavigationLink(destination: CaptureDetailView(capture: capture)) {
                HStack(alignment: .top, spacing: 10) {
                    VerificationBadge(result: capture.verification)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(capture.endpoint)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.semibold)
                        Text(capture.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(capture.summary)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct CaptureDetailView: View {
    let capture: CapturedRequest
    @State private var copied = false
    @State private var bodyRequested = false
    @State private var bodyReady = false

    private var isLargePayload: Bool { capture.prettyJSON.count > 10_000 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerInfo
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                if let result = capture.verification {
                    Divider()
                    VerificationSection(result: result)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }

                Divider()
                if isLargePayload && !bodyReady {
                    if bodyRequested {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading \(capture.prettyJSON.count / 1024) KB…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        // Defer the heavy Text render to the next frame so the spinner
                        // is committed to the display list before layout is blocked.
                        .onAppear {
                            DispatchQueue.main.async { bodyReady = true }
                        }
                    } else {
                        Button {
                            bodyRequested = true
                        } label: {
                            Label("Show body (\(capture.prettyJSON.count / 1024) KB)", systemImage: "chevron.down.circle")
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                } else {
                    Text(capture.prettyJSON)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(capture.endpoint.components(separatedBy: "/").last ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(copied ? "Copied!" : "Copy") {
                    UIPasteboard.general.string = capture.prettyJSON
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }
            }
        }
    }

    private var headerInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(capture.endpoint, systemImage: "network")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.accentColor)
            if #available(iOS 15.0, *) {
                Text(capture.timestamp.formatted(date: .abbreviated, time: .complete))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 12)
    }
}

// MARK: - Shared verification UI

struct VerificationBadge: View {
    let result: VerificationResult?

    var body: some View {
        Group {
            if let result {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 18))
    }
}

struct VerificationSection: View {
    let result: VerificationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.passed ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundColor(result.passed ? .green : .red)
                Text(result.passed ? "All checks passed" : "\(result.failCount) check\(result.failCount == 1 ? "" : "s") failed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(result.passed ? .green : .red)
            }
            ForEach(result.checks) { c in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: c.passed ? "checkmark" : "xmark")
                        .foregroundColor(c.passed ? .green : .red)
                        .font(.caption.weight(.bold))
                        .frame(width: 14)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(c.name)
                            .font(.caption)
                            .foregroundColor(c.passed ? .primary : .red)
                        if let detail = c.detail {
                            Text(detail)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
