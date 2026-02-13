//
//  MUIToken.swift
//  xc
//
//  Created by Jose Fernandes on 2026-02-11.
//

import Foundation
import SwiftUI
import UIKit

/// Provide semantic values for common ui elements.
public struct MUIToken {

    public struct CornerRadius {
        public static let sm: CGFloat = 8
    }

    /// *Design*  was extracted from FIGMA do not change, another extraction will be required
    public struct Design {

        public static var pageContainerInverse: Color {
            Color(UIColor(neutral950)) // Same for both light and dark
        }

        public static var pageContainerSurface: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral950) : UIColor(neutralWhite)
            })
        }

        public static var pageBorderDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var pageTextDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral1000)
            })
        }

        public static var pageTextSubtle: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral400) : UIColor(neutral700)
            })
        }

        // Sizing
        public static let sizingLg: CGFloat = 20
        public static let sizingXs: CGFloat = 8

        // Spacing
        public static let spacingBase: CGFloat = 16
        public static let spacingLg: CGFloat = 20

        // Neutral colors
        public static let neutral400 = Color(red: 194/255, green: 194/255, blue: 201/255)
        public static let neutral600 = Color(red: 94/255, green: 97/255, blue: 115/255)
        public static let neutral700 = Color(red: 66/255, green: 69/255, blue: 89/255)
        public static let neutral950 = Color(red: 26/255, green: 26/255, blue: 36/255)
        public static let neutral1000 = Color(red: 10/255, green: 13/255, blue: 15/255)
        public static let neutralWhite = Color(red: 255/255, green: 255/255, blue: 255/255)

        // Core colors used in other files
        public static let colorDarkNavy = Color(red: 41/255, green: 43/255, blue: 61/255)
        public static let colorLightGrey = Color(red: 237/255, green: 237/255, blue: 237/255)
    }
}
