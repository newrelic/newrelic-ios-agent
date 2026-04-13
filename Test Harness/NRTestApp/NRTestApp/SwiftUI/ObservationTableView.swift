import SwiftUI
import Lottie
import Combine
import NewRelic

// MARK: - Data Model

struct TableColumn: Identifiable {
    let id = UUID()
    let title: String
    let width: CGFloat
}

struct TableRow: Identifiable {
    let id = UUID()
    let values: [String: String]
}

// MARK: - State

final class InfraTableState: ObservableObject {
    enum ViewState { case loading, empty, data }

    @Published var viewState: ViewState = .loading
    @Published var rows: [TableRow] = []

    var isLoading: Bool { viewState == .loading }
    var isEmpty: Bool  { viewState == .empty }

    private var timerTask: Task<Void, Never>?

    let columns: [TableColumn] = [
        TableColumn(title: "Host",    width: 160),
        TableColumn(title: "Status",  width: 80),
        TableColumn(title: "CPU %",   width: 70),
        TableColumn(title: "Mem %",   width: 70),
        TableColumn(title: "Disk %",  width: 70),
        TableColumn(title: "Region",  width: 100),
    ]

    private static let sampleHosts: [[String: String]] = [
        ["Host": "web-prod-01",  "Status": "OK",   "CPU %": "12", "Mem %": "45", "Disk %": "60", "Region": "us-east-1"],
        ["Host": "web-prod-02",  "Status": "OK",   "CPU %": "9",  "Mem %": "41", "Disk %": "58", "Region": "us-east-1"],
        ["Host": "api-prod-01",  "Status": "WARN", "CPU %": "78", "Mem %": "82", "Disk %": "70", "Region": "us-west-2"],
        ["Host": "api-prod-02",  "Status": "OK",   "CPU %": "33", "Mem %": "55", "Disk %": "62", "Region": "us-west-2"],
        ["Host": "db-primary",   "Status": "OK",   "CPU %": "22", "Mem %": "70", "Disk %": "80", "Region": "eu-west-1"],
        ["Host": "db-replica-1", "Status": "OK",   "CPU %": "18", "Mem %": "65", "Disk %": "79", "Region": "eu-west-1"],
        ["Host": "cache-01",     "Status": "CRIT", "CPU %": "95", "Mem %": "99", "Disk %": "30", "Region": "ap-south-1"],
        ["Host": "cache-02",     "Status": "OK",   "CPU %": "14", "Mem %": "48", "Disk %": "31", "Region": "ap-south-1"],
        ["Host": "worker-01",    "Status": "OK",   "CPU %": "40", "Mem %": "52", "Disk %": "44", "Region": "us-east-1"],
        ["Host": "worker-02",    "Status": "WARN", "CPU %": "67", "Mem %": "74", "Disk %": "50", "Region": "us-east-1"],
    ]

