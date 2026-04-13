//
//  NRMaskedViewRepresentable.swift
//  Agent
//
//  Created by Chris Dillard on 10/10/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

struct NRMaskedViewRepresentable<Content: View>: UIViewControllerRepresentable {

    let maskApplicationText: Bool?
    let maskUserInputText: Bool?
    let maskAllImages: Bool?
    let maskAllUserTouches: Bool?
    let blockView: Bool?

    let activated: Bool

    let sessionReplayIdentifier: String?
    
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<MaskedContainerView<Content>> {
        // create forwarded env
        let hostVC = UIHostingController(rootView: MaskedContainerView(context.environment,
                                                                                  inputContent: content))
        hostVC.view.clipsToBounds = false

        if #available(iOS 16.0, *) {
            hostVC.sizingOptions =
                UIHostingControllerSizingOptions.intrinsicContentSize

        }

        hostVC.view.backgroundColor =
            UIColor.clear

        return hostVC
    }

    func updateUIViewController(_ hostVC: UIHostingController<MaskedContainerView<Content>>, context: Context) {

        //env forwarding

        hostVC.rootView = MaskedContainerView(context.environment,
                                                         inputContent: content)

//        // Approach 5: diff masking properties — only notify when something actually changed,
//        // not on every parent re-render that happens to re-invoke this representable.
//        if #available(iOS 17.0, *) {
////            let maskingChanged = hostVC.view.maskApplicationText != maskApplicationText
////                || hostVC.view.maskUserInputText != maskUserInputText
////                || hostVC.view.maskAllImages != maskAllImages
////                || hostVC.view.maskAllUserTouches != maskAllUserTouches
////                || hostVC.view.blockView != blockView
////                || hostVC.view.swiftUISessionReplayIdentifier != sessionReplayIdentifier
////            if maskingChanged {
//                NRMaskingChangeObservable.shared.notifyChange()
// //           }
//        }

        // Handle association w/ host `UIView`
        hostVC.view.maskApplicationText = maskApplicationText
        hostVC.view.maskUserInputText = maskUserInputText
        hostVC.view.maskAllImages = maskAllImages
        hostVC.view.maskAllUserTouches = maskAllUserTouches
        hostVC.view.blockView = blockView
        hostVC.view.swiftUISessionReplayIdentifier = sessionReplayIdentifier
    }

    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<MaskedContainerView<Content>>, context: Context) -> CGSize? {
        let preferredSize = CGSize(width: CGFloat.infinity, height: .infinity)
        let proposedSize = proposal.replacingUnspecifiedDimensions(by: preferredSize)
        return uiViewController.sizeThatFits(in: proposedSize)
    }
}
