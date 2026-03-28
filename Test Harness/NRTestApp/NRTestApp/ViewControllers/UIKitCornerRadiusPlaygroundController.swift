//
//  UIKitCornerRadiusPlaygroundController.swift
//  NRTestApp
//
//  Copyright © 2026 New Relic. All rights reserved.
//

import UIKit
import NewRelic

#if os(iOS)
class UIKitCornerRadiusPlaygroundController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        createCornerRadiusExamples()
    }

    private func setupUI() {
        title = "🔴 UIKit Corner Radius Playground"
        view.backgroundColor = .systemBackground

        // ScrollView setup
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Content StackView setup
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.alignment = .fill
        contentStackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        contentStackView.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func createCornerRadiusExamples() {
        // Add title
        let titleLabel = createLabel(text: "UIKit Corner Radius Examples", fontSize: 24, weight: .bold, color: .label)
        contentStackView.addArrangedSubview(titleLabel)

        // MARK: - Basic Corner Radius Examples
        addSectionHeader("📐 Basic Corner Radius")

        let basicCorners: [(String, CGFloat)] = [
            ("No Corners (0px)", 0),
            ("Small (4px)", 4),
            ("Medium (8px)", 8),
            ("Standard (10px)", 10),
            ("Large (12px)", 12),
            ("XL (16px)", 16),
            ("XXL (20px)", 20),
            ("Circle (50px)", 50)
        ]

        for (title, radius) in basicCorners {
            let container = createCornerExample(title: title, radius: radius, backgroundColor: .systemBlue)
            contentStackView.addArrangedSubview(container)
        }

        // MARK: - Colored Corner Examples
        addSectionHeader("🎨 Colored Backgrounds")

        let coloredExamples: [(String, CGFloat, UIColor)] = [
            ("Red Card", 12, .systemRed),
            ("Green Card", 12, .systemGreen),
            ("Purple Card", 12, .systemPurple),
            ("Orange Card", 12, .systemOrange),
            ("Pink Card", 12, .systemPink),
            ("Indigo Card", 12, .systemIndigo)
        ]

        for (title, radius, color) in coloredExamples {
            let container = createCornerExample(title: title, radius: radius, backgroundColor: color)
            contentStackView.addArrangedSubview(container)
        }

        // MARK: - Border + Corner Radius
        addSectionHeader("🔳 Borders + Corner Radius")

        let borderExamples: [(String, CGFloat, CGFloat, UIColor)] = [
            ("Thin Border", 10, 1, .systemGray),
            ("Medium Border", 10, 3, .systemBlue),
            ("Thick Border", 10, 5, .systemRed),
            ("Extra Thick", 15, 8, .systemPurple)
        ]

        for (title, radius, borderWidth, borderColor) in borderExamples {
            let container = createBorderedCornerExample(
                title: title,
                radius: radius,
                borderWidth: borderWidth,
                borderColor: borderColor
            )
            contentStackView.addArrangedSubview(container)
        }

        // MARK: - Button Examples
        addSectionHeader("🔘 Interactive Buttons")

        let buttonExamples: [(String, CGFloat)] = [
            ("Rounded Button", 8),
            ("Pill Button", 25),
            ("Card Button", 12)
        ]

        for (title, radius) in buttonExamples {
            let button = createRoundedButton(title: title, radius: radius)
            let container = createLabeledContainer(title: "\(title) (\(Int(radius))px)", view: button)
            contentStackView.addArrangedSubview(container)
        }

        // MARK: - Complex Layouts
        addSectionHeader("🏗️ Complex Layout Examples")

        // Nested rounded views
        let nestedContainer = createNestedRoundedViews()
        let nestedLabeledContainer = createLabeledContainer(title: "Nested Rounded Views", view: nestedContainer)
        contentStackView.addArrangedSubview(nestedLabeledContainer)

        // Card with content
        let cardWithContent = createCardWithContent()
        let cardLabeledContainer = createLabeledContainer(title: "Content Card (12px corners)", view: cardWithContent)
        contentStackView.addArrangedSubview(cardLabeledContainer)

        // MARK: - Edge Cases
        addSectionHeader("⚠️ Edge Cases")

        // Very small views with large corner radius
        let tinyView = UIView()
        tinyView.backgroundColor = .systemYellow
        tinyView.layer.cornerRadius = 25
        tinyView.translatesAutoresizingMaskIntoConstraints = false
        tinyView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        tinyView.widthAnchor.constraint(equalToConstant: 30).isActive = true
        let tinyContainer = createLabeledContainer(title: "Tiny View, Large Radius (25px on 30x30)", view: tinyView)
        contentStackView.addArrangedSubview(tinyContainer)

        // Asymmetric corner radius
        let asymmetricView = UIView()
        asymmetricView.backgroundColor = .systemTeal
        asymmetricView.layer.cornerRadius = 20
        asymmetricView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMaxYCorner] // Only top-left and bottom-right
        asymmetricView.translatesAutoresizingMaskIntoConstraints = false
        asymmetricView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        let asymmetricContainer = createLabeledContainer(title: "Asymmetric Corners (top-left, bottom-right only)", view: asymmetricView)
        contentStackView.addArrangedSubview(asymmetricContainer)

        // MARK: - Collection View Cells (ColorCollectionViewCell-style)
        addSectionHeader("📱 Collection View Cells (ColorCollectionViewCell Fix Test)")

        // Test ColorCollectionViewCell-style views
        let collectionCellTest1 = createColorCollectionViewCellTest(cornerRadius: 8, color: .systemRed, text: "8px")
        let collectionCellContainer1 = createLabeledContainer(title: "ColorCollectionViewCell Style (8px) - Should show 8px", view: collectionCellTest1)
        contentStackView.addArrangedSubview(collectionCellContainer1)

        let collectionCellTest2 = createColorCollectionViewCellTest(cornerRadius: 12, color: .systemBlue, text: "12px")
        let collectionCellContainer2 = createLabeledContainer(title: "ColorCollectionViewCell Style (12px) - Should show 12px", view: collectionCellTest2)
        contentStackView.addArrangedSubview(collectionCellContainer2)

        let collectionCellTest3 = createColorCollectionViewCellTest(cornerRadius: 16, color: .systemGreen, text: "16px")
        let collectionCellContainer3 = createLabeledContainer(title: "ColorCollectionViewCell Style (16px) - Should show 16px", view: collectionCellTest3)
        contentStackView.addArrangedSubview(collectionCellContainer3)

        // Test exact ColorCollectionViewCell reproduction
        let exactReproduction = createExactColorCollectionViewCellReproduction()
        let exactContainer = createLabeledContainer(title: "EXACT ColorCollectionViewCell Reproduction (layer.cornerRadius = 8)", view: exactReproduction)
        contentStackView.addArrangedSubview(exactContainer)

        // MARK: - Real-world Examples
        addSectionHeader("🌍 Real-world Examples")

        // iOS Settings-style cell
        let settingsCell = createSettingsStyleCell()
        let settingsCell2 = createSettingsStyleCell()

        let settingsCellContainer = createLabeledContainer(title: "iOS Settings Cell Style", view: settingsCell, view2: settingsCell2)
        contentStackView.addArrangedSubview(settingsCellContainer)

        // Modern card design
        let modernCard = createModernCard()
        let modernCardContainer = createLabeledContainer(title: "Modern Card Design", view: modernCard)
        contentStackView.addArrangedSubview(modernCardContainer)
    }

    // MARK: - Helper Methods

    private func addSectionHeader(_ text: String) {
        let header = createLabel(text: text, fontSize: 20, weight: .semibold, color: .label)
        header.textAlignment = .left
        contentStackView.addArrangedSubview(header)
    }

    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private func createCornerExample(title: String, radius: CGFloat, backgroundColor: UIColor) -> UIView {
        let colorView = UIView()
        colorView.backgroundColor = backgroundColor
        colorView.layer.cornerRadius = radius
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        return createLabeledContainer(title: "\(title) - \(Int(radius))px", view: colorView)
    }

    private func createBorderedCornerExample(title: String, radius: CGFloat, borderWidth: CGFloat, borderColor: UIColor) -> UIView {
        let colorView = UIView()
        colorView.backgroundColor = .systemBackground
        colorView.layer.cornerRadius = radius
        colorView.layer.borderWidth = borderWidth
        colorView.layer.borderColor = borderColor.cgColor
        colorView.translatesAutoresizingMaskIntoConstraints = false
        colorView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        return createLabeledContainer(title: "\(title) - \(Int(radius))px, \(Int(borderWidth))px border", view: colorView)
    }

    private func createRoundedButton(title: String, radius: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = radius
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        return button
    }
    private func createLabeledContainer(title: String, view: UIView) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let titleLabel = createLabel(text: title, fontSize: 16, weight: .medium, color: .secondaryLabel)
        titleLabel.textAlignment = .left

        let stackView = UIStackView(arrangedSubviews: [titleLabel, view])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }
    private func createLabeledContainer(title: String, view: UIView, view2: UIView) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let titleLabel = createLabel(text: title, fontSize: 16, weight: .medium, color: .secondaryLabel)
        titleLabel.textAlignment = .left

        let stackView = UIStackView(arrangedSubviews: [titleLabel, view, view2])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    private func createNestedRoundedViews() -> UIView {
        let outerView = UIView()
        outerView.backgroundColor = .systemGray5
        outerView.layer.cornerRadius = 16
        outerView.translatesAutoresizingMaskIntoConstraints = false

        let innerView = UIView()
        innerView.backgroundColor = .systemBlue
        innerView.layer.cornerRadius = 8
        innerView.translatesAutoresizingMaskIntoConstraints = false

        outerView.addSubview(innerView)
        NSLayoutConstraint.activate([
            outerView.heightAnchor.constraint(equalToConstant: 100),
            innerView.centerXAnchor.constraint(equalTo: outerView.centerXAnchor),
            innerView.centerYAnchor.constraint(equalTo: outerView.centerYAnchor),
            innerView.widthAnchor.constraint(equalTo: outerView.widthAnchor, multiplier: 0.6),
            innerView.heightAnchor.constraint(equalTo: outerView.heightAnchor, multiplier: 0.6)
        ])

        return outerView
    }

    private func createCardWithContent() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = createLabel(text: "Card Title", fontSize: 18, weight: .semibold, color: .label)
        let subtitleLabel = createLabel(text: "This is a card with content and 12px corner radius", fontSize: 14, weight: .regular, color: .secondaryLabel)

        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        cardView.addSubview(stackView)
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 80),
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])

        return cardView
    }

    private func createCollectionViewCellStyle(cornerRadius: CGFloat, color: UIColor, text: String) -> UIView {
        let cellView = UIView()
        cellView.backgroundColor = color
        cellView.layer.cornerRadius = cornerRadius
        cellView.clipsToBounds = true
        cellView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        cellView.addSubview(label)
        NSLayoutConstraint.activate([
            cellView.heightAnchor.constraint(equalToConstant: 80),
            cellView.widthAnchor.constraint(equalToConstant: 80),
            label.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    private func createColorCollectionViewCellTest(cornerRadius: CGFloat, color: UIColor, text: String) -> UIView {
        // Create a view that mimics ColorCollectionViewCell behavior
        let cellView = UIView()
        cellView.backgroundColor = color
        cellView.layer.cornerRadius = cornerRadius
        cellView.clipsToBounds = true
        cellView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        cellView.addSubview(label)
        NSLayoutConstraint.activate([
            cellView.heightAnchor.constraint(equalToConstant: 80),
            cellView.widthAnchor.constraint(equalToConstant: 80),
            label.centerXAnchor.constraint(equalTo: cellView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])

        return cellView
    }

    private func createExactColorCollectionViewCellReproduction() -> UIView {
        // Exact reproduction of ColorCollectionViewCell logic
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Create the actual test cell
        let testCell = TestColorCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        testCell.backgroundColor = UIColor(hue: 0.3, saturation: 0.8, brightness: 0.8, alpha: 1.0)
        testCell.configure(with: 42)
        testCell.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(testCell)
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 120),
            testCell.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            testCell.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            testCell.widthAnchor.constraint(equalToConstant: 100),
            testCell.heightAnchor.constraint(equalToConstant: 100)
        ])

        return containerView
    }

    private func createSettingsStyleCell() -> UIView {
        let cellView = UIView()
        cellView.backgroundColor = .secondarySystemBackground
        cellView.layer.cornerRadius = 10
        cellView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIView()
        iconView.backgroundColor = .systemBlue
        iconView.layer.cornerRadius = 6
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = createLabel(text: "Settings Option", fontSize: 16, weight: .regular, color: .label)
        titleLabel.textAlignment = .left

        let disclosureImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        disclosureImageView.tintColor = .tertiaryLabel
        disclosureImageView.translatesAutoresizingMaskIntoConstraints = false

        cellView.addSubview(iconView)
        cellView.addSubview(titleLabel)
        cellView.addSubview(disclosureImageView)

        NSLayoutConstraint.activate([
            cellView.heightAnchor.constraint(equalToConstant: 50),

            iconView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),

            disclosureImageView.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -16),
            disclosureImageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 8),
            disclosureImageView.heightAnchor.constraint(equalToConstant: 12)
        ])

        return cellView
    }

    private func createModernCard() -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.15
        cardView.translatesAutoresizingMaskIntoConstraints = false

        let headerView = UIView()
        headerView.backgroundColor = .systemBlue
        headerView.layer.cornerRadius = 12
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner] // Top corners only
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let headerLabel = createLabel(text: "Modern Card", fontSize: 18, weight: .bold, color: .white)
        headerView.addSubview(headerLabel)

        let bodyLabel = createLabel(text: "This card uses 16px corner radius with partial rounding on the header", fontSize: 14, weight: .regular, color: .label)
        bodyLabel.textAlignment = .left
        bodyLabel.numberOfLines = 0

        cardView.addSubview(headerView)
        cardView.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 120),

            headerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            headerLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            bodyLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            bodyLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16)
        ])

        return cardView
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Button Tapped!",
            message: "Corner radius: \(sender.layer.cornerRadius)px",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Track interaction
        NewRelic.recordCustomEvent("UIKitCornerRadiusPlayground",
                                 attributes: [
                                     "action": "button_tap",
                                     "corner_radius": sender.layer.cornerRadius
                                 ])
    }
}

