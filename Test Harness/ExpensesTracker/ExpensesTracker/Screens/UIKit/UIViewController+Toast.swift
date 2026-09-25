//
//  UIViewController+Toast.swift
//  ExpensesTracker
//
//  A stand-in for Android's Toast, which the original app used for essentially all feedback: "LOGIN
//  SUCCESSFUL", "Data Inserted", "DATA UPDATED", "Still no internet", the orientation announcements,
//  and every confirmation from the New Relic test menu.
//
//  iOS has no toast, and the honest alternatives are worse for this app: a UIAlertController demands a
//  tap for a message that was never worth one, and doing nothing would delete feedback that the
//  original screens genuinely relied on. So this is a small floating capsule that fades itself out —
//  close enough in behaviour that the ported screens read the same as their Java originals.
//
//  It is not instrumented. A toast is not a view in the MobileViews sense: it has no lifecycle a user
//  navigates through, and reporting one would put noise in the very timeline this app exists to make
//  readable.
//

import UIKit

extension UIViewController {

    func showToast(_ message: String, duration: TimeInterval = 2.0) {
        let label = PaddedLabel()
        label.text = message
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        label.layer.cornerRadius = 18
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.86)
        ])

        UIView.animate(withDuration: 0.2) { label.alpha = 1 } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: []) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
}

/// UILabel has no content insets, and a capsule with text against its edges looks broken.
private final class PaddedLabel: UILabel {

    private let insets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }

    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        let rect = super.textRect(forBounds: bounds.inset(by: insets),
                                  limitedToNumberOfLines: numberOfLines)
        return rect.inset(by: UIEdgeInsets(top: -insets.top, left: -insets.left,
                                           bottom: -insets.bottom, right: -insets.right))
    }
}
