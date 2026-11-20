//
//  NRMASessionReplayFrame.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/30/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)

struct SessionReplayFrame {
    let date: Date
    let views: any SessionReplayViewThingy
    let rootViewControllerId: String?
    let rootSwiftUIViewId: Int?
    let size: CGSize
    let layoutContainerViewCount: Int
    /// Number of NavigationStack destination hosting views visible in this frame.
    /// Increments by 1 for each pushed destination; 0 means the stack is at its root.
    /// A change in this value (push or pop) triggers an immediate full snapshot.
    let navigationStackDepth: Int
    /// Replay ids of the top view controllers' views of the UINavigationControllers in this
    /// frame, outermost first. A change (push, pop, or setViewControllers) requests a full
    /// snapshot once no navigation transition is in progress.
    var navigationTopViewIds: [Int] = []
    /// Whether one of those navigation controllers is mid-transition, including an
    /// interactive pop.
    var isNavigationTransitionInProgress = false
}
#endif
