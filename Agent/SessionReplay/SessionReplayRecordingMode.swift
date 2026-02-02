//
//  SessionReplayRecordingMode.swift
//  Agent
//
//  Created by Chris Dillard on 12/4/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

/// Defines the recording mode for session replay
@available(iOS 13.0, *)
@objc public enum SessionReplayRecordingMode: Int {
    /// Error mode: Records frames in a 15-second circular buffer, waiting for an error to occur
    /// Upon error detection, transitions to full mode and includes the buffered frames
    case error = 0

    /// Full mode: Continuously records and uploads session replay data
    case full = 1

    /// Off mode: Session replay is completely disabled
    case off = 2
}
