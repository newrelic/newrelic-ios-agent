//
//  Coordinator.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit

// Define what a coordinator must include
protocol Coordinator {
    var navigationController: UINavigationController { get set }

    func start()
}
