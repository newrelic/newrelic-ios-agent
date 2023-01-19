//
//  MainCoordinator.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit

// Using the coordinator pattern for navigation
class MainCoordinator: Coordinator {
    var navigationController: UINavigationController

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }

    // Called at the start of the application
    func start() {
        let vc = ViewControllerProvider.viewController
        vc.coordinator = self
        
        navigationController.pushViewController(vc, animated: false)
    }
    
    func showUtilitiesViewController() {
        let utilitiesViewController = ViewControllerProvider.utilitiesViewController
        navigationController.pushViewController(utilitiesViewController, animated: true)
    }
#if os(iOS)
    func showWebViewController() {
        let webViewController = ViewControllerProvider.webViewController
        navigationController.pushViewController(webViewController, animated: true)
    }
#endif
}
