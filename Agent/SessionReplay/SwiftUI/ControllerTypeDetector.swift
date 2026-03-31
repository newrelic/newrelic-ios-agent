//
//  ControllerTypeDetector.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

internal enum ControllerTypeDetector {
    case hostingController
    case navigationStackHostingController
    case modal
    case unknown

    init(from className: String) {
        typealias Rule = (predicate: (String) -> Bool, kind: ControllerTypeDetector)

        let rules: [Rule] = [
            ({ $0.hasPrefix("_TtGC7SwiftUI29PresentationHostingController") }, .modal),
            ({ $0.hasPrefix("_TtGC7SwiftUI") && $0.contains("HostingController") }, .hostingController),
            // UIKit UINavigationController or any remaining SwiftUI navigation-wrapper VC
            // whose class name did not match either rule above.
            ({ $0.contains("Navigation") }, .navigationStackHostingController),
        ]

        for rule in rules where rule.predicate(className) {
            self = rule.kind
            return
        }
        self = .unknown
    }
}
