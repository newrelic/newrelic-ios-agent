//
//  LoginViewController.swift
//  ExpensesTracker
//
//  Port of MainActivity — which, despite the name, was the login screen.
//
//  What the Java did, in order: started the New Relic agent, logged device attributes, set a user id,
//  opened and closed an interaction, then checked connectivity and either showed a "no internet" screen
//  or wired up the login form. Only the last of those is a login screen's job:
//
//    * Agent startup, device attributes, user id and the interaction moved to NewRelicConfig, called
//      from the app delegate. See the note there.
//
//    * The connectivity check and its dedicated no-internet layout are gone. It used the deprecated
//      `getActiveNetworkInfo()`, and its refresh button relaunched MainActivity on top of itself so the
//      stack grew with each tap. More to the point, this app's data lives on a local stub server, so
//      "no internet" is not a state it can be in. The failure the app can actually be in — the server
//      not answering — surfaces as a request error the agent records, which is the more useful signal.
//
//  What is kept exactly: the field-level validation and its uppercase error text, the three
//  destinations (home, registration, forgot password), and the progress indicator over the sign-in call.
//

import UIKit
import NewRelic

final class LoginViewController: InstrumentedViewController {

    override var viewName: ViewName { .login }
    /// The Android app opened an interaction named after this screen at startup. Doing it here instead
    /// means the trace covers the screen actually being built, which is what an interaction is for.
    override var tracksInteraction: Bool { true }

    private let auth: AuthService
    private unowned let flow: AppFlow

    private let emailField = Theme.textField(placeholder: "EMAIL", symbol: "envelope")
    private let passwordField = Theme.textField(placeholder: "PASSWORD", symbol: "lock")
    private let loginButton = Theme.filledButton(title: "LOG IN")
    private let forgotButton = Theme.textButton(title: "Forgot password?")
    private let signUpButton = Theme.textButton(title: "Don't have an account? | SIGNUP")
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
        navigationItem.title = "LOGIN"
        navigationController?.navigationBar.prefersLargeTitles = false

        passwordField.isSecureTextEntry = true
        emailField.keyboardType = .emailAddress
        emailField.textContentType = .username
        emailField.autocapitalizationType = .none
        emailField.accessibilityIdentifier = "login.email"
        passwordField.accessibilityIdentifier = "login.password"
        loginButton.accessibilityIdentifier = "login.submit"

        errorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        loginButton.addTarget(self, action: #selector(signIn), for: .touchUpInside)
        forgotButton.addTarget(self, action: #selector(showForgotPassword), for: .touchUpInside)
        signUpButton.addTarget(self, action: #selector(showRegistration), for: .touchUpInside)

        layout()
    }

    private func layout() {
        let heading = Theme.titleLabel("Expenses tracker")
        let hint = UILabel()
        hint.text = "Any email works. Passwords need six characters."
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabel
        hint.textAlignment = .center
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [
            heading, hint, emailField, passwordField, loginButton, errorLabel, spinner,
            forgotButton, signUpButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(24, after: hint)
        stack.setCustomSpacing(6, after: heading)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .interactive
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 40),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -28)
        ])
    }

    // MARK: - Actions

    @objc private func signIn() {
        errorLabel.text = nil

        let email = emailField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Android set an inline error on the field itself. UITextField has no equivalent, so the
        // message goes to a shared label — same information, same wording.
        guard !email.isEmpty else {
            errorLabel.text = "NAME REQUIRED...."
            return
        }
        guard !password.isEmpty else {
            errorLabel.text = "PASSWORD REQUIRED...."
            return
        }

        setBusy(true)
        NewRelic.recordBreadcrumb("login_attempted", attributes: ["screen": viewName.rawValue])

        Task {
            do {
                let user = try await auth.signIn(email: email, password: password)
                setBusy(false)
                showToast("LOGIN SUCCESSFUL")
                NewRelic.recordBreadcrumb("login_succeeded", attributes: ["uid": user.uid])
                flow.showHome()
            } catch {
                setBusy(false)
                errorLabel.text = error.localizedDescription
                ErrorReporter.reportHandled(error,
                                            source: "LoginViewController",
                                            additionalInfo: "sign-in rejected")
            }
        }
    }

    @objc private func showRegistration() {
        flow.showRegistration(from: self)
    }

    @objc private func showForgotPassword() {
        flow.showForgotPassword(from: self)
    }

    /// The Android ProgressDialog, which it showed with the message "PROCESSING....".
    private func setBusy(_ busy: Bool) {
        loginButton.isEnabled = !busy
        loginButton.configuration?.title = busy ? "PROCESSING...." : "LOG IN"
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }
}
