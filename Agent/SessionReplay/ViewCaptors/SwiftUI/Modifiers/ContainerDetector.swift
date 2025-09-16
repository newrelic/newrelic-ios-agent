//
//  ContainerDetector.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 14.0, *)
public struct ContainerDetector {

    public static func isContainer(_ kind: ClassifiedKind) -> Bool {
        switch kind {
        case .other(let name):
            return isContainerByName(name)
        case .list, .scrollView:
            return true
        default:
            // Leaf views like Text, Button, TextField, etc., are not containers
            return false
        }
    }

    private static func isContainerByName(_ name: String) -> Bool {
        // Layout containers
        let layoutContainers = [
            "VStack", "HStack", "ZStack",
            "LazyVStack", "LazyHStack",
            "LazyVGrid", "LazyHGrid"
        ]

        // Collection containers
        let collectionContainers = [
            "List", "ScrollView", "Form",
            "GroupBox", "DisclosureGroup"
        ]

        // Navigation containers
        let navigationContainers = [
            "NavigationView", "NavigationStack",
            "TabView", "PageTabViewStyle"
        ]

        // Conditional containers
        let conditionalContainers = [
            "_ConditionalContent", "_OptionalContent",
            "Group", "Section"
        ]

        // Data-driven containers
        let dataDrivenContainers = [
            "ForEach", "_VariadicView",
            "TupleView"
        ]

        // Modifier containers (these wrap other views)
        let modifierContainers = [
            "ModifiedContent",
            "_BackgroundModifier", "_OverlayModifier",
            "_PaddingLayout", "_FrameLayout",
            "_FlexFrameLayout", "_FixedSizeLayout"
        ]

        // Wrapper containers
        let wrapperContainers = [
            "AnyView", "_AnyViewStorage",
            "_ConditionalContent", "EmptyView"
        ]

        let allContainerTypes = layoutContainers + collectionContainers +
                               navigationContainers + conditionalContainers +
                               dataDrivenContainers + modifierContainers +
                               wrapperContainers

        let isContainer = allContainerTypes.contains { containerType in
            name.contains(containerType)
        }

//        if isContainer {
//            print("[ContainerDetector] '\(name)' detected as CONTAINER")
//        } else {
//            print("[ContainerDetector] '\(name)' detected as LEAF")
//        }

        return isContainer
    }

    // Special method for detecting containers that shouldn't create their own view nodes
    // but should pass through to their children (like ModifiedContent)
    public static func isPassThroughContainer(_ name: String) -> Bool {
        let passThroughTypes = [
            "ModifiedContent",
            "_ConditionalContent",
            "Group",
            "_OptionalContent",
            "AnyView"
        ]

        return passThroughTypes.contains { name.contains($0) }
    }
}
