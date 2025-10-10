//
//  NRMaskedViewRepresentable.swift
//  Agent
//
//  Created by Chris Dillard on 10/10/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 16, *)
struct NRMaskedViewRepresentable<Content: View>: UIViewControllerRepresentable {

    let maskApplicationText: Bool
    let maskUserInputText: Bool
    let maskAllImages: Bool
    let maskAllUserTouches: Bool
    
    let activated: Bool

    let sessionReplayIdentifier: Int?
    
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIHostingController<MaskedContainerView<Content>> {
        // create forwarded env
        let hostVC = UIHostingController(rootView: MaskedContainerView(context.environment,
                                                                                  inputContent: content))
        hostVC.view.clipsToBounds = false

        hostVC.sizingOptions =
            UIHostingControllerSizingOptions.intrinsicContentSize

        hostVC.view.backgroundColor =
            UIColor.clear

        return hostVC
    }

    func updateUIViewController(_ hostVC: UIHostingController<MaskedContainerView<Content>>, context: Context) {

        //env forwarding

        hostVC.rootView = MaskedContainerView(context.environment,
                                                         inputContent: content)
        
        // Handle association w/ host `UIView`
        hostVC.view.maskApplicationText = maskApplicationText
        hostVC.view.maskUserInputText = maskUserInputText
        hostVC.view.maskAllImages = maskAllImages
        hostVC.view.maskAllUserTouches = maskAllUserTouches
        hostVC.view.sessionReplayIdentifier = sessionReplayIdentifier
        
        //env forwarding    

        hostVC.rootView = MaskedContainerView(context.environment,
                                                         inputContent: content)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<MaskedContainerView<Content>>, context: Context) -> CGSize? {
        let preferredSize = CGSize(width: CGFloat.infinity, height: .infinity)
        let proposedSize = proposal.replacingUnspecifiedDimensions(by: preferredSize)
        return uiViewController.sizeThatFits(in: proposedSize)
    }
}
