//
//  SceneDelegate.swift
//  ExpensesTracker
//
//  Owns the window and hands the root off to AppFlow, which is where every screen transition the
//  Android app expressed as an Intent now lives.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var flow: AppFlow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let flow = AppFlow(window: window)
        self.window = window
        self.flow = flow

        flow.start()
        window.makeKeyAndVisible()
    }
}
