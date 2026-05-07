//  BridgeStressView.swift
//  NRTestApp
//
//  Mixed UIKit/SwiftUI bridge stress screen.
//
//  Nesting (outer → inner):
//    SwiftUI TabView
//      └─ UIViewControllerRepresentable  (NavControllerBridge)
//          └─ UINavigationController
//              └─ UIHostingController
//                  └─ SwiftUI content (InnerSwiftUIScreen)
//                      └─ UIViewControllerRepresentable  (InnerUIKitBridge)
//                          └─ UIViewController (with native UIKit controls)
//
//  This ordering crosses the SwiftUI↔UIKit boundary three times and is where
//  SR's view-tree walker is most likely to miss a hosting layer.

import SwiftUI
import UIKit

struct BridgeStressView: View {
    @State private var tab: Int = 0

    var body: some View {
        TabView(selection: $tab) {
            NavControllerBridge(rootTitle: "Alpha", accent: .systemIndigo)
                .ignoresSafeArea()
                .tag(0)
                .tabItem { Label("Alpha", systemImage: "a.circle") }

            NavControllerBridge(rootTitle: "Bravo", accent: .systemTeal)
                .ignoresSafeArea()
                .tag(1)
                .tabItem { Label("Bravo", systemImage: "b.circle") }

            NavControllerBridge(rootTitle: "Charlie", accent: .systemPink)
                .ignoresSafeArea()
                .tag(2)
                .tabItem { Label("Charlie", systemImage: "c.circle") }
        }
        .navigationBarTitle("Bridge Stress", displayMode: .inline)
    }
}

// MARK: - Layer 2: SwiftUI → UIKit (UINavigationController)

private struct NavControllerBridge: UIViewControllerRepresentable {
    let rootTitle: String
    let accent: UIColor

    func makeUIViewController(context: Context) -> UINavigationController {
        let inner = UIHostingController(rootView: InnerSwiftUIScreen(title: rootTitle, accent: Color(accent), depth: 0))
        inner.title = rootTitle
        let nav = UINavigationController(rootViewController: inner)
        nav.navigationBar.prefersLargeTitles = false
        nav.navigationBar.tintColor = accent
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}

// MARK: - Layer 4: UIKit (UIHostingController) → SwiftUI content

private struct InnerSwiftUIScreen: View {
    let title: String
    let accent: Color
    let depth: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("SwiftUI layer (depth \(depth))")
                    .font(.headline)
                Text("Hosted inside a UIHostingController, inside a UINavigationController, inside a SwiftUI TabView.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Plain SwiftUI controls so the walker has to classify SwiftUI leaves
                // inside a UIKit-hosted subtree.
                HStack {
                    Button("SwiftUI Button") { }
                        .buttonStyle(.borderedProminent)
                    Toggle("Toggle", isOn: .constant(true)).labelsHidden()
                }

                // Layer 5: SwiftUI → UIKit again, one level deeper.
                InnerUIKitBridge(title: "\(title) · UIKit subview", accent: UIColor(accent))
                    .frame(height: 180)
                    .cornerRadius(12)

                // Push-deeper link so the nav stack actually grows.
                NavigationLink {
                    // Pushed destination is still SwiftUI, hosted by the SAME
                    // UIHostingController-in-UINavigationController, and contains
                    // yet another UIViewControllerRepresentable.
                    InnerSwiftUIScreen(title: title, accent: accent, depth: depth + 1)
                        .navigationBarTitle("\(title) · depth \(depth + 1)", displayMode: .inline)
                } label: {
                    HStack {
                        Image(systemName: "arrow.turn.down.right")
                        Text("Push deeper")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(accent.opacity(0.15))
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationBarTitle(Text(title), displayMode: .inline)
    }
}

// MARK: - Layer 5: SwiftUI → UIKit (the inner representable)

private struct InnerUIKitBridge: UIViewControllerRepresentable {
    let title: String
    let accent: UIColor

    func makeUIViewController(context: Context) -> InnerUIKitVC {
        InnerUIKitVC(title: title, accent: accent)
    }

    func updateUIViewController(_ uiViewController: InnerUIKitVC, context: Context) {
        uiViewController.apply(title: title, accent: accent)
    }
}

private final class InnerUIKitVC: UIViewController {
    private let titleLabel = UILabel()
    private let field = UITextField()
    private let button = UIButton(type: .system)
    private let swtch = UISwitch()

    init(title: String, accent: UIColor) {
        super.init(nibName: nil, bundle: nil)
        apply(title: title, accent: accent)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.numberOfLines = 0

        field.borderStyle = .roundedRect
        field.placeholder = "UIKit text field"

        button.setTitle("UIKit Button", for: .normal)
        button.configuration = .tinted()

        swtch.isOn = true

        let row = UIStackView(arrangedSubviews: [button, swtch])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        let stack = UIStackView(arrangedSubviews: [titleLabel, field, row])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -12)
        ])
    }

    func apply(title: String, accent: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = accent
        view?.backgroundColor = accent.withAlphaComponent(0.08)
        button.tintColor = accent
        swtch.onTintColor = accent
    }
}
