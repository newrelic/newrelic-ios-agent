//
//  ForgotPasswordViewController.swift
//  ExpensesTracker
//
//  Port of forgotpassword.java — one email field, one button, and a confirmation.
//
//  The Android version navigated to MainActivity on success (rather than finishing back to it) and had
//  its own BACK button in the layout because it was an Activity with no navigation bar. Both are
//  replaced by popping the navigation stack, which the system back button already offers.
//

import UIKit

final class ForgotPasswordViewController: InstrumentedViewController {

    override var viewName: ViewName { .forgotPassword }

    private let auth: AuthService
    private let emailField = Theme.textField(placeholder: "EMAIL", symbol: "envelope")
    private let resetButton = Theme.filledButton(title: "Reset Password")
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(auth: AuthService) {
        self.auth = auth
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Reset Password"

        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.accessibilityIdentifier = "forgot.email"
        resetButton.accessibilityIdentifier = "forgot.submit"

        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        resetButton.addTarget(self, action: #selector(reset), for: .touchUpInside)

        let explanation = UILabel()
        explanation.text = "We'll send a reset link to your registered email."
        explanation.font = .systemFont(ofSize: 14)
        explanation.textColor = .secondaryLabel
        explanation.numberOfLines = 0
        explanation.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            Theme.titleLabel("Forgot password?"), explanation,
            emailField, resetButton, errorLabel, spinner
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }

    @objc private func reset() {
        errorLabel.text = nil

        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !email.isEmpty else {
            errorLabel.text = "Email field can't be empty"
            return
        }

        setBusy(true)

        Task {
            do {
                try await auth.sendPasswordReset(to: email)
                setBusy(false)
                showToast("Reset Password link has been sent to your registered Email")
                navigationController?.popViewController(animated: true)
            } catch {
                setBusy(false)
                errorLabel.text = "Error : \(error.localizedDescription)"
                ErrorReporter.reportHandled(error,
                                            source: "ForgotPasswordViewController",
                                            additionalInfo: "reset request rejected")
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        resetButton.isEnabled = !busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }
}