    func startCycling() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            let sequence: [ViewState] = [.loading, .data, .loading, .empty]
            var index = 0
            while !Task.isCancelled {
                self.viewState = sequence[index % sequence.count]
                self.rows = self.viewState == .data
                    ? Self.sampleHosts.map { TableRow(values: $0) }
                    : []
                index += 1
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    func stopCycling() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - View

struct ObservationTableView: View {
    @ObservedObject var state: InfraTableState

    init() {
        self.state = InfraTableState()
    }

    var body: some View {
        Group {
            if state.isLoading {
                Lottie(
                    isAnimating: .constant(true),
                    config: LottieConfig(fileName: LottieFile.Loader, speed: .loader)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.isEmpty {
                Text("No results for the selected filters and/or time window")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                tableContent
            }
        }
        .navigationTitle("Observation")
        .onAppear { state.startCycling() }
        .onDisappear { state.stopCycling() }
        .NRTrackView(name: "ObservationTableView")
    }

    private var tableContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerRow
                    Divider()
                    ForEach(state.rows) { row in
                        dataRow(row)
                        Divider()
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(state.columns) { col in
                Text(col.title)
                    .font(.caption.bold())
                    .frame(width: col.width, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func dataRow(_ row: TableRow) -> some View {
        HStack(spacing: 0) {
            ForEach(state.columns) { col in
                let value = row.values[col.title] ?? "—"
                Text(value)
                    .font(.caption)
                    .foregroundColor(cellColor(column: col.title, value: value))
                    .frame(width: col.width, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
            }
        }
    }

    private func cellColor(column: String, value: String) -> Color {
        guard column == "Status" else { return .primary }
        switch value {
        case "WARN": return .orange
        case "CRIT": return .red
        default:     return .green
        }
    }
}

// MARK: - @EnvironmentObject Demo

final class SharedCounterState: ObservableObject {
    @Published var count: Int = 0
    @Published var label: String = "zero"
}

struct EnvironmentObjectDemoView: View {
    @StateObject private var counter = SharedCounterState()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("@EnvironmentObject flows to any descendant without explicit passing through each layer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                EnvObjChildView()
                EnvObjGrandchildWrapperView()
            }
            .padding()
        }
        .navigationTitle("@EnvironmentObject")
        .environmentObject(counter)
        .onAppear {
            NewRelic.recordBreadcrumb("EnvironmentObjectDemoView appeared")
        }
        .NRTrackView(name: "EnvironmentObjectDemoView")
    }
}

struct EnvObjChildView: View {
    @EnvironmentObject var counter: SharedCounterState

    var body: some View {
        GroupBox("Child — reads & mutates shared state") {
            VStack(spacing: 12) {
                Text("Count: \(counter.count)")
                    .font(.title2).fontWeight(.bold)
                HStack(spacing: 24) {
                    Button("−") {
                        counter.count -= 1
                        updateLabel()
                        NewRelic.recordCustomEvent("EnvObjCounter",
                            attributes: ["action": "dec", "value": NSNumber(value: counter.count)])
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(8)

                    Button("+") {
                        counter.count += 1
                        updateLabel()
                        NewRelic.recordCustomEvent("EnvObjCounter",
                            attributes: ["action": "inc", "value": NSNumber(value: counter.count)])
                    }
                    .frame(width: 44, height: 44)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)

                    Button("Reset") {
                        counter.count = 0
                        counter.label = "zero"
                        NewRelic.recordCustomEvent("EnvObjCounter", attributes: ["action": "reset"])
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func updateLabel() {
        counter.label = counter.count > 0 ? "positive" : counter.count < 0 ? "negative" : "zero"
    }
}

struct EnvObjGrandchildWrapperView: View {
    var body: some View {
        GroupBox("Grandchild wrapper (no @EnvironmentObject needed here)") {
            EnvObjGrandchildView()
        }
    }
}

struct EnvObjGrandchildView: View {
    @EnvironmentObject var counter: SharedCounterState

    var body: some View {
        Text("Grandchild sees count=\(counter.count), label=\"\(counter.label)\"")
            .font(.caption)
            .multilineTextAlignment(.center)
    }
}

// MARK: - @AppStorage + @SceneStorage Demo

struct AppStorageDemoView: View {
    @AppStorage("obs_demo_username") private var username: String = ""
    @AppStorage("obs_demo_dark_pref") private var darkPref: Bool = false
    @AppStorage("obs_demo_tap_count") private var tapCount: Int = 0
    @SceneStorage("obs_scene_draft") private var draftText: String = ""

    var body: some View {
        Form {
            Section {
                TextField("Username", text: $username)
                    .onChange(of: username) { new in
                        NewRelic.recordBreadcrumb("AppStorage username",
                            attributes: ["length": NSNumber(value: new.count)])
                    }
                Toggle("Prefer dark mode", isOn: $darkPref)
                    .onChange(of: darkPref) { new in
                        NewRelic.recordCustomEvent("AppStorageToggle",
                            attributes: ["darkPref": NSNumber(value: new)])
                    }
                HStack {
                    Text("Tap count: \(tapCount)")
                    Spacer()
                    Button("Tap") { tapCount += 1 }
                    Button("Reset") { tapCount = 0 }.foregroundColor(.red)
                }
            } header: {
                Text("@AppStorage — UserDefaults backed")
            } footer: {
                Text("Values persist across app launches.")
            }

            Section {
                TextEditor(text: $draftText)
                    .frame(minHeight: 80)
                    .onChange(of: draftText) { _ in
                        NewRelic.recordBreadcrumb("SceneStorage draft updated")
                    }
            } header: {
                Text("@SceneStorage — scene state restoration")
            } footer: {
                Text("Survives scene kills; cleared on full reinstall.")
            }
        }
        .navigationTitle("@AppStorage / @SceneStorage")
        .onAppear {
            NewRelic.recordBreadcrumb("AppStorageDemoView appeared",
                attributes: ["tapCount": NSNumber(value: tapCount)])
        }
        .NRTrackView(name: "AppStorageDemoView")
    }
}

// MARK: - @FocusState Demo

struct FocusStateDemoView: View {
    enum Field: Hashable { case firstName, lastName, email, password }

    @FocusState private var focused: Field?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section("@FocusState — programmatic keyboard focus") {
                TextField("First name", text: $firstName)
                    .focused($focused, equals: .firstName)
                    .submitLabel(.next)
                    .onSubmit { focused = .lastName }

                TextField("Last name", text: $lastName)
                    .focused($focused, equals: .lastName)
                    .submitLabel(.next)
                    .onSubmit { focused = .email }

                TextField("Email", text: $email)
                    .focused($focused, equals: .email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }

                SecureField("Password", text: $password)
                    .focused($focused, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { focused = nil }
            }

            Section("Jump to field") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([Field.firstName, .lastName, .email, .password], id: \.self) { field in
                            Button(fieldLabel(field)) {
                                focused = field
                                NewRelic.recordBreadcrumb("FocusState jump",
                                    attributes: ["field": fieldLabel(field)])
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(focused == field ? Color.blue : Color(.systemGray5))
                            .foregroundColor(focused == field ? .white : .primary)
                            .cornerRadius(8)
                        }
                        Button("Dismiss") {
                            focused = nil
                            NewRelic.recordBreadcrumb("FocusState dismissed")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .navigationTitle("@FocusState")
        .onAppear {
            NewRelic.recordBreadcrumb("FocusStateDemoView appeared")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focused = .firstName
            }
        }
        .NRTrackView(name: "FocusStateDemoView")
    }

    private func fieldLabel(_ field: Field) -> String {
        switch field {
        case .firstName: return "First"
        case .lastName: return "Last"
        case .email: return "Email"
        case .password: return "Pass"
        }
    }
}

// MARK: - @GestureState Demo

struct GestureStateDemoView: View {
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var isLongPressing: Bool = false
    @State private var baseOffset: CGSize = .zero
    @State private var eventLog: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("@GestureState resets to its initial value automatically when the gesture ends.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isLongPressing ? Color.orange : Color.blue)
                    .frame(width: 110, height: 110)
                    .overlay(
                        VStack(spacing: 4) {
                            Text("Drag").foregroundColor(.white)
                            Text("Long-press").font(.caption2).foregroundColor(.white.opacity(0.8))
                        }
                    )
                    .offset(
                        x: baseOffset.width + dragOffset.width,
                        y: baseOffset.height + dragOffset.height
                    )
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                baseOffset.width  += value.translation.width
                                baseOffset.height += value.translation.height
                                log("Drag → (\(Int(baseOffset.width)), \(Int(baseOffset.height)))")
                                NewRelic.recordCustomEvent("GestureDragEnd", attributes: [
                                    "x": NSNumber(value: Float(baseOffset.width)),
                                    "y": NSNumber(value: Float(baseOffset.height))
                                ])
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .updating($isLongPressing) { value, state, _ in state = value }
                            .onEnded { _ in
                                log("Long press fired")
                                NewRelic.recordBreadcrumb("GestureLongPress")
                            }
                    )
            }
            .frame(height: 200)

            Button("Reset position") {
                baseOffset = .zero
                log("Position reset")
            }

            GroupBox("Last events") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(eventLog.suffix(5), id: \.self) { entry in
                        Text(entry).font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .navigationTitle("@GestureState")
        .onAppear { NewRelic.recordBreadcrumb("GestureStateDemoView appeared") }
        .NRTrackView(name: "GestureStateDemoView")
    }

    private func log(_ msg: String) {
        eventLog.append(msg)
        if eventLog.count > 20 { eventLog.removeFirst() }
    }
}

// MARK: - Combine + ObservableObject Demo

final class CombineDemoViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredResults: [String] = []
    @Published var eventCount: Int = 0

    private var cancellables = Set<AnyCancellable>()
    private let eventSubject = PassthroughSubject<String, Never>()

    private static let allItems = [
        "Apple", "Banana", "Cherry", "Date", "Elderberry",
        "Fig", "Grape", "Honeydew", "Kiwi", "Lemon",
        "Mango", "Nectarine", "Orange", "Papaya", "Quince"
    ]

    init() {
        filteredResults = Self.allItems

        // Debounced search using Combine pipeline
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { query -> [String] in
                query.isEmpty
                    ? Self.allItems
                    : Self.allItems.filter { $0.localizedCaseInsensitiveContains(query) }
            }
            .assign(to: &$filteredResults)

        // Count events from a PassthroughSubject
        eventSubject
            .scan(0) { count, _ in count + 1 }
            .receive(on: RunLoop.main)
            .assign(to: &$eventCount)
    }

    func fireEvent(_ name: String) {
        eventSubject.send(name)
        NewRelic.recordBreadcrumb("CombineEvent", attributes: ["name": name])
    }
}

struct CombinePublisherDemoView: View {
    @StateObject private var vm = CombineDemoViewModel()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                TextField("Search (debounced 300 ms)", text: $vm.searchText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("PassthroughSubject events: \(vm.eventCount)")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Fire event") { vm.fireEvent("manual_tap") }
                        .font(.caption)
                }
            }
            .padding()

            List(vm.filteredResults, id: \.self) { item in
                Text(item)
            }
        }
        .navigationTitle("Combine Publishers")
        .onAppear { NewRelic.recordBreadcrumb("CombinePublisherDemoView appeared") }
        .NRTrackView(name: "CombinePublisherDemoView")
    }
}

// MARK: - @Binding Deep Chain (parent → child → grandchild)

struct BindingChainParentView: View {
    @State private var sliderValue: Double = 50
    @State private var toggleOn: Bool = false
    @State private var text: String = "edit me"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Mutations deep in the child tree propagate back to parent @State.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                GroupBox("Parent @State values") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Slider: \(Int(sliderValue))")
                        Text("Toggle: \(toggleOn ? "ON" : "OFF")")
                        Text("Text: \"\(text)\"")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                BindingChainChildView(sliderValue: $sliderValue,
                                     toggleOn: $toggleOn,
                                     text: $text)
            }
            .padding()
        }
        .navigationTitle("@Binding Chain")
        .onAppear { NewRelic.recordBreadcrumb("BindingChainParentView appeared") }
        .NRTrackView(name: "BindingChainParentView")
    }
}

struct BindingChainChildView: View {
    @Binding var sliderValue: Double
    @Binding var toggleOn: Bool
    @Binding var text: String

    var body: some View {
        GroupBox("Child — owns Slider, passes Toggle+Text down") {
            VStack(spacing: 12) {
                Slider(value: $sliderValue, in: 0...100)
                    .onChange(of: sliderValue) { new in
                        NewRelic.recordCustomEvent("BindingSlider",
                            attributes: ["value": NSNumber(value: new)])
                    }
                Text("Slider: \(Int(sliderValue))")
                    .font(.caption).foregroundStyle(.secondary)

                BindingChainGrandchildView(toggleOn: $toggleOn, text: $text)
            }
        }
    }
}

struct BindingChainGrandchildView: View {
    @Binding var toggleOn: Bool
    @Binding var text: String

    var body: some View {
        GroupBox("Grandchild — mutates Toggle & Text") {
            VStack(spacing: 8) {
                Toggle("Toggle", isOn: $toggleOn)
                    .onChange(of: toggleOn) { new in
                        NewRelic.recordCustomEvent("BindingToggle",
                            attributes: ["value": NSNumber(value: new)])
                    }
                TextField("Text field", text: $text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Custom Binding(get:set:) Demo

struct CustomBindingDemoView: View {
    @State private var rawText: String = ""
    @State private var limit: Int = 12
    @State private var forceUppercase: Bool = false
    @State private var validationMessage: String = ""

    /// A custom Binding that enforces character limit + optional uppercasing,
    /// and records every mutation attempt via New Relic.
    private var transformedBinding: Binding<String> {
        Binding(
            get: { rawText },
            set: { proposed in
                let capped = String(proposed.prefix(limit))
                let final = forceUppercase ? capped.uppercased() : capped
                rawText = final
                validationMessage = proposed.count > limit
                    ? "Trimmed to \(limit) chars"
                    : proposed != final ? "Uppercased" : ""
                NewRelic.recordCustomEvent("CustomBinding", attributes: [
                    "proposed_len": NSNumber(value: proposed.count),
                    "final_len":    NSNumber(value: final.count),
                    "trimmed":      NSNumber(value: proposed.count > limit)
                ])
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("Type here", text: transformedBinding)
                    .textFieldStyle(.roundedBorder)
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption).foregroundColor(.orange)
                }
                Text("Stored value (\(rawText.count)/\(limit)): \"\(rawText)\"")
                    .font(.caption2).foregroundStyle(.secondary)
            } header: {
                Text("Custom Binding(get:set:) with transform")
            }

            Section("Controls") {
                Stepper("Char limit: \(limit)", value: $limit, in: 3...30)
                Toggle("Force uppercase", isOn: $forceUppercase)
                Button("Clear") { rawText = ""; validationMessage = "" }
            }
        }
        .navigationTitle("Custom Binding")
        .onAppear { NewRelic.recordBreadcrumb("CustomBindingDemoView appeared") }
        .NRTrackView(name: "CustomBindingDemoView")
    }
}

// MARK: - objectWillChange.send() + non-@Published properties

final class ManualPublishViewModel: ObservableObject {
    // These properties are NOT @Published — changes won't auto-notify
    var hiddenCounter: Int = 0
    var lastManualUpdate: String = "none"

    // @Published for comparison
    @Published var autoCounter: Int = 0

    func incrementHidden() {
        hiddenCounter += 1
        lastManualUpdate = "hidden=\(hiddenCounter) at \(timestamp())"
        // Without this call the view would NOT re-render
        objectWillChange.send()
        NewRelic.recordBreadcrumb("objectWillChange.send()",
            attributes: ["hiddenCounter": NSNumber(value: hiddenCounter)])
    }

    func incrementAuto() {
        autoCounter += 1   // @Published triggers objectWillChange automatically
        NewRelic.recordBreadcrumb("@Published auto notify",
            attributes: ["autoCounter": NSNumber(value: autoCounter)])
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

struct ManualPublishDemoView: View {
    @StateObject private var vm = ManualPublishViewModel()

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("hiddenCounter: \(vm.hiddenCounter)")
                            .fontWeight(.medium)
                        Text(vm.lastManualUpdate)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Increment") { vm.incrementHidden() }
                }
            } header: {
                Text("Non-@Published + objectWillChange.send()")
            } footer: {
                Text("Without objectWillChange.send() the view stays stale even though the property changed.")
            }

            Section {
                HStack {
                    Text("autoCounter: \(vm.autoCounter)")
                        .fontWeight(.medium)
                    Spacer()
                    Button("Increment") { vm.incrementAuto() }
                }
            } header: {
                Text("@Published (auto-notifies for comparison)")
            }
        }
        .navigationTitle("objectWillChange")
        .onAppear { NewRelic.recordBreadcrumb("ManualPublishDemoView appeared") }
        .NRTrackView(name: "ManualPublishDemoView")
    }
}

// MARK: - task(id:) async state loading

struct AsyncTaskStateDemoView: View {
    enum LoadState { case idle, loading, loaded(String), failed(String) }

    @State private var query: String = ""
    @State private var loadState: LoadState = .idle
    @State private var requestCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Search term (triggers async task)", text: $query)
                    HStack {
                        Text("Requests fired: \(requestCount)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear") { query = ""; loadState = .idle }
                            .font(.caption)
                    }
                } header: {
                    Text("task(id:) — re-runs when query changes")
                } footer: {
                    Text("Changing the text field cancels the in-flight task and starts a new one.")
                }
            }
            .frame(maxHeight: 220)

            Divider()

            Group {
                switch loadState {
                case .idle:
                    Text("Type something to load results")
                        .foregroundStyle(.secondary)
                case .loading:
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading \"\(query)\"…").font(.caption)
                    }
                case .loaded(let result):
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(result).font(.caption).multilineTextAlignment(.center)
                    }
                    .padding()
                case .failed(let err):
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding()
        }
        // task(id:) cancels the previous task automatically when `query` changes
        .task(id: query) {
            guard !query.isEmpty else { loadState = .idle; return }
            loadState = .loading
            requestCount += 1
            let captured = query
            let reqNum = requestCount
            NewRelic.recordBreadcrumb("AsyncTask started",
                attributes: ["query": captured, "req": NSNumber(value: reqNum)])
            do {
                // Simulate 800 ms network call; cancels cleanly if query changes
                try await Task.sleep(nanoseconds: 800_000_000)
                // Check for cancellation after sleep
                try Task.checkCancellation()
                loadState = .loaded("Result for [\(captured)] (req #\(reqNum))")
                NewRelic.recordCustomEvent("AsyncTaskLoaded",
                    attributes: ["query": captured, "req": NSNumber(value: reqNum)])
            } catch is CancellationError {
                // Task was cancelled — do not update state
                NewRelic.recordBreadcrumb("AsyncTask cancelled", attributes: ["query": captured])
            } catch {
                loadState = .failed(error.localizedDescription)
            }
        }
        .navigationTitle("task(id:) Async State")
        .onAppear { NewRelic.recordBreadcrumb("AsyncTaskStateDemoView appeared") }
        .NRTrackView(name: "AsyncTaskStateDemoView")
    }
}

