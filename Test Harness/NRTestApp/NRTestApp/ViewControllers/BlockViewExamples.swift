//
//  BlockViewExamples.swift
//  NRTestApp
//
//  Examples demonstrating the new blockView functionality for Session Replay
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI
import UIKit
import NewRelic

// MARK: - SwiftUI Example

struct KeypadSwiftUIExample: View {
    @State private var pin: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter PIN")
                .font(.title)

            // Display entered PIN (this would normally show dots)
            Text(pin.isEmpty ? "Enter your PIN" : String(repeating: "*", count: pin.count))
                .font(.headline)
                .padding()

            // Keypad wrapped in NRConditionalMaskView with blockView: true
            NRConditionalMaskView(blockView: true) {
                VStack(spacing: 15) {
                    // Row 1
                    HStack(spacing: 15) {
                        keypadButton("1")
                        keypadButton("2")
                        keypadButton("3")
                    }

                    // Row 2
                    HStack(spacing: 15) {
                        keypadButton("4")
                        keypadButton("5")
                        keypadButton("6")
                    }

                    // Row 3
                    HStack(spacing: 15) {
                        keypadButton("7")
                        keypadButton("8")
                        keypadButton("9")
                    }

                    // Row 4
                    HStack(spacing: 15) {
                        clearButton()
                        keypadButton("0")
                        deleteButton()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("BlockView SwiftUI")
    }

    private func keypadButton(_ digit: String) -> some View {
        Button(action: {
            if pin.count < 6 {
                pin += digit
            }
        }) {
            Text(digit)
                .font(.title)
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func clearButton() -> some View {
        Button(action: {
            pin = ""
        }) {
            Text("Clear")
                .font(.caption)
                .frame(width: 60, height: 60)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func deleteButton() -> some View {
        Button(action: {
            if !pin.isEmpty {
                pin.removeLast()
            }
        }) {
            Image(systemName: "delete.left")
                .font(.title2)
                .frame(width: 60, height: 60)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

// MARK: - UIKit Example

class KeypadUIKitViewController: UIViewController {
    private var pin: String = ""
    private var pinLabel: UILabel!
    private var keypadContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "BlockView UIKit"
        setupUI()
    }

    private func setupUI() {
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Enter PIN"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // PIN display
        pinLabel = UILabel()
        pinLabel.text = "Enter your PIN"
        pinLabel.font = .systemFont(ofSize: 18, weight: .medium)
        pinLabel.textAlignment = .center
        pinLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pinLabel)

        // Keypad container with blockView
        keypadContainerView = UIView()
        keypadContainerView.backgroundColor = UIColor.systemGray6
        keypadContainerView.layer.cornerRadius = 10
        keypadContainerView.translatesAutoresizingMaskIntoConstraints = false

        // Set the blockView property to block this entire view
        keypadContainerView.blockView = true

        view.addSubview(keypadContainerView)

        setupKeypad()

        // Alternative example container using accessibility ID
        let alternativeContainer = UIView()
        alternativeContainer.backgroundColor = UIColor.systemGray5
        alternativeContainer.layer.cornerRadius = 10
        alternativeContainer.translatesAutoresizingMaskIntoConstraints = false
        alternativeContainer.accessibilityIdentifier = "nr-block" // This will trigger blocking
        view.addSubview(alternativeContainer)

        // Add some buttons to the alternative container
        let buttonA = createAlternativeButton(title: "A")
        let buttonB = createAlternativeButton(title: "B")

        let altLabel = UILabel()
        altLabel.text = "Alternative: Using accessibility ID"
        altLabel.font = .systemFont(ofSize: 12)
        altLabel.textColor = .systemGray
        altLabel.textAlignment = .center
        altLabel.translatesAutoresizingMaskIntoConstraints = false
        alternativeContainer.addSubview(altLabel)

        let altStackView = UIStackView(arrangedSubviews: [buttonA, buttonB])
        altStackView.axis = .horizontal
        altStackView.spacing = 10
        altStackView.translatesAutoresizingMaskIntoConstraints = false
        alternativeContainer.addSubview(altStackView)

        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            pinLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            pinLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            keypadContainerView.topAnchor.constraint(equalTo: pinLabel.bottomAnchor, constant: 30),
            keypadContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            keypadContainerView.widthAnchor.constraint(equalToConstant: 220),
            keypadContainerView.heightAnchor.constraint(equalToConstant: 280),

            alternativeContainer.topAnchor.constraint(equalTo: keypadContainerView.bottomAnchor, constant: 30),
            alternativeContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alternativeContainer.widthAnchor.constraint(equalToConstant: 150),
            alternativeContainer.heightAnchor.constraint(equalToConstant: 100),

            altLabel.topAnchor.constraint(equalTo: alternativeContainer.topAnchor, constant: 10),
            altLabel.centerXAnchor.constraint(equalTo: alternativeContainer.centerXAnchor),

            altStackView.centerXAnchor.constraint(equalTo: alternativeContainer.centerXAnchor),
            altStackView.centerYAnchor.constraint(equalTo: alternativeContainer.centerYAnchor, constant: 10)
        ])
    }

    private func setupKeypad() {
        let buttonSize: CGFloat = 60
        let spacing: CGFloat = 15
        let padding: CGFloat = 20

        // Create buttons for digits 1-9, 0, Clear, and Delete
        let buttons: [(String, Int, Int)] = [
            ("1", 0, 0), ("2", 0, 1), ("3", 0, 2),
            ("4", 1, 0), ("5", 1, 1), ("6", 1, 2),
            ("7", 2, 0), ("8", 2, 1), ("9", 2, 2),
            ("Clear", 3, 0), ("0", 3, 1), ("⌫", 3, 2)
        ]

        for (title, row, col) in buttons {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
            button.backgroundColor = title == "Clear" ? .systemRed :
                                   title == "⌫" ? .systemOrange : .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.translatesAutoresizingMaskIntoConstraints = false

            button.addTarget(self, action: #selector(keypadButtonTapped(_:)), for: .touchUpInside)

            keypadContainerView.addSubview(button)

            let x = padding + CGFloat(col) * (buttonSize + spacing)
            let y = padding + CGFloat(row) * (buttonSize + spacing)

            NSLayoutConstraint.activate([
                button.leftAnchor.constraint(equalTo: keypadContainerView.leftAnchor, constant: x),
                button.topAnchor.constraint(equalTo: keypadContainerView.topAnchor, constant: y),
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }
    }

    private func createAlternativeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])

        return button
    }

    @objc private func keypadButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }

        switch title {
        case "Clear":
            pin = ""
        case "⌫":
            if !pin.isEmpty {
                pin.removeLast()
            }
        case let digit where digit.allSatisfy(\.isNumber):
            if pin.count < 6 {
                pin += digit
            }
        default:
            break
        }

        updatePinDisplay()
    }

    private func updatePinDisplay() {
        pinLabel.text = pin.isEmpty ? "Enter your PIN" : String(repeating: "*", count: pin.count)
    }
}

// MARK: - SwiftUI Hosting Controller

class BlockViewSwiftUIHostingController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let swiftUIView = KeypadSwiftUIExample()
        let hostingController = UIHostingController(rootView: swiftUIView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - Propagation Test Controller

class BlockViewPropagationTestController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "BlockView Propagation Test"
        setupPropagationTest()
    }

    private func setupPropagationTest() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // Test 1: Parent blocked with blockView = true
        let test1Container = createTestContainer(
            title: "Test 1: Parent blockView = true",
            parentBlocked: true,
            backgroundColor: .systemBlue
        )

        // Test 2: Parent blocked with accessibility ID
        let test2Container = createTestContainer(
            title: "Test 2: Parent accessibility ID = nr-block",
            parentBlocked: false,
            backgroundColor: .systemGreen,
            useAccessibilityID: true
        )

        // Test 3: Control - Not blocked
        let test3Container = createTestContainer(
            title: "Test 3: Control - Not blocked",
            parentBlocked: false,
            backgroundColor: .systemOrange
        )

        contentView.addSubview(test1Container)
        contentView.addSubview(test2Container)
        contentView.addSubview(test3Container)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            test1Container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            test1Container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            test1Container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            test2Container.topAnchor.constraint(equalTo: test1Container.bottomAnchor, constant: 30),
            test2Container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            test2Container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            test3Container.topAnchor.constraint(equalTo: test2Container.bottomAnchor, constant: 30),
            test3Container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            test3Container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            test3Container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func createTestContainer(title: String, parentBlocked: Bool, backgroundColor: UIColor, useAccessibilityID: Bool = false) -> UIView {
        let container = UIView()
        container.backgroundColor = backgroundColor
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        // Set blocking behavior
        if useAccessibilityID {
            container.accessibilityIdentifier = "nr-block"
        } else if parentBlocked {
            container.blockView = true
        }

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Create nested child views to test propagation
        let child1 = UIView()
        child1.backgroundColor = .systemRed
        child1.layer.cornerRadius = 5
        child1.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child1)

        let child1Label = UILabel()
        child1Label.text = "Child 1"
        child1Label.font = .systemFont(ofSize: 14)
        child1Label.textColor = .white
        child1Label.textAlignment = .center
        child1Label.translatesAutoresizingMaskIntoConstraints = false
        child1.addSubview(child1Label)

        // Nested grandchild
        let grandchild = UIView()
        grandchild.backgroundColor = .systemPurple
        grandchild.layer.cornerRadius = 3
        grandchild.translatesAutoresizingMaskIntoConstraints = false
        child1.addSubview(grandchild)

        // Make grandchild interactive to test touch blocking
        let grandchildButton = UIButton(type: .system)
        grandchildButton.setTitle("Touch Test", for: .normal)
        grandchildButton.setTitleColor(.white, for: .normal)
        grandchildButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .bold)
        grandchildButton.translatesAutoresizingMaskIntoConstraints = false
        grandchildButton.addTarget(self, action: #selector(touchTestButtonTapped(_:)), for: .touchUpInside)
        grandchild.addSubview(grandchildButton)

        // Another child view
        let child2 = UIView()
        child2.backgroundColor = .systemIndigo
        child2.layer.cornerRadius = 5
        child2.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(child2)

        // Make child2 interactive to test touch blocking
        let child2Button = UIButton(type: .system)
        child2Button.setTitle("Tap Me", for: .normal)
        child2Button.setTitleColor(.white, for: .normal)
        child2Button.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        child2Button.translatesAutoresizingMaskIntoConstraints = false
        child2Button.addTarget(self, action: #selector(touchTestButtonTapped(_:)), for: .touchUpInside)
        child2.addSubview(child2Button)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 200),

            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            child1.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            child1.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            child1.widthAnchor.constraint(equalToConstant: 120),
            child1.heightAnchor.constraint(equalToConstant: 80),

            child1Label.topAnchor.constraint(equalTo: child1.topAnchor, constant: 5),
            child1Label.centerXAnchor.constraint(equalTo: child1.centerXAnchor),

            grandchild.topAnchor.constraint(equalTo: child1Label.bottomAnchor, constant: 5),
            grandchild.centerXAnchor.constraint(equalTo: child1.centerXAnchor),
            grandchild.widthAnchor.constraint(equalToConstant: 80),
            grandchild.heightAnchor.constraint(equalToConstant: 30),

            grandchildButton.centerXAnchor.constraint(equalTo: grandchild.centerXAnchor),
            grandchildButton.centerYAnchor.constraint(equalTo: grandchild.centerYAnchor),

            child2.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            child2.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            child2.widthAnchor.constraint(equalToConstant: 100),
            child2.heightAnchor.constraint(equalToConstant: 60),

            child2Button.centerXAnchor.constraint(equalTo: child2.centerXAnchor),
            child2Button.centerYAnchor.constraint(equalTo: child2.centerYAnchor)
        ])

