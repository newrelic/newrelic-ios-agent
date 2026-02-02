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
