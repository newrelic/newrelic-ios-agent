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