        return container
    }

    @objc private func touchTestButtonTapped(_ sender: UIButton) {
        // This will help test which touches are recorded in session replay
        let alert = UIAlertController(
            title: "Touch Detected!",
            message: "This button tap was processed.\nIn blocked areas, touches should not appear in session replay.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = CGAffineTransform.identity
            }
        }
    }
}

// MARK: - Sign-Out Crash Repro (NR-566282)
//
// Reproduces the customer flow that previously crashed Session Replay:
//   1. A "logged-in" screen builds a dense view tree where every UIView has an
//      explicit borderColor + backgroundColor on its CALayer.
//   2. The user taps Sign Out, which swaps the window's rootViewController in a
//      tight loop. Each swap deallocates the entire previous tree, including
//      every layer's backing CGColor.
//   3. Session Replay's once-per-second capture pass walks the tree on the
//      main thread and tries to read those same colors. Before NR-566282 this
//      resulted in EXC_BAD_ACCESS inside CGColorSpaceGetModel /
//      UIColor.init(cgColor:). With the safeColor guards, autoreleasepool,
//      and NRMAExceptionHandler.safelyRun backstop in place the capture either
//      sees the new tree or drops a single frame — no crash.
//
// To exercise the fix:
//   1. Run NRTestApp with Session Replay enabled (see AppDelegate config).
//   2. Open this VC from the main menu ("Sign-Out Crash Repro").
//   3. Tap "Sign Out (Repro)" and watch the device log: no EXC_BAD_ACCESS.
//      You may see "Session replay frame skipped after NSException: ..."
//      lines from NRMASessionReplay.takeFrame() — those are the backstop
//      doing its job.

