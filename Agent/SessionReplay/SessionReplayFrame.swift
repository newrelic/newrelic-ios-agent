//
//  NRMASessionReplayFrame.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

struct SessionReplayFrame {
    let date: Date
    let views: any SessionReplayViewThingy
    let rootViewControllerId: String?
    let rootSwiftUIViewId: Int?
    let size: CGSize
    let layoutContainerViewCount: Int
}
