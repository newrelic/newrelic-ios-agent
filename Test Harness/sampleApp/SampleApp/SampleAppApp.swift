import SwiftUI
import NewRelic

@main
struct SampleAppApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // TODO: Replace with a real New Relic mobile application token, and enable
        // Session Replay for this app in the New Relic UI. Masking is wired below
        // via NRConditionalMaskView regardless, but no replay is captured until then.
        NewRelic.start(withApplicationToken: "NR_APP_TOKEN_PLACEHOLDER")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    RootTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
        }
    }
}
