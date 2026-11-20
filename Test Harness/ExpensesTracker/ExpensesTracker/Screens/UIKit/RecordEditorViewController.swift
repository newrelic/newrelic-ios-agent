//
//  RecordEditorViewController.swift
//  ExpensesTracker
//
//  Port of the two Android dialogs: custom_layout_for_adding_data.xml (amount, purpose, note, Save,
//  Cancel) and update_item.xml (the same three fields with Update and Delete).
//
//  They were the same three fields with different buttons, and the Android app inflated them from four
//  places — dashboardFragment did it twice, once for income and once for expense, and each list fragment
//  did it again for updates. One screen covers all four, with `existing` deciding whether it is an insert
//  or an edit.
//
//  It is a presented sheet rather than an alert. The Android originals were AlertDialogs with a custom
//  view, which on iOS would mean a UIAlertController with text fields — capped at a single line each, no
//  keyboard control, and no room for the validation messages. A sheet is also a real view as far as the
//  agent is concerned, which an alert's text fields are not, so the add and edit steps show up in the
//  MobileView timeline as the distinct screens they are.
//

import UIKit
import NewRelic

final class RecordEditorViewController: InstrumentedViewController {

    override var viewName: ViewName { existing == nil ? .addRecord : .updateRecord }
    override var viewAttributes: [String: Any] {
        var attributes: [String: Any] = ["ledger": kind.rawValue,
                                        "mode": existing == nil ? "insert" : "update"]
        if let existing {
            // The purpose rides along as an attribute rather than in the view name: view name is a facet,
            // and one name per record would make that facet useless.
            attributes["purpose"] = existing.purpose
        }
        return attributes
    }

    private let kind: RecordKind
    private let existing: LedgerRecord?
    private let store: LedgerStore

    private let amountField = Theme.textField(placeholder: "Amount", symbol: "number")
    private let purposeField = Theme.textField(placeholder: "Purpose", symbol: "tag")
    private let noteField = Theme.textField(placeholder: "Note", symbol: "note.text")
    private let errorLabel = UILabel()

    init(kind: RecordKind, existing: LedgerRecord?, store: LedgerStore) {
        self.kind = kind
        self.existing = existing
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = existing == nil
            ? "Add \(kind.displayName.lowercased())"
            : "Edit \(kind.displayName.lowercased())"

        amountField.keyboardType = .numberPad
        amountField.accessibilityIdentifier = "editor.amount"
        purposeField.accessibilityIdentifier = "editor.purpose"
        noteField.accessibilityIdentifier = "editor.note"

        if let existing {
            amountField.text = String(existing.amount)
            purposeField.text = existing.purpose
            noteField.text = existing.note
        }

        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0

        configureBarButtons()
        layout()
    }

    private func configureBarButtons() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel", style: .plain, target: self, action: #selector(cancel)
        )

        let saveTitle = existing == nil ? "Save" : "Update"
        let saveItem = UIBarButtonItem(title: saveTitle, style: .done, target: self, action: #selector(save))
        saveItem.accessibilityIdentifier = "editor.save"
        navigationItem.rightBarButtonItem = saveItem
    }

    private func layout() {
        let fields = UIStackView(arrangedSubviews: [amountField, purposeField, noteField, errorLabel])
        fields.axis = .vertical
        fields.spacing = 12

        let stack = UIStackView(arrangedSubviews: [fields])
        stack.axis = .vertical
        stack.spacing = 24

        // update_item.xml carried a Delete button beside Update; an insert had no equivalent.
        if existing != nil {
            let deleteButton = Theme.filledButton(title: "Delete", color: .systemRed)
            deleteButton.accessibilityIdentifier = "editor.delete"
            deleteButton.addTarget(self, action: #selector(confirmDelete), for: .touchUpInside)
            stack.addArrangedSubview(deleteButton)
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Actions

    @objc private func cancel() {
        dismiss(animated: true)
    }

    @objc private func save() {
        errorLabel.text = nil

        let amountText = amountField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let purpose = purposeField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let note = noteField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Android checked amount, then parsed it with Integer.parseInt, then checked the other two — so a
        // non-numeric amount crashed with a NumberFormatException before the remaining validation ran.
        // Validating all three first, and treating a bad number as a validation failure, is the fix.
        guard !amountText.isEmpty else {
            errorLabel.text = "Amount required...."
            return
        }
        guard !purpose.isEmpty else {
            errorLabel.text = "Purpose required...."
            return
        }
        guard !note.isEmpty else {
            errorLabel.text = "Note required...."
            return
        }
        guard let amount = Int(amountText), amount > 0 else {
            errorLabel.text = "Amount must be a whole number greater than zero"
            ErrorReporter.recordErrorEvent(type: "validation_error",
                                          source: viewName.rawValue,
                                          message: "amount was not a positive integer: \(amountText)",
                                          severity: "info")
            return
        }

        Task {
            if let existing {
                let updated = LedgerRecord(id: existing.id,
                                          amount: amount,
                                          purpose: purpose,
                                          note: note,
                                          dateText: LedgerRecord.timestamp())
                await store.update(updated, in: kind)

                NewRelic.logInfo("\(viewName.rawValue): record updated — purpose: \(purpose)")
                NewRelic.logAttributes([
                    "action": "update",
                    "ledger": kind.rawValue,
                    "purpose": purpose,
                    "amount": amount
                ])
                presentingViewController?.showToast("DATA UPDATED")
            } else {
                let record = LedgerRecord(amount: amount, purpose: purpose, note: note)
                await store.add(record, to: kind)

                NewRelic.logInfo("\(viewName.rawValue): record inserted — purpose: \(purpose)")
                presentingViewController?.showToast("Data Inserted")
            }
            dismiss(animated: true)
        }
    }

    /// Android deleted on the first tap, with no confirmation and no undo.
    @objc private func confirmDelete() {
        guard let existing else { return }

        let alert = UIAlertController(title: "Delete record?",
                                     message: "\(existing.purpose) — \(existing.displayAmount(for: kind))",
                                     preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.delete(existing)
        })
        present(alert, animated: true)
    }

    private func delete(_ record: LedgerRecord) {
        Task {
            await store.delete(record, from: kind)

            NewRelic.logInfo("\(viewName.rawValue): record deleted — purpose: \(record.purpose)")
            NewRelic.logAttributes([
                "action": "delete",
                "ledger": kind.rawValue,
                "purpose": record.purpose,
                "amount": record.amount
            ])
            presentingViewController?.showToast("Record deleted")
            dismiss(animated: true)
        }
    }
}
