//
//  DateTimePickerViewController.swift
//  NRTestApp
//
//  Created by Claude Code on 3/13/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import UIKit

class DateTimePickerViewController: UIViewController {

    private let datePicker = UIDatePicker()
    private let selectedDateLabel = UILabel()
    private let titleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Date Time Picker"

        setupUI()
    }

    private func setupUI() {
        // Title Label
        titleLabel.text = "Select Date & Time"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Date Picker
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        view.addSubview(datePicker)

        // Selected Date Label
        selectedDateLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        selectedDateLabel.textAlignment = .center
        selectedDateLabel.numberOfLines = 0
        selectedDateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedDateLabel)

        // Set initial date
        updateSelectedDateLabel()

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            datePicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            datePicker.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            selectedDateLabel.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 30),
            selectedDateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            selectedDateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func dateChanged() {
        updateSelectedDateLabel()
    }

    private func updateSelectedDateLabel() {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        selectedDateLabel.text = "Selected:\n\(formatter.string(from: datePicker.date))"
    }
}
