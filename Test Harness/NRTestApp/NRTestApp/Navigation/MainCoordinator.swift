//
//  MainCoordinator.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit
import SwiftUI

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
    
    func showImageViewController(image: UIImage) {
#if os(iOS)
        if #available(iOS 14.0, *) {
            let swiftUIImageView = ImageFullScreen(image: image)
            let imageViewController = UIHostingController(rootView: swiftUIImageView)
            navigationController.pushViewController(imageViewController, animated: true)
        }
#endif
    }
    
    func showUtilitiesViewController() {
        let utilitiesViewController = ViewControllerProvider.utilitiesViewController
        navigationController.pushViewController(utilitiesViewController, animated: true)
    }
    
    func showWebViewController() {
#if os(iOS)
        let webViewController = ViewControllerProvider.webViewController
        navigationController.pushViewController(webViewController, animated: true)
#endif
    }

    func showTextMaskingController() {
        let webViewController = ViewControllerProvider.textMaskingViewController
        navigationController.pushViewController(webViewController, animated: true)
    }
    
    func showCollectionController() {
        let collectionViewController = ViewControllerProvider.collectionViewController
        navigationController.pushViewController(collectionViewController, animated: true)
    }
}
