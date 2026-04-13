//
//  NRTestApp.swift
//  NRTestApp
//

import SwiftUI
import NewRelic

@main
struct NRTestApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainCoordinatorView()
                .ignoresSafeArea()
        }
        .onChange(of: scenePhase) { newScenePhase in
            switch newScenePhase {
            case .active:
                NewRelic.logVerbose("scenePhase: active")
            case .inactive:
                NewRelic.logVerbose("scenePhase: inactive")
            case .background:
                NewRelic.logVerbose("scenePhase: background")
            @unknown default:
                NewRelic.logVerbose("scenePhase '\(newScenePhase)' unknown")
            }
        }
    }
}

// Bridges the existing UIKit coordinator into the SwiftUI WindowGroup.
private struct MainCoordinatorView: UIViewControllerRepresentable {
    // Holds a strong reference to MainCoordinator so its weak refs in child VCs stay alive.
    class Coordinator {
        var appCoordinator: MainCoordinator?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UINavigationController {
        let navigationController = UINavigationController()
        navigationController.navigationBar.prefersLargeTitles = true
        let appCoordinator = MainCoordinator(navigationController: navigationController)
        context.coordinator.appCoordinator = appCoordinator
        appCoordinator.start()
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
