//  MinimalReproView.swift
//  NewRelicDemo
//
//  Created by Anna Shabalina on 11/19/2025.
//

//  Minimal reproduction of performance issue: SwiftUI TabView + one UIViewControllerRepresentable

import SwiftUI
import OSLog
import NewRelic
import os.signpost

@available(iOS 17.0, *)
@Observable @MainActor
class MinimalTabsModel {
    var selected: Int = 0 {
        didSet { instrumentTabSwitch(from: oldValue, to: selected) }
    }
    private let log = OSLog(subsystem: "com.cincas.NewRelicDemo", category: "perf")
    private let signpostName: StaticString = "TabSwitchMinimal"

    private func instrumentTabSwitch(from old: Int, to new: Int) {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: signpostName, "from:%d to:%d", old, new)
        let start = CFAbsoluteTimeGetCurrent()

        // Minimal single custom event (comment out to isolate SDK impact)
        NewRelic.recordCustomEvent("minimal_tab_changed", attributes: [
            "from": NSNumber(value: old),
            "to": NSNumber(value: new)
        ])

        let end = CFAbsoluteTimeGetCurrent()
        let costMs = (end - start) * 1000
        if costMs > 2.0 {
         //   Logger.performance.warning("Minimal sync NR cost \(String(format: "%.2f", costMs))ms")
        }
        os_signpost(.end, log: log, name: signpostName, "cost_ms:%.2f", costMs)
    }
}

@available(iOS 17.0, *)
struct MinimalReproView: View {
    @State private var model = MinimalTabsModel()
    var body: some View {
        TabView(selection: $model.selected) {
            VStack(spacing: 24) {
                Text("Pure SwiftUI Tab")
                    .font(.title3)
                Text("Version under test uses agent calls only on tab change.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .tag(0)
            .tabItem { Label("SwiftUI", systemImage: "swift") }

            HostedControllerView(label: "Controller")
                .tag(1)
                .tabItem { Label("UIKit", systemImage: "rectangle") }
        }
    }
}

struct HostedControllerView: UIViewControllerRepresentable {
    let label: String
    func makeUIViewController(context: Context) -> MinimalController { MinimalController(text: label) }
    func updateUIViewController(_ uiViewController: MinimalController, context: Context) { }
}

final class MinimalController: UIViewController {
    private let text: String
    init(text: String) { self.text = text; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBlue
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}
