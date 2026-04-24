//
//  PerformanceContentView}.swift
//  NewRelicDemo
//
//  Created by Anna Shabalina on 11/19/2025.
//

//  Performance Issue Reproduction

import SwiftUI
import OSLog
import NewRelic

@available(iOS 17.0, *)
struct PerformanceContentView: View {
    @State private var tabViewModel = TabPerformanceViewModel()
    @State private var isRunningTest = false
    @State private var testResults = ""

    var body: some View {
        VStack {
            // Performance Test Controls
            VStack(spacing: 12) {
                Text("New Relic Performance Test")
                    .font(.title2)
                    .fontWeight(.bold)
                Button(isRunningTest ? "Testing..." : "🧪 Run Rapid Tab Switch Test") {
                    runPerformanceTest()
                }
                .disabled(isRunningTest)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                if !testResults.isEmpty {
                    Text(testResults)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
            Divider()
            // Tab View demonstrating performance architecture
            TabView(selection: $tabViewModel.selectedTab) {
                HeavyUIKitTab(tabIndex: 0).tag(0)
                HeavyUIKitTab(tabIndex: 1).tag(1)
                HeavyUIKitTab(tabIndex: 2).tag(2)
                HeavyUIKitTab(tabIndex: 3).tag(3)
                HeavyUIKitTab(tabIndex: 4).tag(4)
            }
        }
    }

    private func runPerformanceTest() {
        isRunningTest = true
        testResults = "Running test..."
        Task {
            let results = await tabViewModel.performRapidSwitchTest()
            await MainActor.run {
                testResults = results
                isRunningTest = false
            }
        }
    }
}

// MARK: - Observable ViewModel (demo MainTabViewModel analogue)
@available(iOS 17.0, *)
@Observable @MainActor
class TabPerformanceViewModel {
    var selectedTab: Int = 0 {
        didSet {
            recordTabChangeWithNewRelic(from: oldValue, to: selectedTab)
        }
    }
    private var lastEmit: CFAbsoluteTime = 0
    private var pendingSwitches: Int = 0
    private let emitInterval: CFAbsoluteTime = 0.30 // 300ms batching window

    // Direct (no batching) instrumentation to expose SDK overhead per tab change.
    private func recordTabChangeWithNewRelic(from oldTab: Int, to newTab: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()

        NewRelic.recordCustomEvent("demo_tab_changed", attributes: [
            "from_tab": NSNumber(value: oldTab),
            "to_tab": NSNumber(value: newTab)
        ])
        NewRelic.recordBreadcrumb("Tab Switch", attributes: [
            "previous": "tab_\(oldTab)",
            "current": "tab_\(newTab)"
        ])

        let beforeYield = CFAbsoluteTimeGetCurrent()
        let syncCostMs = (beforeYield - startTime) * 1000
        if syncCostMs > 2.0 {
            //Logger.performance.warning("🚨 Sync NR tracking took \(String(format: "%.2f", syncCostMs))ms")
        }
    }

    func performRapidSwitchTest() async -> String {
        //Logger.performance.info("🧪 Starting rapid tab switch performance test")
        let testIterations = 100
        var switchTimes: [Double] = []
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<testIterations {
            let switchStartTime = CFAbsoluteTimeGetCurrent()
            selectedTab = i % 5
            await Task.yield()
            try? await Task.sleep(nanoseconds: 8_000_000)
            let switchEndTime = CFAbsoluteTimeGetCurrent()
            let endMs = (switchEndTime - switchStartTime) * 1000
            switchTimes.append(endMs)
        }
        let overallEndTime = CFAbsoluteTimeGetCurrent()
        let totalTime = overallEndTime - overallStartTime
        let averageTime = switchTimes.reduce(0, +) / Double(switchTimes.count)
        let maxTime = switchTimes.max() ?? 0
        let minTime = switchTimes.min() ?? 0
        let results = """
        🔍 Performance Test Results:

        ⏱️ Total time: \(String(format: "%.2f", totalTime))s
        📊 Average switch: \(String(format: "%.2f", averageTime))ms
        📈 Max switch: \(String(format: "%.2f", maxTime))ms  
        📉 Min switch: \(String(format: "%.2f", minTime))ms
        🔢 Iterations: \(testIterations)

        """
        //Logger.performance.info("📊 Test completed: avg=\(String(format: "%.2f", averageTime))ms")
        return results
    }
}

// MARK: - Heavy UIKit Tab (complex tab simulation)
struct HeavyUIKitTab: View {
    let tabIndex: Int
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(0..<50, id: \.self) { index in
                    HStack {
                        ComplexUIKitView(itemIndex: index)
                            .frame(width: 60, height: 60)
                        VStack(alignment: .leading) {
                            Text("Tab \(tabIndex) - Item \(index)")
                                .font(.headline)
                            Text("Complex UIKit integration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        ComplexUIKitView(itemIndex: index + 1000)
                            .frame(width: 40, height: 40)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Tab \(tabIndex)")
        .tabItem {
            Label("Tab \(tabIndex)", systemImage: "\(tabIndex).circle")
        }
    }
}

// MARK: - Complex UIViewControllerRepresentable (navigation/controller embedding simulation)
struct ComplexUIKitView: UIViewControllerRepresentable {
    let itemIndex: Int
    func makeUIViewController(context: Context) -> ComplexViewController {
        let controller = ComplexViewController()
        controller.itemIndex = itemIndex

        NewRelic.recordCustomEvent("uikit_view_created", attributes: [
            "item_index": NSNumber(value: itemIndex)
        ])

        return controller
    }

    func updateUIViewController(_ uiViewController: ComplexViewController, context: Context) {
        uiViewController.itemIndex = itemIndex
    }
}

class ComplexViewController: UIViewController {
    var itemIndex: Int = 0 { didSet { updateContent() } }
    private let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        updateContent()
    }

    private func updateContent() { label.text = "\(itemIndex)" }
}

// MARK: - @Observable + @Bindable Demo (iOS 17+)

@available(iOS 17.0, *)
@Observable
class UserProfile {
    var name: String = "Alice"
    var age: Int = 30
    var isPremium: Bool = false
    var score: Double = 50.0
}

@available(iOS 17.0, *)
struct BindableDemoView: View {
    @State private var profile = UserProfile()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("@Bindable creates $bindings on @Observable properties so they work with SwiftUI controls.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)

                GroupBox("Live values (parent @State)") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Name: \(profile.name)")
                        Text("Age: \(profile.age)")
                        Text("Premium: \(profile.isPremium ? "yes" : "no")")
                        Text("Score: \(String(format: "%.0f", profile.score))")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                BindableEditorView(profile: profile)
            }
            .padding()
        }
        .navigationTitle("@Bindable")
        .onAppear { NewRelic.recordBreadcrumb("BindableDemoView appeared") }
        .NRTrackView(name: "BindableDemoView")
    }
}

@available(iOS 17.0, *)
struct BindableEditorView: View {
    @Bindable var profile: UserProfile   // @Bindable lets us use $ on @Observable

    var body: some View {
        GroupBox("Editor child — uses @Bindable") {
            VStack(spacing: 10) {
                HStack {
                    Text("Name")
                    TextField("Name", text: $profile.name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: profile.name) { _, new in
                            NewRelic.recordBreadcrumb("BindableProfile name", attributes: ["name": new])
                        }
                }
                Stepper("Age: \(profile.age)", value: $profile.age, in: 1...120)
                Toggle("Premium", isOn: $profile.isPremium)
                    .onChange(of: profile.isPremium) { _, new in
                        NewRelic.recordCustomEvent("BindableProfilePremium",
                            attributes: ["value": NSNumber(value: new)])
                    }
                Slider(value: $profile.score, in: 0...100) {
                    Text("Score")
                }
                Text("Score: \(String(format: "%.0f", profile.score))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - @Environment(Model.self) Demo (iOS 17+)

@available(iOS 17.0, *)
@Observable
class AppTheme {
    var primaryColor: Color = .blue
    var fontSize: Double = 16
    var isDense: Bool = false
}

@available(iOS 17.0, *)
struct EnvironmentObservableDemoView: View {
    @State private var theme = AppTheme()

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    ColorPicker("Primary color", selection: $theme.primaryColor)
                        .onChange(of: theme.primaryColor) { _, _ in
                            NewRelic.recordBreadcrumb("AppTheme primaryColor changed")
                        }
                    HStack {
                        Text("Font size: \(Int(theme.fontSize))")
                        Slider(value: $theme.fontSize, in: 10...28)
                    }
                    Toggle("Dense layout", isOn: $theme.isDense)
                } header: {
                    Text("Theme controls (parent — injects via .environment())")
                }
            }
            .frame(maxHeight: 260)

            Divider()

            ThemeChildView()
                .padding()
        }
        .environment(theme)
        .navigationTitle("@Environment(Model.self)")
        .onAppear { NewRelic.recordBreadcrumb("EnvironmentObservableDemoView appeared") }
        .NRTrackView(name: "EnvironmentObservableDemoView")
    }
}

@available(iOS 17.0, *)
struct ThemeChildView: View {
    @Environment(AppTheme.self) private var theme

    var body: some View {
        GroupBox("Child reads @Environment(AppTheme.self)") {
            VStack(spacing: 8) {
                Text("Hello, themed world!")
                    .font(.system(size: theme.fontSize))
                    .foregroundColor(theme.primaryColor)
                Text(theme.isDense ? "Dense layout active" : "Normal spacing")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(theme.isDense ? 4 : 12)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Nested @Observable + @Bindable on nested model (iOS 17+)

@available(iOS 17.0, *)
@Observable
class CartItem {
    var name: String
    var quantity: Int
    var price: Double
    init(name: String, quantity: Int = 1, price: Double) {
        self.name = name; self.quantity = quantity; self.price = price
    }
    var subtotal: Double { Double(quantity) * price }
}

@available(iOS 17.0, *)
@Observable
class ShoppingCart {
    var items: [CartItem] = []
    var couponCode: String = ""
    var total: Double { items.reduce(0) { $0 + $1.subtotal } }
    var discountedTotal: Double { couponCode.uppercased() == "SAVE10" ? total * 0.9 : total }

    func addItem(_ item: CartItem) {
        items.append(item)
        NewRelic.recordCustomEvent("CartItemAdded",
            attributes: ["name": item.name, "price": NSNumber(value: item.price)])
    }
    func removeItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        NewRelic.recordBreadcrumb("CartItemRemoved")
    }
}

@available(iOS 17.0, *)
struct NestedObservableDemoView: View {
    @State private var cart = ShoppingCart()

    private let sampleNames = ["Widget", "Gadget", "Doohickey", "Thingamajig", "Gizmo"]

    var body: some View {
        List {
            Section {
                ForEach(cart.items, id: \.name) { item in
                    CartItemRowView(item: item)
                }
                .onDelete { cart.removeItems(at: $0) }

                Button("+ Add random item") {
                    let name = sampleNames.randomElement()! + " \(Int.random(in: 1...99))"
                    cart.addItem(CartItem(name: name, price: Double.random(in: 1...50).rounded()))
                }
            } header: {
                Text("Items — each row uses @Bindable on a nested @Observable")
            }

            Section {
                TextField("Coupon code (try SAVE10)", text: $cart.couponCode)
                    .onChange(of: cart.couponCode) { _, new in
                        NewRelic.recordBreadcrumb("CartCoupon", attributes: ["code": new])
                    }
                HStack {
                    Text("Total")
                    Spacer()
                    Text("$\(String(format: "%.2f", cart.discountedTotal))")
                        .fontWeight(.bold)
                }
                if cart.couponCode.uppercased() == "SAVE10" {
                    Text("10% discount applied!")
                        .foregroundColor(.green).font(.caption)
                }
            } header: {
                Text("Cart summary")
            }
        }
        .navigationTitle("Nested @Observable")
        .onAppear { NewRelic.recordBreadcrumb("NestedObservableDemoView appeared") }
        .NRTrackView(name: "NestedObservableDemoView")
    }
}

@available(iOS 17.0, *)
struct CartItemRowView: View {
    @Bindable var item: CartItem   // @Bindable on a nested @Observable

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline)
                Text("$\(String(format: "%.2f", item.price)) each")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("\(item.quantity)", value: $item.quantity, in: 1...99)
                .labelsHidden()
            Text("$\(String(format: "%.2f", item.subtotal))")
                .font(.subheadline).fontWeight(.medium)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
