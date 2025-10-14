//
//  StyledTextSwiftUIView.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI

internal struct StyledTextSwiftUIView: XrayConvertible {
    let text: SwiftUIStyledTextRes.StringDrawing

    // Store original subject for deep reflection (accessibility identifiers, etc.)
    let originalSubject: Any

    init(xray: XrayDecoder) throws {
        text = try xray.extract(SwiftUIConstants.textPath)
        originalSubject = xray.runTimeTypeInspector.subject
    }
}
