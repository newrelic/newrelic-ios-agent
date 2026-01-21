//
//  ConfidentialViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 12/3/25.
//

import UIKit
import NewRelic

class ConfidentialViewController: UIViewController {
    
    private var wasReplayPaused = false
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statusLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Confidential View"
        #if os(iOS)
        self.view.backgroundColor = .systemBackground
        #endif
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Pause session replay when entering confidential view
        wasReplayPaused = NewRelic.pauseReplay()
        updateStatusLabel()
        
        NewRelic.logInfo("Confidential view appeared - Session Replay paused: \(wasReplayPaused)")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Resume session replay only if we successfully paused it, we only want to start the replay back up if it was recording already
        if wasReplayPaused {
            let resumed = NewRelic.recordReplay()
            NewRelic.logInfo("Confidential view disappearing - Session Replay resumed: \(resumed)")
            wasReplayPaused = false
        }
    }
    
    private func setupUI() {
        // Title Label
        titleLabel.text = "🔒 Confidential Content"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Description Label
        descriptionLabel.text = "This view contains sensitive information.\n\nSession Replay is paused while viewing this screen to protect your privacy."
        descriptionLabel.font = .systemFont(ofSize: 16)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Status Label
        statusLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Confidential content example
        let confidentialStack = createConfidentialContentSection()
        
        // Main Stack
        let mainStack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel, statusLabel, confidentialStack])
        mainStack.axis = .vertical
        mainStack.spacing = 24
        mainStack.alignment = .fill
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func createConfidentialContentSection() -> UIStackView {
        let containerView = UIView()
#if os(iOS)

        containerView.backgroundColor = .systemGray6
        #endif
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor.systemRed.cgColor
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Example confidential data
        let fields = [
            ("SSN:", "123-45-6789"),
            ("Credit Card:", "4532 1234 5678 9010"),
            ("Password:", "••••••••••"),
            ("Account Number:", "9876543210")
        ]
        
        for (label, value) in fields {
            let fieldStack = UIStackView()
            fieldStack.axis = .horizontal
            fieldStack.spacing = 8
            
            let labelView = UILabel()
            labelView.text = label
            labelView.font = .boldSystemFont(ofSize: 14)
            labelView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            
            let valueView = UILabel()
            valueView.text = value
            valueView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            
            fieldStack.addArrangedSubview(labelView)
            fieldStack.addArrangedSubview(valueView)
            
            contentStack.addArrangedSubview(fieldStack)
        }
        
        containerView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        let wrapperStack = UIStackView(arrangedSubviews: [containerView])
        wrapperStack.axis = .vertical
        
        return wrapperStack
    }
    
    private func updateStatusLabel() {
        if wasReplayPaused {
            statusLabel.text = "✓ Session Replay Paused"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "⚠️ Session Replay Not Paused\n(May not have been recording)"
            statusLabel.textColor = .systemOrange
        }
    }
}
