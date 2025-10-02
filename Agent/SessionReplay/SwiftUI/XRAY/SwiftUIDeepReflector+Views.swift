//
//  SwiftUIDeepReflector+Views.swift
//  Agent
//
//  Created by Chris Dillard on 10/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

extension SwiftUIDeepReflector {

// MARK: - Integration with ViewDetails

/// Extracts accessibility info suitable for ViewDetails/masking logic
/// - Parameter view: SwiftUI view (as Any)
/// - Returns: Tuple of (identifier, shouldMask)
public static func extractViewDetailsInfo(from view: Any) -> (identifier: String?, shouldMask: Bool?) {
  guard let accessibilityInfo = extractAccessibilityInfo(from: view) else {
      return (nil, nil)
  }

  let identifier = accessibilityInfo.identifier
  let shouldMask = extractMaskingPreference(from: view)

  return (identifier, shouldMask)
}

// MARK: - Integration with XrayDecoder

/// Enhances XrayDecoder with deep reflection accessibility extraction
public static func enhanceAttributes(
  _ attributes: inout SwiftUIViewAttributes,
  from xrayDecoder: XrayDecoder,
  accessibilityInfo: AccessibilityInfo?
) {
  // Extract masking preference if we have an identifier
  if let info = accessibilityInfo, info.hasIdentifier {
      if let identifier = info.identifier {
          if identifier == "nr-mask" || identifier.hasSuffix(".nr-mask") {
              attributes.hide = true
          } else if identifier == "nr-unmask" || identifier.hasSuffix(".nr-unmask") {
              attributes.hide = false
          }
      }
  }
}

// MARK: - Batch Processing

/// Process multiple views from a display list or view hierarchy
/// - Parameter views: Array of view subjects to process
/// - Returns: Dictionary mapping view index to accessibility info
public static func batchExtractAccessibility(
  from views: [Any]
) -> [Int: AccessibilityInfo] {
  var results: [Int: AccessibilityInfo] = [:]

  for (index, view) in views.enumerated() {
      if let info = extractAccessibilityInfo(from: view) {
          results[index] = info
      }
  }

  return results
}
}
