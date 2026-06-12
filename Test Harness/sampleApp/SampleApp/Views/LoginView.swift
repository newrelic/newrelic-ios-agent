import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Northwind Bank")
                .font(.largeTitle.bold())
            Text("Sign in to your account")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if showError {
                Text("Invalid credentials")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button("Sign In") {
                if TestCredentials.validate(username, password) {
                    appState.logIn()
                } else {
                    showError = true
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Forgot password?") {}
                .font(.footnote)

            Text("Test login — demo / demo123")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
    }
}
