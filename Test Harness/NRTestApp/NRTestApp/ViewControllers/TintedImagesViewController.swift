//
//  TintedImagesViewController.swift
//  NRTestApp
//
//  Created for testing tinted UIImageView symbols
//

import UIKit
import NewRelic

class TintedImagesViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Tinted UIImageViews"
        view.backgroundColor = .systemBackground

        setupScrollView()
        createTintedImageViews()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func createTintedImageViews() {
        var yPosition: CGFloat = 20

        // Blue Tints
        yPosition = addSection(title: "Blue Tints", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["chevron.left", "heart.fill", "star.fill", "bookmark.fill"],
            tintColor: .systemBlue,
            yPosition: yPosition
        )

        // Red Tints
        yPosition = addSection(title: "Red Tints", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["heart.fill", "exclamationmark.triangle.fill", "trash.fill", "xmark.circle.fill"],
            tintColor: .systemRed,
            yPosition: yPosition
        )

        // Green Tints
        yPosition = addSection(title: "Green Tints", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["checkmark.circle.fill", "leaf.fill", "plus.circle.fill", "checkmark.seal.fill"],
            tintColor: .systemGreen,
            yPosition: yPosition
        )

        // Purple Tints
        yPosition = addSection(title: "Purple Tints", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["moon.stars.fill", "crown.fill", "sparkles", "star.circle.fill"],
            tintColor: .systemPurple,
            yPosition: yPosition
        )

        // Orange Tints
        yPosition = addSection(title: "Orange Tints", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["flame.fill", "sun.max.fill", "bell.fill", "bolt.fill"],
            tintColor: .systemOrange,
            yPosition: yPosition
        )

        // Template Rendering Mode Explicitly Set
        yPosition = addSection(title: "Template Mode (Explicit)", yPosition: yPosition)
        yPosition = addImageRowWithTemplateMode(
            symbols: ["pencil", "folder", "paperplane", "house"],
            tintColor: .systemIndigo,
            yPosition: yPosition
        )

        // Custom Colors
        yPosition = addSection(title: "Custom Colors", yPosition: yPosition)
        yPosition = addImageRow(
            symbols: ["paintbrush.fill", "wand.and.stars", "circle.hexagongrid.fill", "square.stack.3d.up.fill"],
            tintColor: UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0),
            yPosition: yPosition
        )

        // Set content view height
        contentView.heightAnchor.constraint(equalToConstant: yPosition + 20).isActive = true
    }

    private func addSection(title: String, yPosition: CGFloat) -> CGFloat {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yPosition),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20)
        ])

        return yPosition + 40
    }

    private func addImageRow(symbols: [String], tintColor: UIColor, yPosition: CGFloat) -> CGFloat {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 10

        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yPosition),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.heightAnchor.constraint(equalToConstant: 80)
        ])

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])

        for symbolName in symbols {
            let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            let image = UIImage(systemName: symbolName, withConfiguration: config)

            let imageView = UIImageView(image: image)
            imageView.tintColor = tintColor
            imageView.contentMode = .scaleAspectFit

            stackView.addArrangedSubview(imageView)
        }

        return yPosition + 100
    }

    private func addImageRowWithTemplateMode(symbols: [String], tintColor: UIColor, yPosition: CGFloat) -> CGFloat {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 10

        contentView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yPosition),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            containerView.heightAnchor.constraint(equalToConstant: 80)
        ])

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 15),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -15)
        ])

        for symbolName in symbols {
            let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            let image = UIImage(systemName: symbolName, withConfiguration: config)?
                .withRenderingMode(.alwaysTemplate)

            let imageView = UIImageView(image: image)
            imageView.tintColor = tintColor
            imageView.contentMode = .scaleAspectFit

            stackView.addArrangedSubview(imageView)
        }

        return yPosition + 100
    }
}
