import Foundation

struct UserProfile {
    let fullName: String
    let ssn: String           // SENSITIVE
    let dateOfBirth: String    // SENSITIVE
    let address: String        // SENSITIVE
    let phone: String          // SENSITIVE
    let email: String          // SENSITIVE
}

struct Account {
    let nickname: String
    let accountNumberLast4: String  // SENSITIVE
    let balance: Decimal             // SENSITIVE
}

struct Transaction: Identifiable {
    let id = UUID()
    let merchant: String
    let category: String      // benign
    let amount: Decimal        // SENSITIVE
    let date: String
}

struct PaymentCard: Identifiable {
    let id = UUID()
    let brand: String          // benign
    let cardNumber: String     // SENSITIVE
    let cvv: String            // SENSITIVE
    let expiry: String         // SENSITIVE
    let cardholderName: String // SENSITIVE
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let fromUser: Bool
    let body: String           // SENSITIVE when fromUser (personal info)
    let timeLabel: String
}
