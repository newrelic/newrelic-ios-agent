//
//  RegistrationViewController.swift
//  ExpensesTracker
//
//  Port of registration.java — name, email, password, and a check that the email is not already taken
//  before creating the account.
//
//  The Android version's "back to login" button called `startActivity(new Intent(this, MainActivity.class))`,
//  which pushed a *second* login screen on top of the registration screen rather than returning to the
//  first. Popping the navigation stack is what it was reaching for, so that is what this does.
//

import UIKit
import NewRelic

final class RegistrationViewController: InstrumentedViewController {

    override var viewName: ViewName { .registration }

    private let auth: AuthService
    private unowned let flow: AppFlow

    private let nameField = Theme.textField(placeholder: "NAME", symbol: "person")
    private let emailField = Theme.textField(placeholder: "EMAIL", symbol: "envelope")
    private let passwordField = Theme.textField(placeholder: "PASSWORD", symbol: "lock")
    private let registerButton = Theme.filledButton(title: "REGISTER")
    private let signInButton = Theme.textButton(title: "Already have an account? sign in here")
    private let errorLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    init(auth: AuthService, flow: AppFlow) {
        self.auth = auth
        self.flow = flow
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "REGISTRATION"

        passwordField.isSecureTextEntry = true
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        nameField.accessibilityIdentifier = "register.name"
        emailField.accessibilityIdentifier = "register.email"
        passwordField.accessibilityIdentifier = "register.password"
        registerButton.accessibilityIdentifier = "register.submit"

        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        registerButton.addTarget(self, action: #selector(register), for: .touchUpInside)
        signInButton.addTarget(self, action: #selector(backToLogin), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            Theme.titleLabel("Create an account"),
            nameField, emailField, passwordField, registerButton, errorLabel, spinner, signInButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }

    // MARK: - Actions

    @objc private func register() {
        errorLabel.text = nil

        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !name.isEmpty else {
            errorLabel.text = "NAME REQUIRED...."
            return
        }
        guard !email.isEmpty else {
            errorLabel.text = "EMAIL REQUIRED.."
            return
        }
        guard !password.isEmpty else {
            errorLabel.text = "PASSWORD REQUIRED.."
            return
        }

        setBusy(true)

        Task {
            do {
                let user = try await auth.register(name: name, email: email, password: password)
                setBusy(false)
                showToast("REGISTRATION SUCCESSFUL")
                NewRelic.recordBreadcrumb("registration_succeeded", attributes: ["uid": user.uid])
                flow.showHome()
            } catch {
                setBusy(false)
                errorLabel.text = error.localizedDescription
                showToast("REGISTRATION FAILED")
                ErrorReporter.reportHandled(error,
                                            source: "RegistrationViewController",
                                            additionalInfo: "registration rejected")
            }
        }
    }

    @objc private func backToLogin() {
        navigationController?.popViewController(animated: true)
    }

    private func setBusy(_ busy: Bool) {
        registerButton.isEnabled = !busy
        registerButton.configuration?.title = busy ? "PROCESSING..." : "REGISTER"
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }
}
