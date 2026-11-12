//
//  AppFlow.swift
//  ExpensesTracker
//
//  Every screen transition the Android app expressed as `startActivity(new Intent(…))`.
//
//  Collecting them here rather than letting each screen construct the next one keeps the graph
//  readable, and matters more than usual for this app: the transitions are what the MobileViews
//  feature reports on, so "what can follow what" should be answerable without reading five view
//  controllers. It also removes the Android version's habit of navigating to MainActivity to mean
//  "log out", which produced a stack that grew every time.
//

import UIKit

@MainActor
final class AppFlow {

    private let window: UIWindow
    private let auth: AuthService
    private let store: LedgerStore

    init(window: UIWindow,
         auth: AuthService = .shared,
         store: LedgerStore = .shared) {
        self.window = window
        self.auth = auth
        self.store = store
    }

    /// Splash first, as on Android, where SpalashScreen held the LAUNCHER intent filter.
    func start() {
        let splash = SplashViewController { [weak self] in
            self?.showAfterSplash()
        }
        window.rootViewController = splash
    }

    /// Android checked `logauth.getCurrentUser() != null` in MainActivity and skipped straight to
    /// HomeActivity. AuthService keeps a signed-in user across launches for the same reason.
    private func showAfterSplash() {
        if auth.currentUser != nil {
            showHome()
        } else {
            showLogin()
        }
    }

    // MARK: - Auth

    func showLogin() {
        let login = LoginViewController(auth: auth, flow: self)
        setRoot(UINavigationController(rootViewController: login))
    }

    func showRegistration(from presenter: UIViewController) {
        presenter.navigationController?.pushViewController(
            RegistrationViewController(auth: auth, flow: self),
            animated: true
        )
    }

    func showForgotPassword(from presenter: UIViewController) {
        presenter.navigationController?.pushViewController(
            ForgotPasswordViewController(auth: auth),
            animated: true
        )
    }

    // MARK: - Home

    /// Wrapped in a navigation controller for the bar HomeActivity got from its Toolbar — the bar carries
    /// the title, the drawer button, and the two options-menu items.
    func showHome() {
        Task { await store.loadIfNeeded() }

        let home = HomeViewController(store: store, flow: self)
        setRoot(UINavigationController(rootViewController: home))
    }

    func signOut() {
        auth.signOut()
        showLogin()
    }

    // MARK: - The SwiftUI section

    /// Android reached its Compose screens through a toolbar menu item that launched a separate
    /// Activity. Here it is a modal UIHostingController, which is the same idea — a self-contained
    /// UI stack with its own navigation — while keeping one window.
    func showSwiftUISection(from presenter: UIViewController) {
        let host = SwiftUISectionHost.makeViewController()
        host.modalPresentationStyle = .fullScreen
        presenter.present(host, animated: true)
    }

    // MARK: - Root swapping

    private func setRoot(_ viewController: UIViewController) {
        window.rootViewController = viewController
    }
}
