//
//  SplashViewController.swift
//  ExpensesTracker
//
//  Port of SpalashScreen (Android's spelling), which held the LAUNCHER intent filter, ran a fade-and-
//  scale animation over a full-screen image, and started MainActivity from the animation's
//  `onAnimationEnd`.
//
//  Two things change in the port. The image becomes a drawn wordmark, because res/drawable/splashscreen.jpg
//  is a photograph this repo has no licence to and an app icon would have to be invented anyway. And the
//  transition hangs off the animation's completion handler rather than a delegate callback, which is the
//  same guarantee — the next screen appears when the animation is done, not on a timer that might race it.
//

import UIKit

final class SplashViewController: InstrumentedViewController {

    override var viewName: ViewName { .splash }

    private let onFinished: () -> Void
    private let wordmark = UILabel()
    private let subtitle = UILabel()

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.home

        wordmark.text = "Expenses\ntracker"
        wordmark.font = .systemFont(ofSize: 44, weight: .heavy)
        wordmark.textColor = .white
        wordmark.textAlignment = .center
        wordmark.numberOfLines = 0

        subtitle.text = "New Relic iOS agent test harness"
        subtitle.font = .systemFont(ofSize: 14, weight: .medium)
        subtitle.textColor = Theme.accentGreen
        subtitle.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [wordmark, subtitle])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        // res/anim/spalsh_anim.xml: fade in while scaling up.
        stack.alpha = 0
        stack.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runSplashAnimation()
    }

    private func runSplashAnimation() {
        guard let stack = view.subviews.first else {
            onFinished()
            return
        }

        UIView.animate(withDuration: 0.9,
                       delay: 0,
                       usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.2,
                       options: [.allowUserInteraction]) {
            stack.alpha = 1
            stack.transform = .identity
        } completion: { [weak self] _ in
            // Android held the splash only as long as the animation; a short pause after it lands is
            // the difference between a splash you can see and a flash you cannot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self?.onFinished()
            }
        }
    }
}
