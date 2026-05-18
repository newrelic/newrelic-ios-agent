//
//  TextHelper.swift
//  Agent
//
//  Created by Mike Bruin on 1/05/26.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit

/// Helper class for shared text rendering utilities used by UILabelThingy, UITextViewThingy, and CustomTextThingy
class TextHelper {

    /// Extracts font traits (weight and italic) from a UIFont
    /// - Parameter font: The UIFont to extract traits from
    /// - Returns: A tuple containing the font weight and italic boolean
    static func extractFontTraits(from font: UIFont) -> (weight: UIFont.Weight, isItalic: Bool) {
        let traits = font.fontDescriptor.symbolicTraits
        let isItalic = traits.contains(.traitItalic)

        // Extract font weight from font descriptor
        var fontWeight: UIFont.Weight = .regular

        // Check symbolic traits first for bold (more reliable for boldSystemFont)
        if traits.contains(.traitBold) {
            fontWeight = .bold
        }
        // Try to get weight from font descriptor traits dictionary
        else if let weightTrait = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
                  let weight = weightTrait[.weight] as? CGFloat {
            fontWeight = UIFont.Weight(rawValue: weight)
        }
        // Fallback: Try to get weight from font descriptor face attribute
        else if let face = font.fontDescriptor.object(forKey: .face) as? String {
            // Map common face names to weights
            let faceLower = face.lowercased()
            if faceLower.contains("ultralight") {
                fontWeight = .ultraLight
            } else if faceLower.contains("thin") {
                fontWeight = .thin
            } else if faceLower.contains("light") {
                fontWeight = .light
            } else if faceLower.contains("medium") {
                fontWeight = .medium
            } else if faceLower.contains("semibold") {
                fontWeight = .semibold
            } else if faceLower.contains("bold") {
                fontWeight = .bold
            } else if faceLower.contains("heavy") {
                fontWeight = .heavy
            } else if faceLower.contains("black") {
                fontWeight = .black
            }
        }

        return (fontWeight, isItalic)
    }

    /// Extracts label attributes from an NSAttributedString
    /// - Parameter attributedText: The attributed string to extract from
    /// - Returns: A tuple containing text, font, color, alignment, and line break mode
    static func extractLabelAttributes(from attributedText: NSAttributedString) -> (text: String?, font: UIFont, textColor: UIColor, textAlignment: String, lineBreakMode: NSLineBreakMode, kern: CGFloat?) {
        var text: String? = nil
        var font: UIFont = UIFont.systemFont(ofSize: 17.0)
        var textColor: UIColor = .black
        var textAlignment: String = "left"
        var lineBreakMode: NSLineBreakMode = .byWordWrapping
        var kern: CGFloat? = nil

        text = attributedText.string // Extract plain text
        if attributedText.length > 0 && !attributedText.string.isEmpty {
            // Get font from attributed string
            attributedText.enumerateAttributes(in: NSRange(location: 0, length: 1), options: []) { attributes, _, _ in
                if let attributedFont = attributes[.font] as? UIFont {
                    font = attributedFont
                }
                if let attributedColor = attributes[.foregroundColor] as? UIColor {
                    textColor = attributedColor
                }
                if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
                    textAlignment = paragraphStyle.alignment.stringValue()
                    lineBreakMode = paragraphStyle.lineBreakMode
                }
                kern = attributes[.kern] as? CGFloat
            }
        } else {
            // If attributed string is empty, set text to empty string and use defaults
            text = ""
        }

        return (text, font, textColor, textAlignment, lineBreakMode, kern)
    }

    /// Converts UIFont.Weight to CSS font-weight value (100-900)
    /// - Parameter weight: The UIFont.Weight to convert
    /// - Returns: CSS font-weight string value
    static func cssValueForFontWeight(_ weight: UIFont.Weight) -> String {
        // Map UIFont.Weight to CSS font-weight values
        switch weight.rawValue {
        case ...(-0.6): return "100" // ultraLight
        case -0.6 ..< -0.4: return "200" // thin
        case -0.4 ..< -0.2: return "300" // light
        case -0.2 ..< 0.2: return "400" // regular/normal
        case 0.2 ..< 0.3: return "500" // medium
        case 0.3 ..< 0.4: return "600" // semibold
        case 0.4 ..< 0.5: return "700" // bold
        case 0.5 ..< 0.7: return "800" // heavy
        default: return "900" // black
        }
    }

    /// Generates CSS for word wrapping behavior based on numberOfLines and lineBreakMode
    /// - Parameters:
    ///   - numberOfLines: Number of lines (0 = unlimited, 1 = single line, >1 = multiline with limit)
    ///   - lineBreakMode: The line break mode from UILabel/UITextView
    /// - Returns: CSS string for word wrapping behavior
    static func generateWordWrapCSS(numberOfLines: Int, lineBreakMode: NSLineBreakMode) -> String {
        var css = ""

        // Handle single line vs multiline
        if numberOfLines == 1 {
            css += "overflow: hidden; "

            // Handle line break mode for single line
            switch lineBreakMode {
            case .byTruncatingHead, .byTruncatingMiddle, .byTruncatingTail:
                css += "white-space: nowrap; text-overflow: ellipsis; "
            case .byClipping:
                css += "white-space: nowrap; text-overflow: clip; "
            case .byWordWrapping, .byCharWrapping:
                // Single line should not wrap
                css += "white-space: nowrap; text-overflow: clip; "
            @unknown default:
                css += "white-space: nowrap; text-overflow: clip; "
            }
        } else {
            // Multiline (numberOfLines == 0 or > 1)
            switch lineBreakMode {
            case .byWordWrapping:
                css += "white-space: pre-wrap; word-wrap: break-word; "
            case .byCharWrapping:
                css += "white-space: pre-wrap; word-break: break-all; "
            case .byClipping:
                css += "overflow: hidden; white-space: nowrap; "
            case .byTruncatingHead, .byTruncatingMiddle, .byTruncatingTail:
                // For multiline truncation, use word wrapping but add overflow handling
                css += "white-space: pre-wrap; word-wrap: break-word; overflow: hidden; "
                if numberOfLines > 1 {
                    // Use -webkit-line-clamp for limiting lines with ellipsis
                    css += "display: -webkit-box; -webkit-line-clamp: \(numberOfLines); -webkit-box-orient: vertical; text-overflow: ellipsis; "
                }
            @unknown default:
                css += "white-space: pre-wrap; word-wrap: break-word; "
            }
        }

        return css
    }
}
