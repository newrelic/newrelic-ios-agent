//
//  UITabButtonThingy.swift
//  Agent
//
//  Created by Mike Bruin on 3/20/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import UIKit

class UITabButtonThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var isBlocked: Bool

    var subviews = [any SessionReplayViewThingy]()

    var shouldRecordSubviews: Bool {
        true
    }

    var viewDetails: ViewDetails
    private let isSelected: Bool

    init(view: UIView, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isMasked = viewDetails.isMasked ?? false
        self.isBlocked = viewDetails.blockView ?? false

        // Detect if this tab button is selected by checking if it's in SelectedContentView
        var isInSelectedContent = false
        var currentView = view.superview
        while currentView != nil {
            let className = NSStringFromClass(type(of: currentView!))
            if className.contains("SelectedContentView") {
                isInSelectedContent = true
                break
            }
            // Stop at UITabBar level to avoid going too far up
            if className.contains("UITabBar") {
                break
            }
            currentView = currentView?.superview
        }

        // Also check if the view itself has isSelected property (UIControl subclasses)
        if let control = view as? UIControl {
            self.isSelected = control.isSelected || isInSelectedContent
        } else {
            self.isSelected = isInSelectedContent
        }
    }

    func cssDescription() -> String {
        return "#\(viewDetails.cssSelector) {\(generateBaseCSSStyle())} "
    }

    func generateRRWebNode() -> ElementNodeData {
        let node = ElementNodeData(id: viewDetails.viewId,
                                   tagName: .div,
                                   attributes: ["id": viewDetails.cssSelector],
                                   childNodes: [])

        // Add selected state as a CSS class if needed
        if isSelected {
            node.attributes["class"] = "selected-tab"
        }

        return node
    }

    func generateSelectedStyle() -> String {
        var style = generateBaseCSSStyle()

        // Add a subtle background to indicate selection
        if isSelected {
            style.append(" background-color: rgba(0, 0, 0, 0.05);")
        }

        return style
    }

    func generateRRWebAdditionNode(parentNodeId: Int) -> [RRWebMutationData.AddRecord] {
        let node = generateRRWebNode()
        node.attributes["style"] = generateSelectedStyle()
        let addNode: RRWebMutationData.AddRecord = .init(parentId: parentNodeId, nextId: viewDetails.nextId, node: .element(node))

        return [addNode]
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UITabButtonThingy else {
            return []
        }
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()

        allAttributes["style"] = typedOther.generateSelectedStyle()

        // Update selection class if it changed
        if self.isSelected != typedOther.isSelected {
            if typedOther.isSelected {
                allAttributes["class"] = "selected-tab"
            } else {
                allAttributes["class"] = ""
            }
        }

        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }

        return mutations
    }
}

extension UITabButtonThingy: Equatable {
    static func == (lhs: UITabButtonThingy, rhs: UITabButtonThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails && lhs.isSelected == rhs.isSelected
    }
}

extension UITabButtonThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
        hasher.combine(isSelected)
    }
}
