import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            CardsView()
                .tabItem { Label("Cards", systemImage: "creditcard") }
            MessagesView()
                .tabItem { Label("Support", systemImage: "message") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