// MARK: - @StateObject vs @ObservedObject lifetime

/// Shared counter so both ownership styles point at real objects
final class LifetimeCounter: ObservableObject {
    let label: String
    @Published var count: Int = 0
    init(label: String) { self.label = label }
}

struct StateObjectVsObservedDemoView: View {
    @State private var parentRerenderTick: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Tap 'Force parent re-render'. @StateObject keeps its counter; @ObservedObject resets because the parent re-creates the instance on each render.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                Button("Force parent re-render (tick=\(parentRerenderTick))") {
                    parentRerenderTick += 1
                    NewRelic.recordBreadcrumb("ParentRerender tick=\(parentRerenderTick)")
                }
                .padding(8)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

                // @StateObject — Xcode creates the vm once and keeps it alive
                StateObjectRowView()

                // @ObservedObject — we create the vm inline, so every parent
                // re-render produces a fresh instance and the count resets
                ObservedObjectRowView(vm: LifetimeCounter(label: "@ObservedObject"))
            }
            .padding()
        }
        .navigationTitle("StateObject vs ObservedObject")
        .onAppear { NewRelic.recordBreadcrumb("StateObjectVsObservedDemoView appeared") }
        .NRTrackView(name: "StateObjectVsObservedDemoView")
    }
}

struct StateObjectRowView: View {
    @StateObject private var vm = LifetimeCounter(label: "@StateObject")

    var body: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.label).fontWeight(.semibold)
                    Text("count: \(vm.count)")
                    Text("Survives parent re-renders")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("+1") {
                    vm.count += 1
                    NewRelic.recordCustomEvent("StateObjectCount",
                        attributes: ["count": NSNumber(value: vm.count)])
                }
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.15)).cornerRadius(8)
            }
        }
    }
}

struct ObservedObjectRowView: View {
    @ObservedObject var vm: LifetimeCounter

    var body: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.label).fontWeight(.semibold)
                    Text("count: \(vm.count)")
                    Text("Resets when parent re-renders")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("+1") {
                    vm.count += 1
                    NewRelic.recordCustomEvent("ObservedObjectCount",
                        attributes: ["count": NSNumber(value: vm.count)])
                }
                .frame(width: 44, height: 44)
                .background(Color.purple.opacity(0.15)).cornerRadius(8)
            }
        }
    }
}
