//
//  ViewControllerProvider.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit

enum ViewControllerProvider {
    // Provides an AllCatsViewController
    static var viewController: ViewController {
        let viewController = ViewController()
        viewController.viewModel = ApodViewModel()
        return viewController
    }
    
    static var utilitiesViewController: UtilitiesViewController {
        let viewController = UtilitiesViewController()
        return viewController
    }
#if os(iOS)
    static var webViewController : WebViewController {
        let viewController = WebViewController()
        return viewController
    }
#endif

    static var textMaskingViewController: TextMaskingViewController {
        let viewController = TextMaskingViewController()
        return viewController
    }
    
    static var collectionViewController: ScrollableCollectionViewController {
        let viewController = ScrollableCollectionViewController()
        return viewController
    }
}

