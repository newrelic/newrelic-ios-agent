import SwiftUI

struct CaptureViewerView: View {
    @ObservedObject private var store = NRCaptureServer.shared
    @State private var verifySummary: NRCaptureServer.VerifySummary?
    @State private var listedCaptures: [CapturedRequest] = []
    @State private var detailVisible = false
    @State private var showingInjectSheet = false
    @State private var showingConfigSheet = false

    var body: some View {
        NavigationView {
            Group {
                if listedCaptures.isEmpty {
                    emptyState
                } else {
                    captureList
                }
            }
            .onReceive(store.$captures) { incoming in
                // Don't update the list while a detail view is open — it would pop navigation.
                // Sync happens in captureList's onDisappear when the user returns.
                if !detailVisible {
                    listedCaptures = incoming
                }
            }
            .navigationTitle("Captures")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 10) {
                        let armed = store.injection != nil
                        Button { showingInjectSheet = true } label: {
                            Text(armed ? store.injection!.override.label : "Inject")
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                                .foregroundColor(armed ? .white : .orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(armed ? Color.orange : Color.orange.opacity(0.15))
                                .cornerRadius(6)
                        }
                        .sheet(isPresented: $showingInjectSheet) {
                            InjectErrorSheet(injection: $store.injection)
                        }

                        Button { showingConfigSheet = true } label: {
                            Image(systemName: store.connectConfigMutated
                                  ? "slider.horizontal.3"
                                  : "slider.horizontal.3")
                                .foregroundColor(store.connectConfigMutated ? .orange : .primary)
                        }
                        .sheet(isPresented: $showingConfigSheet) {
                            ConnectConfigSheet()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Verify All") {
                            store.verifyAll { summary in
                                verifySummary = summary
                            }
                        }
                        .disabled(listedCaptures.isEmpty)
                        Button("Clear") {
                            store.captures.removeAll()
                            listedCaptures = []
                        }
                        .disabled(listedCaptures.isEmpty)
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
        List(listedCaptures) { capture in
            NavigationLink(destination: CaptureDetailView(capture: capture)
                .onAppear  { detailVisible = true }
                .onDisappear {
                    detailVisible = false
                    listedCaptures = store.captures  // catch up on any captures that arrived while in detail
                }
            ) {
                HStack(alignment: .top, spacing: 10) {
                    VerificationBadge(result: capture.verification)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(capture.endpoint)
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        Text(capture.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if capture.endpoint == "/mobile/blobs" {
                            Text(capture.fullURL)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        } else {
                            Text(capture.summary)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
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
    @State private var bodyRevealed = false

    private var isLargePayload: Bool { capture.prettyJSON.count > 10_000 }
    private var bodyLines: [String] { capture.prettyJSON.components(separatedBy: "\n") }

    var body: some View {
        // LazyVStack so body lines are rendered on-demand as the user scrolls,
        // avoiding the CoreGraphics bogus-layer-size crash on large payloads.
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // Header and verification are small — group them as one eager block.
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
                }

                if !capture.queryParams.isEmpty {
                    QueryParamsSection(endpoint: capture.endpoint, queryParams: capture.queryParams)
                    Divider()
                }

                if isLargePayload && !bodyRevealed {
                    Button {
                        bodyRevealed = true
                    } label: {
                        Label("Show body (\(capture.prettyJSON.count / 1024) KB)", systemImage: "chevron.down.circle")
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                } else {
                    ForEach(Array(bodyLines.enumerated()), id: \.offset) { index, line in
                        Text(verbatim: line.isEmpty ? " " : line)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, index == 0 ? 12 : 0)
                    }
                    Color.clear.frame(height: 12)
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
            Text(capture.timestamp.formatted(date: .abbreviated, time: .complete))
                .font(.caption)
                .foregroundColor(.secondary)
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

// MARK: - URL query params disclosure

private struct QueryParamsSection: View {
    let endpoint: String
    let queryParams: [(String, String)]
    @State private var expanded = false
    @State private var urlCopied = false

    private var fullURL: String {
        guard !queryParams.isEmpty else { return endpoint }
        let qs = queryParams.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        return "\(endpoint)?\(qs)"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text(fullURL)
                        .font(.system(.caption2, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button(urlCopied ? "Copied!" : "Copy") {
                        UIPasteboard.general.string = fullURL
                        urlCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { urlCopied = false }
                    }
                    .font(.caption2)
                }
                .padding(.bottom, 4)
                Divider()
                ForEach(Array(queryParams.enumerated()), id: \.offset) { _, pair in
                    if pair.0 == "attributes" {
                        AttributesRow(raw: pair.1)
                    } else {
                        paramRow(pair.0, pair.1)
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        } label: {
            Text("URL Parameters")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func paramRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(key)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AttributesRow: View {
    let raw: String
    @State private var expanded = false

    private var pairs: [(String, String)] {
        let decoded = raw.removingPercentEncoding ?? raw
        return decoded.components(separatedBy: "&").compactMap { pair in
            let parts = pair.components(separatedBy: "=")
            guard parts.count >= 2 else { return nil }
            return (parts[0], parts[1...].joined(separator: "="))
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 4) {
                        Text(pair.0)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 160, alignment: .leading)
                        Text(pair.1)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 4) {
                Text("attributes")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 130, alignment: .leading)
                Text("(\(pairs.count) keys)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Connect config JSON editor

/// Pushed onto InjectErrorSheet's NavigationView stack — no NavigationView wrapper needed.
private struct ConnectConfigEditorView: View {
    let onSave: (ConnectConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var config: ConnectConfig

    init(initial: ConnectConfig, onSave: @escaping (ConnectConfig) -> Void) {
        self.onSave = onSave
        _config = State(initialValue: initial)
    }

    private static let logLevels = ["DEBUG", "INFO", "WARN", "ERROR", "VERBOSE", "AUDIT"]
    @State private var selectedRuleIndex: Int? = nil

    var body: some View {
        Form {
            Section("Session Replay") {
                Toggle("Enabled", isOn: $config.configuration.sessionReplay.enabled)
                Stepper(
                    "Sampling rate: \(Int(config.configuration.sessionReplay.samplingRate))%",
                    value: $config.configuration.sessionReplay.samplingRate,
                    in: 0...100, step: 10
                )
                Stepper(
                    "Error sampling rate: \(Int(config.configuration.sessionReplay.errorSamplingRate))%",
                    value: $config.configuration.sessionReplay.errorSamplingRate,
                    in: 0...100, step: 10
                )
                Picker("Mode", selection: $config.configuration.sessionReplay.mode) {
                    Text("custom").tag("custom")
                    Text("default").tag("default")
                }
                Toggle("Mask application text", isOn: $config.configuration.sessionReplay.maskApplicationText)
                Toggle("Mask user input text",  isOn: $config.configuration.sessionReplay.maskUserInputText)
                Toggle("Mask all images",       isOn: $config.configuration.sessionReplay.maskAllImages)
                Toggle("Mask all touches",      isOn: $config.configuration.sessionReplay.maskAllUserTouches)
            }

            Section("Logs") {
                Toggle("Enabled", isOn: $config.configuration.logs.enabled)
                Picker("Level", selection: $config.configuration.logs.level) {
                    ForEach(Self.logLevels, id: \.self) { Text($0).tag($0) }
                }
                Stepper(
                    "Sampling rate: \(Int(config.configuration.logs.samplingRate))%",
                    value: $config.configuration.logs.samplingRate,
                    in: 0...100, step: 10
                )
            }

            Section("Custom Masking Rules") {
                ForEach(config.configuration.sessionReplay.customMaskingRules.indices, id: \.self) { i in
                    NavigationLink(tag: i, selection: $selectedRuleIndex) {
                        MaskingRuleEditorView(
                            rule: $config.configuration.sessionReplay.customMaskingRules[i]
                        )
                    } label: {
                        maskingRuleLabel(config.configuration.sessionReplay.customMaskingRules[i])
                    }
                }
                .onDelete {
                    config.configuration.sessionReplay.customMaskingRules.remove(atOffsets: $0)
                    selectedRuleIndex = nil
                }
                Button("Add Rule") {
                    let newIndex = config.configuration.sessionReplay.customMaskingRules.count
                    config.configuration.sessionReplay.customMaskingRules.append(
                        .init(identifier: "class", type: "mask", name: [])
                    )
                    selectedRuleIndex = newIndex
                }
            }
        }
        .navigationTitle("Connect Config")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { onSave(config); dismiss() } label: {
                    Text("Apply").fontWeight(.semibold)
                }
            }
        }
        .onChange(of: selectedRuleIndex) { newValue in
            guard newValue == nil else { return }
            config.configuration.sessionReplay.customMaskingRules.removeAll {
                $0.name.first?.isEmpty != false
            }
        }
    }

    @ViewBuilder
    private func maskingRuleLabel(_ rule: ConnectConfig.MaskingRule) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(rule.type)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(rule.type == "mask" ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .cornerRadius(4)
                Text(rule.identifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(rule.name.isEmpty ? "(no names)" : rule.name.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Masking rule editor

private struct MaskingRuleEditorView: View {
    @Binding var rule: ConnectConfig.MaskingRule
    @State private var draft: ConnectConfig.MaskingRule
    @Environment(\.dismiss) private var dismiss

    init(rule: Binding<ConnectConfig.MaskingRule>) {
        _rule = rule
        _draft = State(initialValue: rule.wrappedValue)
    }

    var body: some View {
        Form {
            Section {
                Picker("Identifier", selection: $draft.identifier) {
                    Text("class").tag("class")
                    Text("tag").tag("tag")
                }
                Picker("Type", selection: $draft.type) {
                    Text("mask").tag("mask")
                    Text("unmask").tag("unmask")
                }
            }

            Section("Name") {
                TextField("e.g. UITextField", text: Binding(
                    get: { draft.name.first ?? "" },
                    set: { draft.name = [$0] }
                ))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))
            }
        }
        .navigationTitle("Masking Rule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { rule = draft; dismiss() } label: {
                    Text("Save").fontWeight(.semibold)
                }
                .disabled(draft.name.first?.isEmpty != false)
            }
        }
    }
}

// MARK: - Connect config sheet

private struct ConnectConfigSheet: View {
    @ObservedObject private var store = NRCaptureServer.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ConnectConfigEditorView(
                initial: store.connectConfig,
                onSave: { store.setConnectConfig($0) }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset", role: .destructive) {
                        store.resetConnectConfig()
                        dismiss()
                    }
                    .disabled(!store.connectConfigMutated)
                }
            }
        }
    }
}

// MARK: - Error injection sheet

private struct InjectErrorSheet: View {
    @Binding var injection: StatusInjection?
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset   = ResponseOverride.presets[0]
    @State private var selectedEndpoint = StatusInjection.Endpoint.all
    @State private var count       = 1
    @State private var unlimited   = false

    var body: some View {
        NavigationView {
            Form {
                Section("Response") {
                    Picker("Error", selection: $selectedPreset) {
                        ForEach(ResponseOverride.presets, id: \.label) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Endpoint") {
                    Picker("Endpoint", selection: $selectedEndpoint) {
                        ForEach(StatusInjection.Endpoint.allCases) { ep in
                            Text(ep.rawValue).tag(ep)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Repeat") {
                    Toggle("Unlimited", isOn: $unlimited)
                    if !unlimited {
                        Stepper("Count: \(count)", value: $count, in: 1...100)
                    }
                }

                if let active = injection {
                    Section("Active injection") {
                        Text(active.label)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.orange)
                        Button("Disarm", role: .destructive) {
                            injection = nil
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Inject Error")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Arm") {
                        injection = StatusInjection(
                            override: selectedPreset,
                            endpoint: selectedEndpoint,
                            remaining: count,
                            unlimited: unlimited
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

