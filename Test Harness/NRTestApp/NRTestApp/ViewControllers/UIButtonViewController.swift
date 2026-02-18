//
//  UIButtonViewController.swift
//  NRTestApp
//
//  Created by Chris Dillard on 2/17/26.
//

import UIKit

class UIButtonViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UIButton Catalog"
        setupView()
        addButtonExamples()
    }

    private func setupView() {
        view.backgroundColor = .white

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        stackView.distribution = .fill

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func addButtonExamples() {
        // System Button Types
        addSection(title: "System Button Types")
        addButton(createSystemButton())
        addButton(createDetailDisclosureButton())
        addButton(createInfoButton())
        addButton(createContactAddButton())

        // Button Configurations (iOS 15+)
        if #available(iOS 15.0, *) {
            addSection(title: "Button Configurations")
            addButton(createPlainConfigButton())
            addButton(createGrayConfigButton())
            addButton(createTintedConfigButton())
            addButton(createFilledConfigButton())
        }

        // Custom Colors
        addSection(title: "Custom Colors")
        addButton(createColoredButton())
        addButton(createGradientButton())
        addButton(createCustomBackgroundButton())

        // Corner Radius & Borders
        addSection(title: "Corner Radius & Borders")
        addButton(createRoundedButton())
        addButton(createBorderedButton())
        addButton(createCircleButton())

        // Image Buttons
        addSection(title: "Image Buttons")
        addButton(createImageButton())
        addButton(createImageWithTextButton())
        addButton(createSymbolButton())

        // Font Styles
        addSection(title: "Font Styles")
        addButton(createBoldFontButton())
        addButton(createItalicFontButton())
        addButton(createLargeFontButton())

        // Effects
        addSection(title: "Visual Effects")
        addButton(createShadowButton())
        addButton(createAttributedTitleButton())
        addButton(createMultiLineButton())

        // States
        addSection(title: "Button States")
        addButton(createHighlightedButton())
        addButton(createDisabledButton())
        addButton(createSelectedButton())

        // Interactive
        addSection(title: "Interactive Elements")
        addButton(createCounterButton())
        addButton(createLoadingButton())

        // Custom Shapes
        addSection(title: "Custom Shapes")
        addButton(createPillShapeButton())
        addButton(createCapsuleButton())
    }

    private func addSection(title: String) {
        let label = UILabel()
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = .lightGray
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true

        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(separator)
    }

    private func addButton(_ button: UIButton) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        stackView.addArrangedSubview(container)
    }

    // MARK: - Button Creation Methods

    private func createSystemButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("System Button", for: .normal)
        return button
    }

    private func createDetailDisclosureButton() -> UIButton {
        let button = UIButton(type: .detailDisclosure)
        return button
    }

    private func createInfoButton() -> UIButton {
        let button = UIButton(type: .infoLight)
        return button
    }

    private func createContactAddButton() -> UIButton {
        let button = UIButton(type: .contactAdd)
        return button
    }

    @available(iOS 15.0, *)
    private func createPlainConfigButton() -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = "Plain Configuration"
        let button = UIButton(configuration: config)
        return button
    }

    @available(iOS 15.0, *)
    private func createGrayConfigButton() -> UIButton {
        var config = UIButton.Configuration.gray()
        config.title = "Gray Configuration"
        let button = UIButton(configuration: config)
        return button
    }

    @available(iOS 15.0, *)
    private func createTintedConfigButton() -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = "Tinted Configuration"
        config.baseBackgroundColor = .systemPurple
        config.baseForegroundColor = .systemPurple
        let button = UIButton(configuration: config)
        return button
    }

    @available(iOS 15.0, *)
    private func createFilledConfigButton() -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "Filled Configuration"
        config.baseBackgroundColor = .systemBlue
        let button = UIButton(configuration: config)
        return button
    }

    private func createColoredButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Colored Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createGradientButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Gradient Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 200, height: 44)
        gradientLayer.cornerRadius = 8

        button.layer.insertSublayer(gradientLayer, at: 0)
        return button
    }

    private func createCustomBackgroundButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Custom Background", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemOrange
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

        button.setBackgroundColor(.systemOrange.withAlphaComponent(0.5), for: .highlighted)
        return button
    }

    private func createRoundedButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Rounded Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createBorderedButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Bordered Button", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createCircleButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("●", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemIndigo
        button.widthAnchor.constraint(equalToConstant: 60).isActive = true
        button.heightAnchor.constraint(equalToConstant: 60).isActive = true
        button.layer.cornerRadius = 30
        button.clipsToBounds = true
        return button
    }

    private func createImageButton() -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: "star.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemYellow
        return button
    }

    private func createImageWithTextButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("  Image + Text", for: .normal)
        let image = UIImage(systemName: "heart.fill")
        button.setImage(image, for: .normal)
        button.tintColor = .systemPink
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        return button
    }

    private func createSymbolButton() -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)
        let image = UIImage(systemName: "play.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemGreen
        return button
    }

    private func createBoldFontButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Bold Font Button", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        return button
    }

    private func createItalicFontButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Italic Font Button", for: .normal)
        button.titleLabel?.font = UIFont.italicSystemFont(ofSize: 16)
        return button
    }

    private func createLargeFontButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Large Font", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        return button
    }

    private func createShadowButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Shadow Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemTeal
        button.layer.cornerRadius = 8
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 4
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createAttributedTitleButton() -> UIButton {
        let button = UIButton(type: .system)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.systemRed,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let attributedTitle = NSAttributedString(string: "Attributed Title", attributes: attributes)
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }

    private func createMultiLineButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Multi-Line\nButton Text", for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .systemGray5
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createHighlightedButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Tap Me!", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.lightGray, for: .highlighted)
        button.backgroundColor = .systemBlue
        button.setBackgroundColor(.systemBlue.withAlphaComponent(0.6), for: .highlighted)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }

    private func createDisabledButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Disabled Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGray
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        button.isEnabled = false
        return button
    }

    private func createSelectedButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Toggle Me", for: .normal)
        button.setTitle("Selected!", for: .selected)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGray
        button.setBackgroundColor(.systemGreen, for: .selected)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

        button.addTarget(self, action: #selector(toggleButtonSelected(_:)), for: .touchUpInside)
        return button
    }

    private func createCounterButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Tap Count: 0", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemIndigo
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        button.tag = 0

        button.addTarget(self, action: #selector(incrementCounter(_:)), for: .touchUpInside)
        return button
    }

    private func createLoadingButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Start Loading", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

        button.addTarget(self, action: #selector(toggleLoading(_:)), for: .touchUpInside)
        return button
    }

    private func createPillShapeButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Pill Shape", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemPink
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 32, bottom: 12, right: 32)
        button.layer.cornerRadius = 22
        return button
    }

    private func createCapsuleButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("Capsule Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBrown
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 40, bottom: 16, right: 40)

        DispatchQueue.main.async {
            button.layer.cornerRadius = button.frame.height / 2
        }
        return button
    }

    // MARK: - Actions

    @objc private func buttonTapped(_ sender: UIButton) {
        let title = sender.title(for: .normal) ?? "Button"
        print("Tapped: \(title)")

        let alert = UIAlertController(title: "Button Tapped", message: title, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func toggleButtonSelected(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        print("Button selected state: \(sender.isSelected)")
    }

    @objc private func incrementCounter(_ sender: UIButton) {
        sender.tag += 1
        sender.setTitle("Tap Count: \(sender.tag)", for: .normal)
    }

    @objc private func toggleLoading(_ sender: UIButton) {
        if sender.subviews.contains(where: { $0 is UIActivityIndicatorView }) {
            sender.subviews.first(where: { $0 is UIActivityIndicatorView })?.removeFromSuperview()
            sender.setTitle("Start Loading", for: .normal)
            sender.isEnabled = true
        } else {
            sender.setTitle("", for: .normal)
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = .white
            spinner.translatesAutoresizingMaskIntoConstraints = false
            sender.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: sender.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: sender.centerYAnchor)
            ])
            spinner.startAnimating()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak sender] in
                spinner.removeFromSuperview()
                sender?.setTitle("Start Loading", for: .normal)
            }
        }
    }
}

// MARK: - UIButton Extension

extension UIButton {
    func setBackgroundColor(_ color: UIColor, for state: UIControl.State) {
        let image = UIImage.imageWithColor(color: color)
        setBackgroundImage(image, for: state)
    }
}

extension UIImage {
    static func imageWithColor(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
