import SwiftUI

// MARK: - Root demo view (mirrors what lives inside a WindowGroup { } scene)

@available(iOS 16.0, *)

struct WindowGroupDemoView: View {

    // MARK: Alerts & sheets
    @State private var showAlert         = false
    @State private var showConfirm       = false
    @State private var showSheet         = false
    @State private var showFullScreen    = false
    @State private var showPopover       = false

    // MARK: Text / form
    @State private var nameText          = ""
    @State private var bioText           = ""
    @State private var sliderValue       = 0.5
    @State private var stepperCount      = 3
    @State private var toggleOn          = true
    @State private var pickerIndex       = 0
    @State private var selectedDate      = Date()
    @State private var selectedColor     = Color.accentColor
    @State private var searchText        = ""

    // MARK: Progress / task
    @State private var progress          = 0.4
    @State private var isLoading         = false

    // MARK: Disclosure / expand
    @State private var sectionExpanded   = true

    private let flavors  = ["Vanilla", "Chocolate", "Strawberry", "Mint"]
    private let symbols  = ["star", "heart", "bolt", "flame", "leaf", "moon", "sun.max", "cloud"]

    var body: some View {
        Form {
            presentationSection
            inputSection
            controlsSection
            labelSymbolSection
            groupBoxSection
            disclosureSection
            progressSection
            colorSection
            menuSection
            toolbarPlaceholderSection
        }
        .navigationTitle("WindowGroup Elements")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search elements")
        // MARK: Alert
        .alert("Standard Alert", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
            Button("Destructive", role: .destructive) {}
        } message: {
            Text("This is a standard SwiftUI .alert modifier attached at scene level.")
        }
        // MARK: Confirmation Dialog
        .confirmationDialog("Confirm Action", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {}
            Button("Archive")                   {}
            Button("Cancel", role: .cancel)     {}
        } message: {
            Text("Choose what to do with this item.")
        }
        // MARK: Sheet
        .sheet(isPresented: $showSheet) {
            SheetContentView(isPresented: $showSheet)
        }
        // MARK: Full-screen cover
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenContentView(isPresented: $showFullScreen)
        }
        // MARK: Popover (iPad shows popover; iPhone shows sheet)
        .popover(isPresented: $showPopover) {
            VStack(spacing: 12) {
                Text("Popover Content").font(.headline)
                Text("On iPad this floats. On iPhone it becomes a sheet.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                Button("Dismiss") { showPopover = false }
            }
            .padding()
            .frame(minWidth: 260)
        }
        // MARK: Toolbar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Refresh", systemImage: "arrow.clockwise") { progress = Double.random(in: 0...1) }
                    Button("Toggle Load", systemImage: "bolt") { isLoading.toggle() }
                    Divider()
                    Button("Reset", systemImage: "arrow.uturn.backward", role: .destructive) { resetAll() }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Label("Home", systemImage: "house")
                Spacer()
                Label("Saved", systemImage: "bookmark")
                Spacer()
                Label("Profile", systemImage: "person.circle")
                Spacer()
            }
        }
    }

    // MARK: - Sections

    private var presentationSection: some View {
        Section("Presentations") {
            Button("Show Alert")              { showAlert      = true }
            Button("Show Confirmation Dialog") { showConfirm   = true }
            Button("Show Sheet")              { showSheet      = true }
            Button("Show Full-Screen Cover")  { showFullScreen = true }
            Button("Show Popover")            { showPopover    = true }
        }
    }

    private var inputSection: some View {
        Section("Text Input") {
            LabeledContent("Name") {
                TextField("Enter name", text: $nameText)
                    .textContentType(.name)
                    .submitLabel(.next)
            }
            LabeledContent("Bio") {
                TextField("A short bio…", text: $bioText, axis: .vertical)
                    .lineLimit(3...6)
            }
            LabeledContent("Secure") {
                SecureField("Password", text: .constant(""))
            }
        }
    }

    private var controlsSection: some View {
        Section("Controls") {
            Picker("Flavor", selection: $pickerIndex) {
                ForEach(flavors.indices, id: \.self) { i in
                    Text(flavors[i]).tag(i)
                }
            }
            .pickerStyle(.menu)

            DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])

            Toggle("Notifications", isOn: $toggleOn)

            VStack(alignment: .leading, spacing: 4) {
                Text("Brightness: \(Int(sliderValue * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $sliderValue)
            }

            Stepper("Quantity: \(stepperCount)", value: $stepperCount, in: 0...20)
        }
    }

    private var labelSymbolSection: some View {
        Section("Labels & SF Symbols") {
            ForEach(symbols, id: \.self) { name in
                Label(name.capitalized, systemImage: name)
            }
        }
    }

    private var groupBoxSection: some View {
        Section("GroupBox") {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Feature A enabled", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Feature B disabled", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Label("Feature C pending", systemImage: "clock.fill")
                        .foregroundStyle(.orange)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("App Features", systemImage: "gearshape.2")
                    .font(.headline)
            }
        }
    }

    private var disclosureSection: some View {
        Section("DisclosureGroup") {
            DisclosureGroup("Advanced Settings", isExpanded: $sectionExpanded) {
                Toggle("Haptic Feedback",    isOn: .constant(true))
                Toggle("Analytics",          isOn: .constant(false))
                Toggle("Background Refresh", isOn: .constant(true))
                LabeledContent("Cache Size", value: "128 MB")
                LabeledContent("Build",      value: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")
            }
        }
    }

    private var progressSection: some View {
        Section("Progress & Activity") {
            VStack(alignment: .leading, spacing: 10) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Determinate: \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading…")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap Options › Toggle Load to show spinner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if #available(iOS 16.0, *) {
                Gauge(value: progress) {
                    Label("Level", systemImage: "waveform")
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                } minimumValueLabel: {
                    Text("0")
                } maximumValueLabel: {
                    Text("100")
                }
                .gaugeStyle(.accessoryLinear)

                Gauge(value: progress) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                }
                .gaugeStyle(.accessoryCircular)
            }
        }
    }

    private var colorSection: some View {
        Section("Color Picker") {
            ColorPicker("Accent Color", selection: $selectedColor, supportsOpacity: true)
            RoundedRectangle(cornerRadius: 10)
                .fill(selectedColor)
                .frame(height: 44)
                .overlay(
                    Text("Preview")
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                )
        }
    }

    private var menuSection: some View {
        Section("Menus & Context Menus") {
            Menu("Primary Menu") {
                Menu("Nested Submenu") {
                    Button("Option A") {}
                    Button("Option B") {}
                }
                Button("Share",  systemImage: "square.and.arrow.up") {}
                Button("Copy",   systemImage: "doc.on.doc")           {}
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {}
            }

            Text("Long-press for context menu")
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                .contextMenu {
                    Button("Copy",   systemImage: "doc.on.doc")  {}
                    Button("Share",  systemImage: "square.and.arrow.up") {}
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) {}
                } preview: {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.fill")
                            .font(.largeTitle)
                        Text("Context Preview")
                    }
                    .padding()
                }
        }
    }

    private var toolbarPlaceholderSection: some View {
        Section("Toolbar (see nav bar / bottom bar)") {
            Label("Trailing: Options menu",   systemImage: "ellipsis.circle")
            Label("Leading: Edit button",     systemImage: "pencil")
            Label("Bottom: Home/Saved/Profile", systemImage: "rectangle.bottomthird.inset.filled")
        }
    }

    // MARK: - Helpers

    private func resetAll() {
        nameText       = ""
        bioText        = ""
        sliderValue    = 0.5
        stepperCount   = 3
        toggleOn       = true
        pickerIndex    = 0
        selectedDate   = Date()
        selectedColor  = .accentColor
        progress       = 0.4
        isLoading      = false
    }
}

// MARK: - Sheet content
@available(iOS 16.0, *)

private struct SheetContentView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                Text("Sheet Presentation")
                    .font(.title2.bold())
                Text("Sheets slide up from the bottom. Use .presentationDetents to control height on iOS 16+.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                if #available(iOS 16.0, *) {
                    Text("This sheet uses .medium and .large detents.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .navigationTitle("Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .if_available_presentationDetents()
    }
}

// MARK: - Full-screen cover content

private struct FullScreenContentView: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.indigo, .purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "macwindow.on.rectangle")
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                Text("Full-Screen Cover")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("fullScreenCover covers the entire screen,\nincluding the status bar.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                Button {
                    isPresented = false
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .foregroundStyle(.white)
            }
            .padding()
        }
    }
}

// MARK: - Availability shim for presentationDetents

private extension View {
    @ViewBuilder
    func if_available_presentationDetents() -> some View {
        if #available(iOS 16.0, *) {
            self.presentationDetents([.medium, .large])
        } else {
            self
        }
    }
}
