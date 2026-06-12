import Foundation

enum SeedData {
    static let profile = UserProfile(
        fullName: "Jordan Avery Lee",
        ssn: "123-45-6789",
        dateOfBirth: "1990-04-15",
        address: "742 Evergreen Terrace, Springfield, IL 62704",
        phone: "(555) 010-7788",
        email: "jordan.lee@example.com"
    )

    static let account = Account(
        nickname: "Everyday Checking",
        accountNumberLast4: "4821",
        balance: Decimal(string: "8423.57")!
    )

    static let transactions: [Transaction] = [
        .init(merchant: "Blue Bottle Coffee", category: "Dining", amount: Decimal(string: "6.75")!, date: "Jun 11"),
        .init(merchant: "Whole Foods Market", category: "Groceries", amount: Decimal(string: "84.20")!, date: "Jun 10"),
        .init(merchant: "Shell", category: "Gas", amount: Decimal(string: "52.10")!, date: "Jun 9"),
        .init(merchant: "Netflix", category: "Entertainment", amount: Decimal(string: "15.49")!, date: "Jun 8")
    ]

    static let cards: [PaymentCard] = [
        .init(brand: "Visa", cardNumber: "4111 1111 1111 1111", cvv: "123", expiry: "08/27", cardholderName: "Jordan A Lee"),
        .init(brand: "Mastercard", cardNumber: "5555 5555 5555 4444", cvv: "456", expiry: "11/26", cardholderName: "Jordan A Lee")
    ]

    static let messages: [ChatMessage] = [
        .init(fromUser: false, body: "Hi! You're chatting with Sam from Support. How can I help?", timeLabel: "9:41 AM"),
        .init(fromUser: true, body: "My card ending 1111 was charged twice for $84.20 at Whole Foods.", timeLabel: "9:42 AM"),
        .init(fromUser: false, body: "I'm sorry about that — let me take a look.", timeLabel: "9:42 AM"),
        .init(fromUser: true, body: "Thanks. My SSN is 123-45-6789 if you need to verify me.", timeLabel: "9:43 AM")
    ]
}
