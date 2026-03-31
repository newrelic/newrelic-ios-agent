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
            // Gap 2: modal must be checked before the broad HostingController rule below,
            // since PresentationHostingController also contains "HostingController".
            ({ $0.hasPrefix("_TtGC7SwiftUI29PresentationHostingController") }, .modal),
            // Gap 2: broaden from the exact "19UIHostingController" prefix so that
            // NavigationStack pushed-destination VCs (e.g. NavigationDestinationHostingController)
            // are classified as .hostingController rather than falling through to
            // .navigationStackHostingController and being silently skipped.
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
