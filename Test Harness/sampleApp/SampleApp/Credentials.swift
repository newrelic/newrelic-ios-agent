import Foundation

enum TestCredentials {
    static let username = "demo"
    static let password = "demo123"

    static func validate(_ user: String, _ pass: String) -> Bool {
        user == username && pass == password
    }
}
