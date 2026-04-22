//
//  UIDatePickerThingy.swift
//  Agent_iOS
//
//  Created by Mike Bruin on 3/16/26.
//  Copyright © 2026 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

#if os(iOS)
class UIDatePickerThingy: SessionReplayViewThingy {
    var isMasked: Bool
    var isBlocked: Bool
    var subviews = [any SessionReplayViewThingy]()

    var shouldRecordSubviews: Bool {
        true
    }

    var viewDetails: ViewDetails

    init(view: UIDatePicker, viewDetails: ViewDetails) {
        self.viewDetails = viewDetails
        self.isBlocked = viewDetails.blockView ?? false

        // Date picker values are user input - respect maskUserInputText
        if let isMasked = viewDetails.isMasked {
            self.isMasked = isMasked
        } else if let maskUserInputText = viewDetails.maskUserInputText {
            self.isMasked = maskUserInputText
        } else {
            self.isMasked = NRMAHarvestController.configuration()?.session_replay_maskUserInputText ?? true
        }

        // Mark this view and all descendants to skip aggressive clipping
        self.markViewHierarchyToSkipClipping(view)
    }

    private func markViewHierarchyToSkipClipping(_ view: UIView) {
        view.skipAggressiveClipping = true
        for subview in view.subviews {
            markViewHierarchyToSkipClipping(subview)
        }
    }

    func generateRRWebNode() -> ElementNodeData {
        return ElementNodeData(
            id: viewDetails.viewId,
            tagName: .div,
            attributes: [
                "id": viewDetails.cssSelector,
                "style": inlineCSSDescription()
            ],
            childNodes: []
        )
    }

    func generateDifference<T: SessionReplayViewThingy>(from other: T) -> [MutationRecord] {
        guard let typedOther = other as? UIDatePickerThingy else { return [] }
        var mutations = [MutationRecord]()
        var allAttributes = [String: String]()

        allAttributes["style"] = typedOther.generateBaseCSSStyle()

        if !allAttributes.isEmpty {
            let attributeRecord = RRWebMutationData.AttributeRecord(id: viewDetails.viewId, attributes: allAttributes)
            mutations.append(attributeRecord)
        }

        return mutations
    }
}

extension UIDatePickerThingy: Equatable {
    static func == (lhs: UIDatePickerThingy, rhs: UIDatePickerThingy) -> Bool {
        return lhs.viewDetails == rhs.viewDetails
    }
}

extension UIDatePickerThingy: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewDetails)
    }
}
#endif
