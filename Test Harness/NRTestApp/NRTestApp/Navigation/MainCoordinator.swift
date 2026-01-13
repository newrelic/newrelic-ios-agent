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
#if os(iOS)

        let webViewController = ViewControllerProvider.textMaskingViewController
        navigationController.pushViewController(webViewController, animated: true)
        #endif
    }


   func showAttributedStringTextMaskingController() {
      let attributedStringTextMaskingViewController = ViewControllerProvider.attributedStringTextMaskingViewController
      navigationController.pushViewController(attributedStringTextMaskingViewController, animated: true)
   }

    func showCollectionController() {
        let collectionViewController = ViewControllerProvider.collectionViewController
        navigationController.pushViewController(collectionViewController, animated: true)
    }
    
    func showInfiniteScrollController() {
        let infiniteViewController = ViewControllerProvider.infiniteViewController
        navigationController.pushViewController(infiniteViewController, animated: true)
    }
    
    func showInfiniteImageScrollController() {
        let infiniteViewController = ViewControllerProvider.infiniteImageViewController
        navigationController.pushViewController(infiniteViewController, animated: true)
    }
    
    func showDiffTestController() {
        let diffTestViewController = ViewControllerProvider.diffTestViewController
        navigationController.pushViewController(diffTestViewController, animated: true)
    }
    
    func showPerformanceContentView() {
#if os(iOS)
        if #available(iOS 15.0, *) {
            if #available(iOS 17.0, *) {
                let swiftUIView = PerformanceContentView()
                let swiftUIViewController = UIHostingController(rootView: swiftUIView)
                navigationController.pushViewController(swiftUIViewController, animated: true)
                
            } else {
                // Fallback on earlier versions
            }
        }
#endif
    }

    func showConfidentialController() {
        let confidentialViewController = ViewControllerProvider.confidentialViewController
        navigationController.pushViewController(confidentialViewController, animated: true)
    }
    
    func showSwiftUITestView() {
#if os(iOS)
        if #available(iOS 15.0, *) {
            let swiftUIView = SwiftUIContentView()
            let swiftUIViewController = UIHostingController(rootView: swiftUIView)
            navigationController.pushViewController(swiftUIViewController, animated: true)
        }
#endif
    }
    
    func showSwiftUIViewRepresentableTestView() {
#if os(iOS)
        if #available(iOS 15.0, *) {
            let swiftUIView = SwiftUIViewRepresentableTestView()
            let swiftUIViewController = UIHostingController(rootView: swiftUIView)
            navigationController.pushViewController(swiftUIViewController, animated: true)
        }
#endif
    }
        
}
