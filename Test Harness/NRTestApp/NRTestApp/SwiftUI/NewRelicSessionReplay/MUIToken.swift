//
//  MUIToken.swift
//  xc
//
//  Created by Jose Fernandes on 2026-02-11.
//


/*
 * Important notice:
 * Copyright (C) 2022 Manulife IM - All Rights Reserved
 * This software is the sole property of Manulife IM and
 * cannot be distributed and/or copied without the written
 * permission of Manulife IM.
 *
 * The use of this code falls under the terms of the MIT
 * license. A copy of the MIT license should be included
 * with the code.
 */

import Foundation
import SwiftUI
import UIKit

/// Provide semantic values for common ui elements.
///
/// Using `MUIToken
/// ===============================
///
/// To declare the button, use the following:
///
///     import SwiftMUI
///
///     NavigationLink(destination: destination) {
///         EmptyView()
///     }
///     .background(MUIToken.SemanticColor.green)
///     .cornerRadius(MUIToken.Border.Radius.lg)
///
public struct MUIToken {
    public struct Border {
        public struct Radius {
            public static let sm: CGFloat = 4
            public static let md: CGFloat = 6
            public static let lg: CGFloat = 8
            public static let xl: CGFloat = 16
        }
    }
    public struct BrandColor {
        public static let brandPrimary = Color(UIColor(red: 30/255, green: 33/255, blue: 47/255, alpha: 1))
        public static let buttonPrimary = Color(UIColor(red: 40/255, green: 43/255, blue: 62/255, alpha: 1))
        public static let buttonPrimaryInverse = Color(UIColor(red: 178/255, green: 186/255, blue: 215/255, alpha: 1))
        public static let buttonTextInverse = Color(UIColor(red: 118/255, green: 176/255, blue: 255/255, alpha: 1))
        public static let green = Color(UIColor(red: 0/255, green: 167/255, blue: 88/255, alpha: 1))
        public static let blue = Color(UIColor(red: 0/255, green: 0/255, blue: 193/255, alpha: 1))
        public static let coral = Color(UIColor(red: 255/255, green: 119/255, blue: 105/255, alpha: 1))
        public static let darkNavy = Color(UIColor(red: 40/255, green: 43/255, blue: 62/255, alpha: 1))
        public static let turquoise = Color(UIColor(red: 6/255, green: 199/255, blue: 186/255, alpha: 1))
        public static let gold = Color(UIColor(red: 244/255, green: 150/255, blue: 0/255, alpha: 1))
        public static let violet = Color(UIColor(red: 54/255, green: 21/255, blue: 88/255, alpha: 1))
        public static let greenLight4 = Color(UIColor(red: 202/255, green: 238/255, blue: 217/255, alpha: 1))
        public static let greenLight3 = Color(UIColor(red: 172/255, green: 229/255, blue: 196/255, alpha: 1))
        public static let greenLight2 = Color(UIColor(red: 92/255, green: 215/255, blue: 144/255, alpha: 1))
        public static let greenLight1 = Color(UIColor(red: 0/255, green: 196/255, blue: 110/255, alpha: 1))
        public static let greenDark1 = Color(UIColor(red: 6/255, green: 135/255, blue: 78/255, alpha: 1))
        public static let greenDark2 = Color(UIColor(red: 4/255, green: 97/255, blue: 56/255, alpha: 1))
        public static let greenDark3 = Color(UIColor(red: 0/255, green: 68/255, blue: 39/255, alpha: 1))
        public static let blueLight5 = Color(UIColor(red: 118/255, green: 176/255, blue: 255/255, alpha: 1))
        public static let blueLight4 = Color(UIColor(red: 193/255, green: 216/255, blue: 247/255, alpha: 1))
        public static let blueLight3 = Color(UIColor(red: 118/255, green: 176/255, blue: 255/255, alpha: 1))
        public static let blueLight2 = Color(UIColor(red: 45/255, green: 105/255, blue: 255/255, alpha: 1))
        public static let blueLight1 = Color(UIColor(red: 30/255, green: 30/255, blue: 229/255, alpha: 1))
        public static let blueDark1 = Color(UIColor(red: 0/255, green: 0/255, blue: 154/255, alpha: 1))
        public static let blueDark2 = Color(UIColor(red: 0/255, green: 0/255, blue: 130/255, alpha: 1))
        public static let blueDark3 = Color(UIColor(red: 0/255, green: 0/255, blue: 96/255, alpha: 1))
        public static let coralLight4 = Color(UIColor(red: 246/255, green: 220/255, blue: 216/255, alpha: 1))
        public static let coralLight3 = Color(UIColor(red: 246/255, green: 204/255, blue: 199/255, alpha: 1))
        public static let coralLight2 = Color(UIColor(red: 252/255, green: 172/255, blue: 161/255, alpha: 1))
        public static let coralLight1 = Color(UIColor(red: 246/255, green: 144/255, blue: 130/255, alpha: 1))
        public static let coralDark1 = Color(UIColor(red: 236/255, green: 100/255, blue: 83/255, alpha: 1))
        public static let coralDark2 = Color(UIColor(red: 220/255, green: 90/255, blue: 68/255, alpha: 1))
        public static let coralDark3 = Color(UIColor(red: 193/255, green: 74/255, blue: 54/255, alpha: 1))
        public static let darkNavyLight5 = Color(UIColor(red: 223/255, green: 224/255, blue: 226/255, alpha: 1))
        public static let darkNavyLight4 = Color(UIColor(red: 142/255, green: 144/255, blue: 162/255, alpha: 1))
        public static let darkNavyLight3 = Color(UIColor(red: 94/255, green: 96/255, blue: 115/255, alpha: 1))
        public static let darkNavyLight2 = Color(UIColor(red: 66/255, green: 69/255, blue: 89/255, alpha: 1))
        public static let darkNavyLight1 = Color(UIColor(red: 52/255, green: 40/255, blue: 75/255, alpha: 1))
        public static let violetLight4 = Color(UIColor(red: 217/255, green: 210/255, blue: 232/255, alpha: 1))
        public static let violetLight3 = Color(UIColor(red: 190/255, green: 180/255, blue: 211/255, alpha: 1))
        public static let violetLight2 = Color(UIColor(red: 136/255, green: 119/255, blue: 171/255, alpha: 1))
        public static let violetLight1 = Color(UIColor(red: 83/255, green: 53/255, blue: 115/255, alpha: 1))
        public static let violetDark1 = Color(UIColor(red: 38/255, green: 11/255, blue: 66/255, alpha: 1))
        public static let violetDark2 = Color(UIColor(red: 29/255, green: 8/255, blue: 51/255, alpha: 1))
        public static let violetDark3 = Color(UIColor(red: 15/255, green: 1/255, blue: 29/255, alpha: 1))
        public static let goldLight4 = Color(UIColor(red: 251/255, green: 233/255, blue: 198/255, alpha: 1))
        public static let goldLight3 = Color(UIColor(red: 251/255, green: 211/255, blue: 138/255, alpha: 1))
        public static let goldLight2 = Color(UIColor(red: 252/255, green: 196/255, blue: 87/255, alpha: 1))
        public static let goldLight1 = Color(UIColor(red: 249/255, green: 171/255, blue: 46/255, alpha: 1))
        public static let goldDark1 = Color(UIColor(red: 227/255, green: 132/255, blue: 0/255, alpha: 1))
        public static let goldDark2 = Color(UIColor(red: 195/255, green: 118/255, blue: 18/255, alpha: 1))
        public static let goldDark3 = Color(UIColor(red: 167/255, green: 89/255, blue: 0/255, alpha: 1))
        public static let turquoiseLight4 = Color(UIColor(red: 197/255, green: 244/255, blue: 241/255, alpha: 1))
        public static let turquoiseLight3 = Color(UIColor(red: 197/255, green: 244/255, blue: 241/255, alpha: 1))
        public static let turquoiseLight2 = Color(UIColor(red: 106/255, green: 231/255, blue: 223/255, alpha: 1))
        public static let turquoiseLight1 = Color(UIColor(red: 40/255, green: 215/255, blue: 203/255, alpha: 1))
        public static let turquoiseDark1 = Color(UIColor(red: 5/255, green: 178/255, blue: 167/255, alpha: 1))
        public static let turquoiseDark2 = Color(UIColor(red: 8/255, green: 162/255, blue: 152/255, alpha: 1))
        public static let turquoiseDark3 = Color(UIColor(red: 11/255, green: 145/255, blue: 137/255, alpha: 1))
        public static let secondaryLabelAccessible = Color(UIColor(red: 108/255, green: 108/255, blue: 112/255, alpha: 1))
        public static let lightGrayBackground = Color(UIColor(red: 217/255, green: 217/255, blue: 217/255, alpha: 1))
    }

