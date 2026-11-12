//
//  Theme.swift
//  ExpensesTracker
//
//  The Android app's palette and the few shared view builders, in one place.
//
//  Colours come straight from res/values/colors.xml so the two apps look like the same product:
//
//      Homecolor               #024D05   the toolbar / primary green
//      custom_button_text_color #035906   button text and accents
//      colorprimaryvarient     #82EF02   the bright accent green
//      cardColor               #0C134F   the dark navy used for cards
//      blue                    #0B219C   income accents
//
//  Deliberately light-mode only, as the Android app was: it hardcoded white backgrounds and dark card
//  colours with no night qualifiers, so honouring the system dark mode here would make the two apps
//  diverge visually for no gain. `overrideUserInterfaceStyle` is set on the window's root controllers.
//

import UIKit

enum Theme {

    static let home = UIColor(red: 0.008, green: 0.302, blue: 0.020, alpha: 1)          // #024D05
    static let buttonText = UIColor(red: 0.012, green: 0.349, blue: 0.024, alpha: 1)    // #035906
    static let accentGreen = UIColor(red: 0.510, green: 0.937, blue: 0.008, alpha: 1)   // #82EF02
    static let card = UIColor(red: 0.047, green: 0.075, blue: 0.310, alpha: 1)          // #0C134F
    static let incomeBlue = UIColor(red: 0.043, green: 0.129, blue: 0.612, alpha: 1)    // #0B219C

    static let background = UIColor.white
    static let expenseRed = UIColor.systemRed

    /// Tint for a ledger of either kind, used by totals, cells and amount labels.
    static func tint(for kind: RecordKind) -> UIColor {
        switch kind {
        case .income:  return home
        case .expense: return expenseRed
        }
    }

    // MARK: - Shared view builders

    /// The Android `customloginbutton` / `custom_button_background` shape: filled, rounded, uppercase.
    static func filledButton(title: String, color: UIColor = Theme.home) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = color
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)

        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }

    static func textButton(title: String, color: UIColor = Theme.buttonText) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = color
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = .systemFont(ofSize: 15)
        return button
    }

    /// The Android `customedittext` shape: a bordered field with an SF Symbol where the drawable was.
    static func textField(placeholder: String, symbol: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.backgroundColor = UIColor.secondarySystemBackground
        field.font = .systemFont(ofSize: 16)
        field.autocorrectionType = .no
        field.spellCheckingType = .no

        let icon = UIImageView(image: UIImage(systemName: symbol))
        icon.tintColor = Theme.buttonText
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 34, height: 22)
        field.leftView = icon
        field.leftViewMode = .always

        return field
    }

    static func titleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 26, weight: .heavy)
        label.textColor = Theme.home
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    static func card(_ content: UIView, background: UIColor = Theme.card) -> UIView {
        let container = UIView()
        container.backgroundColor = background
        container.layer.cornerRadius = 14
        container.layer.cornerCurve = .continuous
        container.addSubview(content)

        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14)
        ])
        return container
    }
}
