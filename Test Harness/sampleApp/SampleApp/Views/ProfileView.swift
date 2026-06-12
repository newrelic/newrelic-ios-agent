import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Personal information") {
                    labeled("Full name", appState.profile.fullName)
                    labeled("SSN", appState.profile.ssn)
                    labeled("Date of birth", appState.profile.dateOfBirth)
                    labeled("Address", appState.profile.address)
                    labeled("Phone", appState.profile.phone)
                    labeled("Email", appState.profile.email)
                }
                Section {
                    Button("Edit") {}
                    Button("Sign out", role: .destructive) { appState.logOut() }
                }
                Section {
                    Text("App version 1.0.0").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}