// Test class that exactly replicates ColorCollectionViewCell
class TestColorCollectionViewCell: UICollectionViewCell {
    private let label = UILabel()
    private let blurEffectView: UIVisualEffectView

    override init(frame: CGRect) {
        // Create blur effect
#if os(iOS)
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
#else
        blurEffectView = UIVisualEffectView()
#endif
        super.init(frame: frame)

        // Configure cell appearance - THIS IS THE KEY LINE THAT WAS FAILING
        layer.cornerRadius = 8
        clipsToBounds = true

        // Set up blur effect view
        blurEffectView.frame = contentView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(blurEffectView)

        // Configure label
        label.textAlignment = .center
        label.textColor = .black
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false

#if os(iOS)
        // Add label to the vibrancy effect view for better text rendering on blur
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = blurEffectView.bounds
        vibrancyView.contentView.addSubview(label)
        blurEffectView.contentView.addSubview(vibrancyView)

        // Set up constraints for the label
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vibrancyView.contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vibrancyView.contentView.centerYAnchor),
            vibrancyView.leadingAnchor.constraint(equalTo: blurEffectView.leadingAnchor),
            vibrancyView.trailingAnchor.constraint(equalTo: blurEffectView.trailingAnchor),
            vibrancyView.topAnchor.constraint(equalTo: blurEffectView.topAnchor),
            vibrancyView.bottomAnchor.constraint(equalTo: blurEffectView.bottomAnchor)
        ])
#endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with number: Int) {
        label.text = "\(number)"
    }
}

#endif