    public struct SemanticColor {
        public static let green = UITraitCollection.current.userInterfaceStyle == .dark ?
            Color(red: 0/255, green: 196/255, blue: 110/255) : Color(red: 0/255, green: 167/255, blue: 88/255)
        public static let red = UITraitCollection.current.userInterfaceStyle == .dark ?
            Color(red: 252/255, green: 172/255, blue: 161/255) : Color(red: 219/255, green: 31/255, blue: 0/255)
        public static let gray = UITraitCollection.current.userInterfaceStyle == .dark ?
            Color(red: 198/255, green: 198/255, blue: 200/255) : Color(red: 198/255, green: 198/255, blue: 200/255)
    }

    public struct Table {
        public static let backgroundColorLight = Color(UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1))
        public static let backgroundColorDark = Color(UIColor(red: 44/255, green: 44/255, blue: 46/255, alpha: 1))
        public static let borderColor = Color(UIColor(red: 194/255, green: 195/255, blue: 201/255, alpha: 1))

        public static let tableRowHeight: CGFloat = 49
        public static let cardRowHeight: CGFloat = 94
    }

    public struct CornerRadius {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }

    public struct Scale {
        public static let sm: CGFloat = 1
        public static let md: CGFloat = 2
        public static let lg: CGFloat = 3
        public static let xl: CGFloat = 4
        public static let xxl: CGFloat = 5
    }
    
    public struct Padding {
        public static let hairline: CGFloat = 1 / UIScreen.main.scale
        public static let xxs: CGFloat = 1
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let ssm: CGFloat = 10
        public static let md: CGFloat = 12
        public static let mmd: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let llg: CGFloat = 24
        public static let xl: CGFloat = 30
        public static let semi_xxl: CGFloat = 32
        public static let xxl: CGFloat = 40
        public static let xxxl: CGFloat = 50
    }

    public struct Opacity {
        public static let transparent: CGFloat = 0.4
        public static let semi_transparent: CGFloat = 0.35
        public static let opaque: CGFloat = 1
        public static let opaqueMinThreshold: CGFloat = 0.1
    }
    
    public struct Brightness {
        public static let low: CGFloat = 0.4
        public static let high: CGFloat = 1
    }

    public struct ImageSize {
        public static let sm: CGFloat = 20 // placeholder, not used yet
        public static let ssm: CGFloat = 32
        public static let md: CGFloat = 40
        public static let mmd: CGFloat = 70
        public static let lg: CGFloat = 100 // placeholder, not used yet
        public static let xl: CGFloat = 140 // placeholder, not used yet
    }

    public struct FontSize {
        public static let sm: CGFloat = 14
        public static let md: CGFloat = 16
        public static let mmd: CGFloat = 17
        public static let lg: CGFloat = 34
        public static let xl: CGFloat = 60
        public static let xxl: CGFloat = 80
    }
    
    public struct Insets {
        public static let hairline: CGFloat = 1 / UIScreen.main.scale
        public static let xxs: CGFloat = 1
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let mmd: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let llg: CGFloat = 24
        public static let lllg: CGFloat = 28
        public static let xl: CGFloat = 30
        public static let xxl: CGFloat = 40
    }
    
    
    
    
    /// *Design*  was extracted from FIGMA do not change, another extraction will be required
    public struct Design {
        
        public static var buttonCustom: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(colorLight3Blue) : UIColor(colorLight1Blue)
            })
        }


        public static var componentAlertBackgroundError: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(red1000) : UIColor(red50)
            })
        }
        public static var componentAlertBackgroundInfo: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(blue1000) : UIColor(blue50)
            })
        }

        public static var componentAlertBackgroundInverse: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral950) : UIColor(neutral600)
            })
        }

        public static var componentAlertBackgroundSubtle: Color {
            Color(UIColor(neutral950)) // Same for both light and dark
        }

        public static var componentAlertBackgroundSuccess: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green1000) : UIColor(green50)
            })
        }

        public static var componentAlertBackgroundWarning: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(gold1000) : UIColor(gold50)
            })
        }

        public static var componentAlertBorderError: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(red400) : UIColor(red700)
            })
        }

        public static var componentAlertBorderInfo: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(blue300) : UIColor(blue400)
            })
        }

        public static var componentAlertBorderInverse: Color {
            Color(UIColor(neutral600)) // Same for both light and dark
        }

        public static var componentAlertBorderSubtle: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral500) : UIColor(neutral300)
            })
        }

        public static var componentAlertBorderSuccess: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green400) : UIColor(green700)
            })
        }

        public static var componentAlertBorderWarning: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(gold400) : UIColor(gold800)
            })
        }

        public static var componentAlertIconError: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(red400) : UIColor(red700)
            })
        }

        public static var componentAlertIconInfo: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(blue300) : UIColor(blue400)
            })
        }

        public static var componentAlertIconInverse: Color {
            Color(UIColor(neutral300)) // Same for both light and dark
        }

        public static var componentAlertIconSubtle: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral500)
            })
        }

        public static var componentAlertIconSuccess: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green400) : UIColor(green700)
            })
        }

        public static var componentAlertIconWarning: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(gold400) : UIColor(gold800)
            })
        }

        public static var componentAlertTextDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutralWhite)
            })
        }

        public static var componentAlertTextInverse: Color {
            Color(UIColor(neutralWhite)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandBackgroundDefault: Color {
            Color(UIColor(green700)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandBackgroundDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral100)
            })
        }

        public static var componentButtonFilledBrandBackgroundFocused: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral600)
            })
        }

        public static var componentButtonFilledBrandBackgroundPressed: Color {
            Color(UIColor(green600)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandIconDefault: Color {
            Color(UIColor(neutralWhite)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandIconDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandLabelDefault: Color {
            Color(UIColor(neutralWhite)) // Same for both light and dark
        }

        public static var componentButtonFilledBrandLabelDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonFilledNeutralBackgroundDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral900)
            })
        }

        public static var componentButtonFilledNeutralBackgroundDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral100)
            })
        }

        public static var componentButtonFilledNeutralBackgroundFocused: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral600)
            })
        }

        public static var componentButtonFilledNeutralBackgroundPressed: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral200) : UIColor(neutral800)
            })
        }

        public static var componentButtonFilledNeutralIconDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutralWhite)
            })
        }

        public static var componentButtonFilledNeutralIconDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonFilledNeutralLabelDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutralWhite)
            })
        }

        public static var componentButtonFilledNeutralLabelDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonGhostBackgroundFocused: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral600)
            })
        }

        public static var componentButtonGhostBackgroundPressed: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral200)
            })
        }

        public static var componentButtonGhostIconDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral950)
            })
        }

        public static var componentButtonGhostIconDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonGhostLabelDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral950)
            })
        }

        public static var componentButtonGhostLabelDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonOutlinedBackgroundDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral950) : UIColor(neutralWhite)
            })
        }

        public static var componentButtonOutlinedBackgroundDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral100)
            })
        }

        public static var componentButtonOutlinedBackgroundFocused: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral600)
            })
        }

        public static var componentButtonOutlinedBackgroundPressed: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral200)
            })
        }

        public static var componentButtonOutlinedBorderDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral700)
            })
        }

        public static var componentButtonOutlinedBorderDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral300)
            })
        }

        public static var componentButtonOutlinedIconDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral950)
            })
        }

        public static var componentButtonOutlinedIconDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentButtonOutlinedLabelDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral950)
            })
        }

        public static var componentButtonOutlinedLabelDisabled: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var componentRadioBorderDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral500) : UIColor(neutral300)
            })
        }

        public static var componentRadioBorderDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var componentRadioBorderSelected: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral50) : UIColor(green700)
            })
        }

        public static var componentRadioButtonDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral300) : UIColor(neutral500)
            })
        }

        public static var componentRadioButtonDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var componentRadioButtonSelected: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green400) : UIColor(green700)
            })
        }

        public static var componentRadioButtonStateLayerSelected: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral300)
            })
        }

        public static var componentRadioLabelDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral1000)
            })
        }

        public static var componentRadioLabelDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var componentTooltipBackground: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral950)
            })
        }

        public static var componentTooltipText: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral1000) : UIColor(neutralWhite)
            })
        }

        public static var pageBorderDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var pageBorderSubtle: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral800) : UIColor(neutral200)
            })
        }

        public static var pageContainerBackground: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral1000) : UIColor(neutral50)
            })
        }

        public static var pageContainerDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral800) : UIColor(neutral200)
            })
        }

        public static var pageContainerInverse: Color {
            Color(UIColor(neutral950)) // Same for both light and dark
        }

        public static var pageContainerInverseDimmed: Color {
            Color(UIColor(neutral700)) // Same for both light and dark
        }

        public static var pageContainerOverlay: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(red: 51/255, green: 56/255, blue: 74/255, alpha: 0.6) : UIColor(red: 51/255, green: 56/255, blue: 74/255, alpha: 0.4)
            })
        }

        public static var pageContainerSurface: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral950) : UIColor(neutralWhite)
            })
        }

        public static var pageContainerSurfaceDimmed: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral900) : UIColor(neutral100)
            })
        }

        public static var pageIconDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral50) : UIColor(neutral900)
            })
        }

        public static var pageIconError: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(red400) : UIColor(red700)
            })
        }

        public static var pageIconInfo: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(blue300) : UIColor(blue400)
            })
        }

        public static var pageIconInteractive: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green400) : UIColor(green700)
            })
        }

        public static var pageIconInverse: Color {
            Color(UIColor(neutralWhite)) // Same for both light and dark
        }

        public static var pageIconSubtle: Color {
            Color(UIColor(neutral500)) // Same for both light and dark
        }

        public static var pageIconSuccess: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green500) : UIColor(green600)
            })
        }

        public static var pageIconWarning: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(gold400) : UIColor(gold800)
            })
        }

        public static var pageTextDefault: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutralWhite) : UIColor(neutral1000)
            })
        }

        public static var pageTextDisabled: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral600) : UIColor(neutral400)
            })
        }

        public static var pageTextInteractive: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(green400) : UIColor(green700)
            })
        }

        public static var pageTextInverse: Color {
            Color(UIColor(neutralWhite)) // Same for both light and dark
        }

        public static var pageTextSubtle: Color {
            Color(UIColor { traits in
                return traits.userInterfaceStyle == .dark ? UIColor(neutral400) : UIColor(neutral700)
            })
        }
        // Border Sizes
        public static let borderSizeBase: CGFloat = 1
        public static let borderSizeLg: CGFloat = 2
        public static let borderSizeSm: CGFloat = 0.5

        // Corner Radii
        public static let cornerRadius0: CGFloat = 0
        public static let cornerRadius2xl: CGFloat = 9999
        public static let cornerRadiusBase: CGFloat = 8
        public static let cornerRadiusLg: CGFloat = 20
        public static let cornerRadiusSm: CGFloat = 6
        public static let cornerRadiusXl: CGFloat = 40

        // Sizing
        public static let sizing2xl: CGFloat = 32
        public static let sizing2xs: CGFloat = 4
        public static let sizing3xl: CGFloat = 40
        public static let sizing4xl: CGFloat = 48
        public static let sizing5xl: CGFloat = 56
        public static let sizingBase: CGFloat = 16
        public static let sizingLg: CGFloat = 20
        public static let sizingSm: CGFloat = 12
        public static let sizingXl: CGFloat = 24
        public static let sizingXs: CGFloat = 8

        // Spacing
        public static let spacing0: CGFloat = 0
        public static let spacing2xl: CGFloat = 32
        public static let spacing2xs: CGFloat = 4
        public static let spacing3xl: CGFloat = 40
        public static let spacingBase: CGFloat = 16
        public static let spacingLg: CGFloat = 20
        public static let spacingSm: CGFloat = 12
        public static let spacingXl: CGFloat = 24
        public static let spacingXs: CGFloat = 8



        public static let blue100 = Color(red: 220/255, green: 235/255, blue: 255/255)
        public static let blue1000 = Color(red: 0/255, green: 0/255, blue: 38/255)
        public static let blue200 = colorLight4Blue
        public static let blue300 = colorLight3Blue
        public static let blue400 = colorLight2Blue
        public static let blue50 = Color(red: 240/255, green: 245/255, blue: 255/255)
        public static let blue500 = colorLight1Blue
        public static let blue600 = colorJhBlue
        public static let blue700 = colorDark1Blue
        public static let blue800 = colorDark2Blue
        public static let blue900 = colorDark3Blue
        public static let blue950 = Color(red: 0/255, green: 0/255, blue: 64/255)

        public static let cyan100 = Color(red: 204/255, green: 250/255, blue: 242/255)
        public static let cyan1000 = Color(red: 3/255, green: 26/255, blue: 20/255)
        public static let cyan200 = colorLight4Turquoise
        public static let cyan300 = colorLight3Turquoise
        public static let cyan400 = colorLight2Turquoise
        public static let cyan50 = Color(red: 240/255, green: 252/255, blue: 250/255)
        public static let cyan500 = colorLight1Turquoise
        public static let cyan600 = colorTurquoise
        public static let cyan700 = colorDark1Turquoise
        public static let cyan800 = colorDark2Turquoise
        public static let cyan900 = colorDark3Turquoise
        public static let cyan950 = Color(red: 5/255, green: 79/255, blue: 59/255)

        public static let gold100 = Color(red: 255/255, green: 237/255, blue: 214/255)
        public static let gold1000 = Color(red: 38/255, green: 20/255, blue: 0/255)
        public static let gold200 = colorLight4Gold
        public static let gold300 = colorLight3Gold
        public static let gold400 = colorLight2Gold
        public static let gold50 = Color(red: 255/255, green: 247/255, blue: 237/255)
        public static let gold500 = colorLight1Gold
        public static let gold600 = colorGold
        public static let gold700 = colorDark1Gold
        public static let gold800 = colorDark2Gold
        public static let gold900 = colorDark3Gold
        public static let gold950 = Color(red: 125/255, green: 66/255, blue: 0/255)

        public static let green100 = Color(red: 220/255, green: 253/255, blue: 232/255)
        public static let green1000 = Color(red: 0/255, green: 20/255, blue: 13/255)
        public static let green200 = colorLight4Green
        public static let green300 = colorLight3Green
        public static let green400 = colorLight2Green
        public static let green50 = Color(red: 240/255, green: 253/255, blue: 245/255)
        public static let green500 = colorLight1Green
        public static let green600 = colorMGreen
        public static let green700 = colorDark1Green
        public static let green800 = colorDark2Green
        public static let green900 = colorDark3Green
        public static let green950 = Color(red: 0/255, green: 38/255, blue: 23/255)

        public static let neutralBlack = colorBlack
        public static let neutral100 = colorLight1Grey
        public static let neutral1000 = Color(red: 10/255, green: 13/255, blue: 15/255)
        public static let neutral200 = colorLightGrey
        public static let neutral300 = colorLight5DarkNavy
        public static let neutral400 = colorDark3LightGrey
        public static let neutral50 = colorLight2Grey
        public static let neutral500 = colorLight4DarkNavy
        public static let neutral600 = colorLight3DarkNavy
        public static let neutral700 = colorLight2DarkNavy
        public static let neutral800 = colorLight1DarkNavy
        public static let neutral900 = Color(red: 38/255, green: 43/255, blue: 56/255)
        public static let neutral950 = Color(red: 26/255, green: 26/255, blue: 36/255)
        public static let neutralWhite = colorWhite

        public static let purple100 = Color(red: 242/255, green: 232/255, blue: 255/255)
        public static let purple1000 = Color(red: 13/255, green: 8/255, blue: 26/255)
        public static let purple200 = colorLight4Violet
        public static let purple300 = colorLight3Violet
        public static let purple400 = colorLight2Violet
        public static let purple50 = Color(red: 250/255, green: 245/255, blue: 255/255)
        public static let purple500 = colorLight1Violet
        public static let purple600 = colorViolet
        public static let purple700 = colorDark1Violet
        public static let purple800 = colorDark2Violet
        public static let purple900 = colorDark3Violet
        public static let purple950 = Color(red: 26/255, green: 15/255, blue: 51/255)

        public static let red100 = Color(red: 255/255, green: 227/255, blue: 227/255)
        public static let red1000 = Color(red: 41/255, green: 5/255, blue: 5/255)
        public static let red200 = colorLight3Coral
        public static let red300 = colorLight2Coral
        public static let red400 = colorLight1Coral
        public static let red50 = Color(red: 255/255, green: 242/255, blue: 242/255)
        public static let red500 = colorCoral
        public static let red600 = colorRed
        public static let red700 = colorDark1Coral
        public static let red800 = colorDark2Coral
        public static let red900 = colorDark3Coral
        public static let red950 = Color(red: 92/255, green: 10/255, blue: 10/255)

        // Accent Colors
        public static let colorAccentDark1 = colorDark1Coral
        public static let colorAccentDark2 = colorDark2Coral
        public static let colorAccentDark3 = colorDark3Coral
        public static let colorAccentDefault = colorCoral
        public static let colorAccentLight1 = colorLight1Coral
        public static let colorAccentLight2 = colorLight2Coral
        public static let colorAccentLight3 = colorLight3Coral
        public static let colorAccentLight4 = colorLight4Coral

        // Core Colors
        public static let colorBlack = Color(red: 0/255, green: 0/255, blue: 0/255)
        public static let colorCoral = Color(red: 237/255, green: 99/255, blue: 84/255)
        public static let colorDark1Blue = Color(red: 0/255, green: 0/255, blue: 153/255)
        public static let colorDark1Coral = Color(red: 209/255, green: 58/255, blue: 56/255)
        public static let colorDark1Gold = Color(red: 227/255, green: 133/255, blue: 0/255)
        public static let colorDark1Green = Color(red: 5/255, green: 135/255, blue: 79/255)
        public static let colorDark1LightGrey = Color(red: 230/255, green: 230/255, blue: 232/255)
        public static let colorDark1Turquoise = Color(red: 5/255, green: 179/255, blue: 166/255)
        public static let colorDark1Violet = Color(red: 77/255, green: 51/255, blue: 107/255)
        public static let colorDark2Blue = Color(red: 0/255, green: 0/255, blue: 130/255)
        public static let colorDark2Coral = Color(red: 160/255, green: 13/255, blue: 23/255)
        public static let colorDark2Gold = Color(red: 207/255, green: 118/255, blue: 18/255)
        public static let colorDark2Green = Color(red: 5/255, green: 97/255, blue: 56/255)
        public static let colorDark2LightGrey = Color(red: 221/255, green: 224/255, blue: 227/255)
        public static let colorDark2Turquoise = Color(red: 8/255, green: 163/255, blue: 153/255)
        public static let colorDark2Violet = Color(red: 51/255, green: 26/255, blue: 84/255)
        public static let colorDark3Blue = Color(red: 0/255, green: 0/255, blue: 97/255)
        public static let colorDark3Coral = Color(red: 130/255, green: 10/255, blue: 15/255)
        public static let colorDark3Gold = Color(red: 166/255, green: 89/255, blue: 0/255)
        public static let colorDark3Green = Color(red: 0/255, green: 69/255, blue: 38/255)
        public static let colorDark3LightGrey = Color(red: 194/255, green: 194/255, blue: 201/255)
        public static let colorDark3Turquoise = Color(red: 10/255, green: 145/255, blue: 137/255)
        public static let colorDark3Violet = Color(red: 38/255, green: 23/255, blue: 71/255)
        public static let colorDarkNavy = Color(red: 41/255, green: 43/255, blue: 61/255)
        public static let colorGold = Color(red: 245/255, green: 150/255, blue: 0/255)
        public static let colorJhBlue = Color(red: 0/255, green: 0/255, blue: 194/255)
        public static let colorLight1Blue = Color(red: 31/255, green: 31/255, blue: 230/255)
        public static let colorLight1Coral = Color(red: 255/255, green: 120/255, blue: 104/255)
        public static let colorLight1DarkNavy = Color(red: 51/255, green: 56/255, blue: 74/255)
        public static let colorLight1Gold = Color(red: 250/255, green: 171/255, blue: 46/255)
        public static let colorLight1Green = Color(red: 0/255, green: 196/255, blue: 110/255)
        public static let colorLight1Grey = Color(red: 245/255, green: 245/255, blue: 245/255)
        public static let colorLight1Turquoise = Color(red: 41/255, green: 214/255, blue: 204/255)
        public static let colorLight1Violet = Color(red: 112/255, green: 86/255, blue: 148/255)
        public static let colorLight2Blue = Color(red: 46/255, green: 105/255, blue: 255/255)
        public static let colorLight2Coral = Color(red: 245/255, green: 143/255, blue: 130/255)
        public static let colorLight2DarkNavy = Color(red: 66/255, green: 69/255, blue: 89/255)
        public static let colorLight2Gold = Color(red: 253/255, green: 196/255, blue: 87/255)
        public static let colorLight2Green = Color(red: 92/255, green: 214/255, blue: 143/255)
        public static let colorLight2Grey = Color(red: 250/255, green: 250/255, blue: 250/255)
        public static let colorLight2Turquoise = Color(red: 107/255, green: 232/255, blue: 222/255)
        public static let colorLight2Violet = Color(red: 130/255, green: 107/255, blue: 166/255)
        public static let colorLight3Blue = Color(red: 117/255, green: 176/255, blue: 255/255)
        public static let colorLight3Coral = Color(red: 253/255, green: 171/255, blue: 161/255)
        public static let colorLight3DarkNavy = Color(red: 94/255, green: 97/255, blue: 115/255)
        public static let colorLight3Gold = Color(red: 247/255, green: 211/255, blue: 138/255)
        public static let colorLight3Green = Color(red: 171/255, green: 230/255, blue: 196/255)
        public static let colorLight3Turquoise = Color(red: 158/255, green: 242/255, blue: 238/255)
        public static let colorLight3Violet = Color(red: 158/255, green: 140/255, blue: 189/255)
        public static let colorLight4Blue = Color(red: 194/255, green: 217/255, blue: 247/255)
        public static let colorLight4Coral = Color(red: 245/255, green: 204/255, blue: 199/255)
        public static let colorLight4DarkNavy = Color(red: 143/255, green: 143/255, blue: 163/255)
        public static let colorLight4Gold = Color(red: 250/255, green: 232/255, blue: 199/255)
        public static let colorLight4Green = Color(red: 201/255, green: 237/255, blue: 217/255)
        public static let colorLight4Turquoise = Color(red: 197/255, green: 245/255, blue: 242/255)
        public static let colorLight4Violet = Color(red: 212/255, green: 209/255, blue: 232/255)
        public static let colorLight5DarkNavy = Color(red: 222/255, green: 222/255, blue: 227/255)
        public static let colorLightGrey = Color(red: 237/255, green: 237/255, blue: 237/255)
        public static let colorMGreen = Color(red: 0/255, green: 166/255, blue: 89/255)

        // Neutral Colors
        public static let colorNeutralDarkDark1 = colorSuperDarkNavy
        public static let colorNeutralDarkDark2 = colorBlack
        public static let colorNeutralDarkDefault = colorDarkNavy
        public static let colorNeutralDarkLight1 = colorLight1DarkNavy
        public static let colorNeutralDarkLight2 = colorLight2DarkNavy
        public static let colorNeutralDarkLight3 = colorLight3DarkNavy
        public static let colorNeutralDarkLight4 = colorLight4DarkNavy
        public static let colorNeutralDarkLight5 = colorLight5DarkNavy
        public static let colorNeutralLightDark1 = colorDark1LightGrey
        public static let colorNeutralLightDark2 = colorDark2LightGrey
        public static let colorNeutralLightDark3 = colorDark3LightGrey
        public static let colorNeutralLightDefault = colorLightGrey
        public static let colorNeutralLightLight1 = colorLight1Grey
        public static let colorNeutralLightLight2 = colorLight2Grey
        public static let colorNeutralLightLight3 = colorWhite

        // Primary Colors
        public static let colorPrimaryAlternateDark1 = colorDark1Blue
        public static let colorPrimaryAlternateDark2 = colorDark2Blue
        public static let colorPrimaryAlternateDark3 = colorDark3Blue
        public static let colorPrimaryAlternateDefault = colorJhBlue
        public static let colorPrimaryAlternateLight1 = colorLight1Blue
        public static let colorPrimaryAlternateLight2 = colorLight2Blue
        public static let colorPrimaryAlternateLight3 = colorLight3Blue
        public static let colorPrimaryAlternateLight4 = colorLight4Blue

        public static let colorPrimaryMainDark1 = colorDark1Green
        public static let colorPrimaryMainDark2 = colorDark2Green
        public static let colorPrimaryMainDark3 = colorDark3Green
        public static let colorPrimaryMainDefault = colorMGreen
        public static let colorPrimaryMainLight1 = colorLight1Green
        public static let colorPrimaryMainLight2 = colorLight2Green
        public static let colorPrimaryMainLight3 = colorLight3Green
        public static let colorPrimaryMainLight4 = colorLight4Green

        public static let colorRed = Color(red: 219/255, green: 31/255, blue: 0/255)

        // Secondary Colors
        public static let colorSecondaryOneDark1 = colorDark1Violet
        public static let colorSecondaryOneDark2 = colorDark2Violet
        public static let colorSecondaryOneDark3 = colorDark3Violet
        public static let colorSecondaryOneDefault = colorViolet
        public static let colorSecondaryOneLight1 = colorLight1Violet
        public static let colorSecondaryOneLight2 = colorLight2Violet
        public static let colorSecondaryOneLight3 = colorLight3Violet
        public static let colorSecondaryOneLight4 = colorLight4Violet

        public static let colorSecondaryThreeDark1 = colorDark1Turquoise
        public static let colorSecondaryThreeDark2 = colorDark2Turquoise
        public static let colorSecondaryThreeDark3 = colorDark3Turquoise
        public static let colorSecondaryThreeDefault = colorTurquoise
        public static let colorSecondaryThreeLight1 = colorLight1Turquoise
        public static let colorSecondaryThreeLight2 = colorLight2Turquoise
        public static let colorSecondaryThreeLight3 = colorLight3Turquoise
        public static let colorSecondaryThreeLight4 = colorLight4Turquoise

        public static let colorSecondaryTwoDark1 = colorDark1Gold
        public static let colorSecondaryTwoDark2 = colorDark2Gold
        public static let colorSecondaryTwoDark3 = colorDark3Gold
        public static let colorSecondaryTwoDefault = colorGold
        public static let colorSecondaryTwoLight1 = colorLight1Gold
        public static let colorSecondaryTwoLight2 = colorLight2Gold
        public static let colorSecondaryTwoLight3 = colorLight3Gold
        public static let colorSecondaryTwoLight4 = colorLight4Gold

        // Status Colors
        public static let colorStatusDisabled = colorLight4DarkNavy
        public static let colorStatusError = colorRed
        public static let colorStatusInactive = colorLightGrey
        public static let colorStatusInformation = colorLight2Blue
        public static let colorStatusSuccess = colorDark1Green
        public static let colorStatusWarning = colorDark2Gold

        // Other Colors
        public static let colorSuperDarkNavy = Color(red: 31/255, green: 33/255, blue: 46/255)
        public static let colorTurquoise = Color(red: 5/255, green: 199/255, blue: 186/255)
        public static let colorViolet = Color(red: 97/255, green: 69/255, blue: 133/255)
        public static let colorWhite = Color(red: 255/255, green: 255/255, blue: 255/255)
        
        // Font Sizes
        public static let fontSize10xl: CGFloat = 36
        public static let fontSize11xl: CGFloat = 38
        public static let fontSize12xl: CGFloat = 44
        public static let fontSize13xl: CGFloat = 47
        public static let fontSize14xl: CGFloat = 48
        public static let fontSize15xl: CGFloat = 54
        public static let fontSize16xl: CGFloat = 56
        public static let fontSize17xl: CGFloat = 60
        public static let fontSize2xl: CGFloat = 22
        public static let fontSize2xs: CGFloat = 13
        public static let fontSize3xl: CGFloat = 23
        public static let fontSize3xs: CGFloat = 12
        public static let fontSize4xl: CGFloat = 24
        public static let fontSize5xl: CGFloat = 25
        public static let fontSize6xl: CGFloat = 26
        public static let fontSize7xl: CGFloat = 30
        public static let fontSize8xl: CGFloat = 32
        public static let fontSize9xl: CGFloat = 34
        public static let fontSizeBase: CGFloat = 16
        public static let fontSizeLg: CGFloat = 17
        public static let fontSizeSm: CGFloat = 15
        public static let fontSizeXl: CGFloat = 18
        public static let fontSizeXs: CGFloat = 14
        
        public static let fontSizeBodyL: CGFloat = 17
        public static let fontSizeBodyM: CGFloat = 16
        public static let fontSizeBodyS: CGFloat = 15
        public static let fontSizeDisplay: CGFloat = 34
        public static let fontSizeLabelL: CGFloat = 13
        public static let fontSizeLabelM: CGFloat = 12
        public static let fontSizeLabelS: CGFloat = 11
        public static let fontSizeTitleL: CGFloat = 28
        public static let fontSizeTitleM: CGFloat = 22
        public static let fontSizeTitleS: CGFloat = 20
        
        public static let letterSpacingTitleL: CGFloat = 0.38
        public static let letterSpacingDisplay: CGFloat = 0.4
        
        // Font Weights
        public static let fontWeightBold: CGFloat = 700
        public static let fontWeightDemibold: CGFloat = 600
        public static let fontWeightLight: CGFloat = 300
        public static let fontWeightRegular: CGFloat = 400
        
        // Layout Sizes
        public static let layout1: CGFloat = 12
        public static let layout2: CGFloat = 16
        public static let layout3: CGFloat = 24
        public static let layout4: CGFloat = 32
        public static let layout5: CGFloat = 40
        public static let layout6: CGFloat = 48
        public static let layout7: CGFloat = 64
        public static let layout8: CGFloat = 96
        public static let layout9: CGFloat = 160
        
        // Letter Spacing
        public static let letterSpacingB1: CGFloat = 0
        public static let letterSpacingB2: CGFloat = 0
        public static let letterSpacingH1: CGFloat = 0
        public static let letterSpacingH2: CGFloat = 0
        public static let letterSpacingH3: CGFloat = 0
        public static let letterSpacingH4: CGFloat = 0
        public static let letterSpacingLink: CGFloat = 0
        
        // Line Heights
        public static let lineHeight10xl: CGFloat = 60
        public static let lineHeight11xl: CGFloat = 64
        public static let lineHeight12xl: CGFloat = 68
        public static let lineHeight13xl: CGFloat = 72
        public static let lineHeight14xl: CGFloat = 84
        public static let lineHeight2xl: CGFloat = 28
        public static let lineHeight2xs: CGFloat = 13
        public static let lineHeight3xl: CGFloat = 32
        public static let lineHeight3xs: CGFloat = 12
        public static let lineHeight4xl: CGFloat = 36
        public static let lineHeight5xl: CGFloat = 41
        public static let lineHeight6xl: CGFloat = 44
        public static let lineHeight7xl: CGFloat = 48
        public static let lineHeight8xl: CGFloat = 54
        public static let lineHeight9xl: CGFloat = 56
        public static let lineHeightBase: CGFloat = 16
        public static let lineHeightLg: CGFloat = 20
        public static let lineHeightSm: CGFloat = 15
        public static let lineHeightXl: CGFloat = 24
        public static let lineHeightXs: CGFloat = 14
        
        // Radius
        public static let radius2xl: CGFloat = 32
        public static let radius3xl: CGFloat = 64
        public static let radiusLg: CGFloat = 12
        public static let radiusMd: CGFloat = 8
        public static let radiusSm: CGFloat = 4
        public static let radiusXl: CGFloat = 16
        
        // Screen Sizes
        public static let screen2xl: CGFloat = 1920
        public static let screenDesktop: CGFloat = screenMd
        public static let screenLg: CGFloat = 1280
        public static let screenMd: CGFloat = 1024
        public static let screenMobile: CGFloat = screenXs
        public static let screenSm: CGFloat = 768
        public static let screenTablet: CGFloat = screenSm
        public static let screenXl: CGFloat = 1440
        public static let screenXs: CGFloat = 320
        
        // Spacing
        public static let spacing1: CGFloat = 4
        public static let spacing2: CGFloat = 8
        public static let spacing3: CGFloat = 12
        public static let spacing4: CGFloat = 16
        public static let spacing5: CGFloat = 24
        public static let spacing6: CGFloat = 32
        public static let spacing7: CGFloat = 40
        public static let spacing8: CGFloat = 48
        public static let spacing9: CGFloat = 64

        
        public static let fontFamilyFontFamily = "SF Pro"
    }
}

