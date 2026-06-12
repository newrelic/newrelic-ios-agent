import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var cards: [PaymentCard] = SeedData.cards
    @Published var messages: [ChatMessage] = SeedData.messages

    let profile = SeedData.profile
    let account = SeedData.account
    let transactions = SeedData.transactions

    func logIn() { isAuthenticated = true }
    func logOut() { isAuthenticated = false }
}
