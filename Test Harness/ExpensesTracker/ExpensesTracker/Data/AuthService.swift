//
//  AuthService.swift
//  ExpensesTracker
//
//  Stands in for Firebase Auth.
//
//  The Android app used FirebaseAuth for sign-in, registration, and password reset. Bringing
//  firebase-ios-sdk into this repo's Test Harness to reproduce that would be a large third-party
//  dependency and a GoogleService-Info.plist in exchange for nothing the agent needs: what matters
//  here is that there are screens with credentials in them, that they validate and fail and succeed,
//  and that a user id reaches the agent. All of that is reproducible locally.
//
//  So: any well-formed email with a password of at least six characters signs in. Registration
//  remembers the account for the rest of the process's life, and rejects an email that is already
//  registered — the one Firebase behaviour the Android app had visible UI for
//  (`fetchSignInMethodsForEmail`). Password reset always succeeds after a short delay.
//
//  The artificial delay is not padding. Every one of these calls was asynchronous on Android, with a
//  ProgressDialog over the top, and the screens are written against that reality. Making them
//  instantaneous here would hide the loading states from anyone reading a session replay.
//

import Foundation
import NewRelic

struct AuthUser: Codable, Equatable {
    let uid: String
    let email: String
    var displayName: String
}

enum AuthError: LocalizedError {
    case invalidEmail
    case invalidPassword
    case emailAlreadyInUse
    case unknownUser

    var errorDescription: String? {
        switch self {
        case .invalidEmail:      return "INVALID EMAIL"
        case .invalidPassword:   return "INVALID PASSWORD"
        case .emailAlreadyInUse: return "Email already exists!"
        case .unknownUser:       return "No account for that email"
        }
    }
}

final class AuthService {

    static let shared = AuthService()

    private static let currentUserKey = "ExpensesTracker.currentUser"
    private let simulatedLatency: Duration = .milliseconds(600)

    /// Emails registered during this run, on top of whatever is already signed in. Firebase persisted
    /// these server-side; nothing here needs them to outlive the process.
    private var knownEmails: Set<String> = []

    private(set) var currentUser: AuthUser? {
        didSet { persistCurrentUser() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.currentUserKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            currentUser = user
        }
    }

    // MARK: - Sign in / out

    func signIn(email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(for: simulatedLatency)

        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.invalidPassword }

        let user = AuthUser(uid: Self.uid(for: email),
                            email: email,
                            displayName: Self.displayName(for: email))
        currentUser = user

        // Android set the user id once, at startup, from BuildConfig. Setting it again on sign-in is
        // the more useful behaviour: the id in the session then matches whoever actually signed in.
        NewRelic.setUserId(user.uid)
        NewRelic.logInfo("AuthService: sign-in succeeded for \(user.email)")

        return user
    }

    func signOut() {
        NewRelic.logInfo("AuthService: sign-out")
        currentUser = nil
        // A nil user id starts a new session, which is what a log-out should mean for reporting.
        NewRelic.setUserId(nil)
    }

    // MARK: - Registration

    func register(name: String, email: String, password: String) async throws -> AuthUser {
        try await Task.sleep(for: simulatedLatency)

        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.invalidPassword }
        guard !knownEmails.contains(email.lowercased()) else { throw AuthError.emailAlreadyInUse }

        knownEmails.insert(email.lowercased())

        let user = AuthUser(uid: Self.uid(for: email), email: email, displayName: name)
        currentUser = user

        NewRelic.setUserId(user.uid)
        NewRelic.logInfo("AuthService: registration succeeded for \(user.email)")

        return user
    }

    // MARK: - Password reset

    func sendPasswordReset(to email: String) async throws {
        try await Task.sleep(for: simulatedLatency)
        guard Self.isValidEmail(email) else { throw AuthError.invalidEmail }
        NewRelic.logInfo("AuthService: password reset requested for \(email)")
    }

    // MARK: - Helpers

    /// Deliberately loose: "something@something.something". Tightening it would only make the login
    /// screen harder to drive from a UI test.
    static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1].contains(".") && !parts[1].hasPrefix(".") && !parts[1].hasSuffix(".")
    }

    /// Stable per email, so signing in as the same address twice keeps the same uid — Firebase's
    /// behaviour, and it means the ledger on disk still belongs to you after a sign-out.
    ///
    /// Hashed by hand rather than with `hashValue`: Swift seeds its hasher per process, so
    /// `hashValue` would hand out a different uid on every launch and the ledger would appear to
    /// empty itself. FNV-1a is stable, and uniqueness across a handful of test accounts is all that
    /// is being asked of it.
    private static func uid(for email: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in email.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return "uid-" + String(format: "%016llx", hash)
    }

    private static func displayName(for email: String) -> String {
        String(email.split(separator: "@").first ?? "User").capitalized
    }

    private func persistCurrentUser() {
        let defaults = UserDefaults.standard
        guard let currentUser, let data = try? JSONEncoder().encode(currentUser) else {
            defaults.removeObject(forKey: Self.currentUserKey)
            return
        }
        defaults.set(data, forKey: Self.currentUserKey)
    }
}
