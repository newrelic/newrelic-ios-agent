import SwiftUI
import NewRelic

struct NewRelicTestAppContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            FormView()
                .tabItem {
                    Label("Form", systemImage: "doc.text.fill")
                }
                .tag(1)

            ChartsView()
                .tabItem {
                    Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) { newValue in
            // Track tab changes with New Relic
            let tabNames = ["Dashboard", "Form", "Charts", "Settings"]
            NewRelic.recordCustomEvent("TabChanged",
                                      attributes: [
                                        "toTab": tabNames[newValue]
                                      ])
        }
        .onAppear {
            // Record app launch event
            NewRelic.recordCustomEvent("AppLaunched")
        }
    }
}
