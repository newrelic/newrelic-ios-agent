//
//  BlockViewExamples.swift
//  NewRelic iOS Agent
//
//  Examples demonstrating the new blockView functionality for Session Replay
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI
import UIKit

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

            // Alternative approach using accessibility identifier
            VStack(spacing: 15) {
                Text("Alternative: Using accessibility ID")
                    .font(.caption)
                    .foregroundColor(.gray)

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button("A") { /* action */ }
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)

                        Button("B") { /* action */ }
                            .frame(width: 50, height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("nr-block") // This will also trigger blocking
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
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

// MARK: - Usage Examples Documentation

/*
## How to Use BlockView Functionality

### SwiftUI Approach

1. **Using NRConditionalMaskView with blockView parameter:**
```swift
NRConditionalMaskView(blockView: true) {
    // Your sensitive UI content here
    YourSensitiveView()
}
```

2. **Using accessibility identifier:**
```swift
YourSensitiveView()
    .accessibilityIdentifier("nr-block")
```

### UIKit Approach

1. **Using the blockView property directly:**
```swift
let sensitiveView = UIView()
sensitiveView.blockView = true
```

2. **Using accessibility identifier:**
```swift
let sensitiveView = UIView()
sensitiveView.accessibilityIdentifier = "nr-block"
```

### What Happens When a View is Blocked

When a view is marked with `blockView: true` or has the accessibility identifier "nr-block":

- The entire view area becomes a solid black rectangle in session replay
- All content within that view is completely hidden
- Subviews are also blocked (blocking cascades down the view hierarchy)
- User interactions in that area are still captured but the visual content is blocked

### Difference from Masking

- **Masking**: Replaces specific content (text becomes asterisks, images become placeholders)
- **Blocking**: Creates a complete black overlay covering the entire view area
*/