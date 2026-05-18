import SwiftUI
import NewRelic

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showResetAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App Settings")) {
                    Toggle("Dark Mode", isOn: $viewModel.darkModeEnabled)
                        .onChange(of: viewModel.darkModeEnabled) { newValue in
                            NewRelic.recordCustomEvent("DarkModeToggled",
                                                      attributes: ["enabled": newValue])
                        }

                    Toggle("Push Notifications", isOn: $viewModel.pushNotificationsEnabled)
                        .onChange(of: viewModel.pushNotificationsEnabled) { newValue in
                            NewRelic.recordCustomEvent("PushNotificationsToggled",
                                                      attributes: ["enabled": newValue])
                        }

                    Toggle("Location Services", isOn: $viewModel.locationEnabled)
                }

                Section(header: Text("Data & Privacy")) {
                    Toggle("Analytics", isOn: $viewModel.analyticsEnabled)
                        .onChange(of: viewModel.analyticsEnabled) { newValue in
                            NewRelic.setAttribute("analyticsEnabled", value: newValue)
                        }

                    Toggle("Crash Reporting", isOn: $viewModel.crashReportingEnabled)

                    Button {
                        clearCache()
                    } label: {
                        HStack {
                            Text("Clear Cache")
                            Spacer()
                            Text("\(viewModel.cacheSize) MB")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Performance")) {
                    Picker("Refresh Rate", selection: $viewModel.refreshRate) {
                        Text("Every 5 seconds").tag(5)
                        Text("Every 15 seconds").tag(15)
                        Text("Every 30 seconds").tag(30)
                        Text("Every minute").tag(60)
                    }

                    Toggle("Offline Mode", isOn: $viewModel.offlineMode)
                        .onChange(of: viewModel.offlineMode) { newValue in
                            NewRelic.setAttribute("offlineMode", value: newValue)
                        }

                    Stepper("Max Concurrent Tasks: \(viewModel.maxConcurrentTasks)",
                           value: $viewModel.maxConcurrentTasks,
                           in: 1...10)
                }

                Section(header: Text("Network")) {
                    Button("Test Network Request") {
                        testNetworkRequest()
                    }

                    Button("Trigger Background Task") {
                        triggerBackgroundTask()
                    }

                    Button("Simulate Error") {
                        simulateError()
                    }
                    .foregroundColor(.red)
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.02.19.1")
                            .foregroundColor(.secondary)
                    }

                    Button("Reset All Settings") {
                        showResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    viewModel.resetSettings()
                    NewRelic.recordCustomEvent("SettingsReset")
                }
            } message: {
                Text("Are you sure you want to reset all settings to default?")
            }
            .onAppear {
                NewRelic.recordBreadcrumb("SettingsView appeared")
            }
        }
    }

    private func clearCache() {
        let interactionId = NewRelic.startInteraction(withName: "ClearCache")

        let originalSize = viewModel.cacheSize
        viewModel.cacheSize = 0

        NewRelic.recordCustomEvent("CacheCleared",
                                  attributes: ["previousSize": originalSize])
        NewRelic.stopCurrentInteraction(interactionId)
    }

    private func testNetworkRequest() {
        let interactionId = NewRelic.startInteraction(withName: "TestNetworkRequest")

//        NetworkService.shared.fetchData { result in
//            switch result {
//            case .success(let data):
//                NewRelic.recordCustomEvent("NetworkRequestSuccess",
//                                          attributes: ["dataSize": data.count])
//            case .failure(let error):
//                NewRelic.recordCustomEvent("NetworkRequestFailure",
//                                          attributes: ["error": error.localizedDescription])
//                NewRelic.recordError(error)
//            }
//            NewRelic.stopCurrentInteraction(interactionId)
//        }
    }

    private func triggerBackgroundTask() {
        let interactionId = NewRelic.startInteraction(withName: "BackgroundTask")

        NewRelic.recordCustomEvent("BackgroundTaskStarted")

        DispatchQueue.global(qos: .background).async {
            Thread.sleep(forTimeInterval: 2)

            let result = (0..<1000000).reduce(0, +)

            DispatchQueue.main.async {
                NewRelic.recordCustomEvent("BackgroundTaskCompleted",
                                          attributes: ["result": result])
                NewRelic.stopCurrentInteraction(interactionId)
            }
        }
    }

    private func simulateError() {
        let errors = [
            NSError(domain: "com.app.network", code: 500, userInfo: [NSLocalizedDescriptionKey: "Internal Server Error"]),
            NSError(domain: "com.app.database", code: 404, userInfo: [NSLocalizedDescriptionKey: "Record Not Found"]),
            NSError(domain: "com.app.validation", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Input"]),
            NSError(domain: "com.app.authentication", code: 401, userInfo: [NSLocalizedDescriptionKey: "Unauthorized Access"])
        ]

        let randomError = errors.randomElement()!
        NewRelic.recordError(randomError)
        NewRelic.recordCustomEvent("ErrorSimulated",
                                  attributes: [
                                    "errorDomain": randomError.domain,
                                    "errorCode": randomError.code,
                                    "errorDescription": randomError.localizedDescription
                                  ])
    }
}

class SettingsViewModel: ObservableObject {
    @Published var darkModeEnabled = false
    @Published var pushNotificationsEnabled = true
    @Published var locationEnabled = true
    @Published var analyticsEnabled = true
    @Published var crashReportingEnabled = true
    @Published var cacheSize = 42
    @Published var refreshRate = 15
    @Published var offlineMode = false
    @Published var maxConcurrentTasks = 5

    func resetSettings() {
        darkModeEnabled = false
        pushNotificationsEnabled = true
        locationEnabled = true
        analyticsEnabled = true
        crashReportingEnabled = true
        cacheSize = 42
        refreshRate = 15
        offlineMode = false
        maxConcurrentTasks = 5
    }
}

#Preview {
    SettingsView()
}