#if os(iOS)
final class SignOutCrashReproViewController: UIViewController {

    private let statusLabel = UILabel()
    private let signOutButton = UIButton(type: .system)

    /// How many times the rootViewController is swapped per Sign-Out tap.
    /// Tuned to a value that reliably overlapped with at least one Session
    /// Replay capture pass during local testing.
    private let swapCount = 30
    /// Delay between swaps. Short enough to land inside one SR tick, long
    /// enough to allow the runloop to fire layout / deallocation.
    private let swapInterval: TimeInterval = 0.05

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign-Out Crash Repro"
        view.backgroundColor = .systemBackground

        buildDenseColoredTree()
        installSignOutButton()
        installStatusLabel()
    }

    // MARK: Tree of layered, colored views

    /// Builds 4 levels × 5 children per level of nested UIViews, each with a
    /// distinct random borderColor + backgroundColor set directly on the
    /// CALayer. The customer crash signature is specifically a CGColor read
    /// off a deallocating layer, so the more layers-with-colors the better.
    private func buildDenseColoredTree() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemGray6
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.heightAnchor.constraint(equalToConstant: 360)
        ])

        addColoredChildren(into: container, depth: 4, fanOut: 5)
    }

    private func addColoredChildren(into parent: UIView, depth: Int, fanOut: Int) {
        guard depth > 0 else { return }
        for i in 0..<fanOut {
            let child = UIView()
            child.translatesAutoresizingMaskIntoConstraints = false
            child.backgroundColor = UIColor(
                red: .random(in: 0...1),
                green: .random(in: 0...1),
                blue: .random(in: 0...1),
                alpha: 1.0
            )
            // Set borderColor directly on the layer — this is the exact path
            // ViewDetails.init(view:) reads from.
            child.layer.borderWidth = 1.0
            child.layer.borderColor = UIColor(
                red: .random(in: 0...1),
                green: .random(in: 0...1),
                blue: .random(in: 0...1),
                alpha: 1.0
            ).cgColor
            child.layer.cornerRadius = 4

            parent.addSubview(child)
            NSLayoutConstraint.activate([
                child.topAnchor.constraint(equalTo: parent.topAnchor, constant: CGFloat(i) * 4 + 8),
                child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: CGFloat(i) * 4 + 8),
                child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -(CGFloat(i) * 4 + 8)),
                child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -(CGFloat(i) * 4 + 8))
            ])

            addColoredChildren(into: child, depth: depth - 1, fanOut: fanOut)
        }
    }

    // MARK: Sign-out flow that triggers the race

    private func installSignOutButton() {
        signOutButton.translatesAutoresizingMaskIntoConstraints = false
        signOutButton.setTitle("Sign Out (Repro)", for: .normal)
        signOutButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        signOutButton.accessibilityIdentifier = "sign_out_repro_button"
        signOutButton.addTarget(self, action: #selector(didTapSignOut), for: .touchUpInside)
        view.addSubview(signOutButton)
        NSLayoutConstraint.activate([
            signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signOutButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func installStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.text = "Tap Sign Out to swap the rootViewController \(swapCount)× in \(Int(Double(swapCount) * swapInterval * 1000)) ms while Session Replay is recording."
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.bottomAnchor.constraint(equalTo: signOutButton.topAnchor, constant: -16)
        ])
    }

    @objc private func didTapSignOut() {
        guard let window = view.window else { return }
        signOutButton.isEnabled = false
        cycleSignOut(window: window, remaining: swapCount)
    }

    /// Replaces the window's rootViewController repeatedly. Each replacement
    /// deallocates the previous controller's entire view tree (and every
    /// layer's CGColor along with it) on the main thread — exactly the
    /// situation that produced the customer's EXC_BAD_ACCESS.
    private func cycleSignOut(window: UIWindow, remaining: Int) {
        guard remaining > 0 else {
            // Final state: a fresh, simple "logged out" screen so the test app
            // is in a recognisable state when the loop ends.
            let final = SignedOutPlaceholderViewController()
            window.rootViewController = UINavigationController(rootViewController: final)
            return
        }

        let next = SignOutCrashReproViewController()
        window.rootViewController = UINavigationController(rootViewController: next)

        DispatchQueue.main.asyncAfter(deadline: .now() + swapInterval) { [weak self, weak window] in
            guard let self = self, let window = window else { return }
            self.cycleSignOut(window: window, remaining: remaining - 1)
        }
    }
}

/// Tiny placeholder shown when the swap loop finishes. Gives the user a clear
/// "we made it through without crashing" indicator.
final class SignedOutPlaceholderViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Signed Out"
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Sign-out repro completed without crashing."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }
}
#endif
