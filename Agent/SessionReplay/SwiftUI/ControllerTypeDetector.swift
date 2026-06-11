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
            // SwiftUI NavigationStack destination hosting controllers satisfy BOTH the Navigation
            // and HostingController predicates. This rule must precede the generic hosting
            // controller rule so they are not incorrectly classified as plain .hostingController,
            // which would prevent navigationStackDepth from incrementing on push/pop.
            ({ $0.hasPrefix("_TtGC7SwiftUI") && $0.contains("Navigation") && $0.contains("HostingController") }, .navigationStackHostingController),
            ({ $0.hasPrefix("_TtGC7SwiftUI") && $0.contains("HostingController") }, .hostingController),
            // Catch-all for UIKit UINavigationController whose class name did not match above.
            ({ $0.contains("Navigation") }, .navigationStackHostingController),
        ]

        for rule in rules where rule.predicate(className) {
            self = rule.kind
            return
        }
        self = .unknown
    }
}
