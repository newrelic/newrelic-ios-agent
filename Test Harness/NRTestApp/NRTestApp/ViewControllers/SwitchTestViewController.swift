//
//  SwitchTestViewController.swift
//  NRTestApp
//
//  Created by Claude Code on 3/17/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import UIKit

class SwitchTestViewController: UIViewController {

    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Switch configurations
    private let defaultSwitch = UISwitch()
    private let defaultSwitchLabel = UILabel()

    private let customGreenSwitch = UISwitch()
    private let customGreenSwitchLabel = UILabel()

    private let customBlueSwitch = UISwitch()
    private let customBlueSwitchLabel = UILabel()

    private let customPurpleSwitch = UISwitch()
    private let customPurpleSwitchLabel = UILabel()

    private let customThumbSwitch = UISwitch()
    private let customThumbSwitchLabel = UILabel()

    private let offSwitch = UISwitch()
    private let offSwitchLabel = UILabel()

    // Custom Switches
    private let customSwitch1 = CustomSwitch()
    private let customSwitch1Label = UILabel()

    private let customSwitch2 = CustomSwitch()
    private let customSwitch2Label = UILabel()

    private let customSwitch3 = CustomSwitch()
    private let customSwitch3Label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "UISwitch Test"

        setupScrollView()
        setupUI()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupUI() {
        // Title Label
        titleLabel.text = "UISwitch Examples"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        var lastView: UIView = titleLabel

        // 1. Default Switch (System Green, On)
        lastView = addSwitchRow(
            switch: defaultSwitch,
            label: defaultSwitchLabel,
            title: "Default Switch (On)",
            below: lastView
        )
        defaultSwitch.isOn = true
        defaultSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(defaultSwitchLabel, for: defaultSwitch)

        // 2. Custom Green Switch
        lastView = addSwitchRow(
            switch: customGreenSwitch,
            label: customGreenSwitchLabel,
            title: "Custom Green",
            below: lastView
        )
        customGreenSwitch.isOn = true
        customGreenSwitch.onTintColor = .systemGreen
        customGreenSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(customGreenSwitchLabel, for: customGreenSwitch)

        // 3. Custom Blue Switch
        lastView = addSwitchRow(
            switch: customBlueSwitch,
            label: customBlueSwitchLabel,
            title: "Custom Blue",
            below: lastView
        )
        customBlueSwitch.isOn = true
        customBlueSwitch.onTintColor = .systemBlue
        customBlueSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(customBlueSwitchLabel, for: customBlueSwitch)

        // 4. Custom Purple Switch
        lastView = addSwitchRow(
            switch: customPurpleSwitch,
            label: customPurpleSwitchLabel,
            title: "Custom Purple",
            below: lastView
        )
        customPurpleSwitch.isOn = false
        customPurpleSwitch.onTintColor = .systemPurple
        customPurpleSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(customPurpleSwitchLabel, for: customPurpleSwitch)

        // 5. Custom Thumb Color
        lastView = addSwitchRow(
            switch: customThumbSwitch,
            label: customThumbSwitchLabel,
            title: "Custom Thumb (Orange)",
            below: lastView
        )
        customThumbSwitch.isOn = true
        customThumbSwitch.onTintColor = .systemRed
        customThumbSwitch.thumbTintColor = .systemOrange
        customThumbSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(customThumbSwitchLabel, for: customThumbSwitch)

        // 6. Off Switch
        lastView = addSwitchRow(
            switch: offSwitch,
            label: offSwitchLabel,
            title: "Default (Off)",
            below: lastView
        )
        offSwitch.isOn = false
        offSwitch.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        updateLabel(offSwitchLabel, for: offSwitch)

        // === CustomSwitch Examples ===

        // 7. CustomSwitch - Default
        lastView = addCustomSwitchRow(
            customSwitch: customSwitch1,
            label: customSwitch1Label,
            title: "CustomSwitch - Default",
            below: lastView
        )
        customSwitch1.isOn = true
        customSwitch1.addTarget(self, action: #selector(customSwitchChanged(_:)), for: .valueChanged)
        updateCustomLabel(customSwitch1Label, for: customSwitch1)

        // 8. CustomSwitch - Square corners
        lastView = addCustomSwitchRow(
            customSwitch: customSwitch2,
            label: customSwitch2Label,
            title: "CustomSwitch - Square",
            below: lastView
        )
        customSwitch2.isOn = false
        customSwitch2.cornerRadius = 0.1
        customSwitch2.thumbCornerRadius = 0.1
        customSwitch2.onTintColor = .systemBlue
        customSwitch2.addTarget(self, action: #selector(customSwitchChanged(_:)), for: .valueChanged)
        updateCustomLabel(customSwitch2Label, for: customSwitch2)

        // 9. CustomSwitch - Custom colors
        lastView = addCustomSwitchRow(
            customSwitch: customSwitch3,
            label: customSwitch3Label,
            title: "CustomSwitch - Purple/Yellow",
            below: lastView
        )
        customSwitch3.isOn = true
        customSwitch3.onTintColor = .systemPurple
        customSwitch3.offTintColor = .systemGray3
        customSwitch3.thumbTintColor = .systemYellow
        customSwitch3.addTarget(self, action: #selector(customSwitchChanged(_:)), for: .valueChanged)
        updateCustomLabel(customSwitch3Label, for: customSwitch3)

        // Set content view height
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            lastView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }

    private func addSwitchRow(switch switchControl: UISwitch, label: UILabel, title: String, below: UIView) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        switchControl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(switchControl)

        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: below.bottomAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),

            switchControl.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            switchControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    private func addCustomSwitchRow(customSwitch: CustomSwitch, label: UILabel, title: String, below: UIView) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        customSwitch.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(customSwitch)

        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: below.bottomAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),

            customSwitch.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            customSwitch.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            customSwitch.widthAnchor.constraint(equalToConstant: 51),
            customSwitch.heightAnchor.constraint(equalToConstant: 31),

            label.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    @objc private func switchChanged(_ sender: UISwitch) {
        switch sender {
        case defaultSwitch:
            updateLabel(defaultSwitchLabel, for: sender)
        case customGreenSwitch:
            updateLabel(customGreenSwitchLabel, for: sender)
        case customBlueSwitch:
            updateLabel(customBlueSwitchLabel, for: sender)
        case customPurpleSwitch:
            updateLabel(customPurpleSwitchLabel, for: sender)
        case customThumbSwitch:
            updateLabel(customThumbSwitchLabel, for: sender)
        case offSwitch:
            updateLabel(offSwitchLabel, for: sender)
        default:
            break
        }
    }

    @objc private func customSwitchChanged(_ sender: CustomSwitch) {
        switch sender {
        case customSwitch1:
            updateCustomLabel(customSwitch1Label, for: sender)
        case customSwitch2:
            updateCustomLabel(customSwitch2Label, for: sender)
        case customSwitch3:
            updateCustomLabel(customSwitch3Label, for: sender)
        default:
            break
        }
    }

    private func updateLabel(_ label: UILabel, for switchControl: UISwitch) {
        label.text = "State: \(switchControl.isOn ? "ON ✓" : "OFF")"
    }

    private func updateCustomLabel(_ label: UILabel, for customSwitch: CustomSwitch) {
        label.text = "State: \(customSwitch.isOn ? "ON ✓" : "OFF") [Generic View Capture]"
    }
}
