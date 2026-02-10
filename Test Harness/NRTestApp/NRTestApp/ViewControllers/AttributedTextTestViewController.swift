//
//  AttributedTextTestViewController.swift
//  NRTestApp
//
//  Created for testing Session Replay text rendering
//

import UIKit

class AttributedTextTestViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var timer: Timer?
    private var timerLabel: UILabel?
    private var elapsedSeconds: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Attributed Text Test"

        setupScrollView()
        setupStackView()
        addTestViews()
        startTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedSeconds += 1
            self.updateTimerLabel()
        }
    }

    private func updateTimerLabel() {
        let minutes = elapsedSeconds / 600
        let seconds = (elapsedSeconds / 10) % 60
        let deciseconds = elapsedSeconds % 10

        let timeString = String(format: "%02d:%02d.%d", minutes, seconds, deciseconds)

        let attributedText = NSMutableAttributedString()
        attributedText.append(NSAttributedString(
            string: "Timer: ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
        ))
        attributedText.append(NSAttributedString(
            string: timeString,
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
        ))

        timerLabel?.attributedText = attributedText
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true

        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func addTestViews() {
        // Timer label that updates quickly
        addSectionHeader("UILabel - Timer (updates 10x per second)")
        let label = UILabel()
        label.numberOfLines = 0
        label.attributedText = NSAttributedString(string: "Timer: 00:00.0")
        timerLabel = label
        stackView.addArrangedSubview(label)
        updateTimerLabel()

        // UILabel with multiline, mixed fonts, colors, spacing
        addSectionHeader("UILabel - Multiline with Mixed Formatting")
        stackView.addArrangedSubview(createComplexLabel1())

        // UILabel with letter spacing and line spacing
        addSectionHeader("UILabel - Custom Spacing")
        stackView.addArrangedSubview(createComplexLabel2())

        // UILabel with bold, italic, and underline
        addSectionHeader("UILabel - Bold, Italic, Styles")
        stackView.addArrangedSubview(createComplexLabel3())

        // UITextField with attributed placeholder and text
        addSectionHeader("UITextField - Attributed Text")
        stackView.addArrangedSubview(createComplexTextField())

        // UITextView with complex attributed text
        addSectionHeader("UITextView - Complex Formatting")
        stackView.addArrangedSubview(createComplexTextView())

        // UILabel with word wrapping test
        addSectionHeader("UILabel - Word Wrapping (numberOfLines=0)")
        stackView.addArrangedSubview(createWordWrappingLabel())

        // UILabel with truncation test
        addSectionHeader("UILabel - Truncation (numberOfLines=2)")
        stackView.addArrangedSubview(createTruncatingLabel())
    }

    private func addSectionHeader(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        stackView.addArrangedSubview(label)
    }

    private func createComplexLabel1() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0

        let text = NSMutableAttributedString()

        // Large red bold text
        let part1 = NSAttributedString(
            string: "Large Bold Red Text\n",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.systemRed
            ]
        )

        // Regular text with custom line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        paragraphStyle.alignment = .left

        let part2 = NSAttributedString(
            string: "This is normal text with increased line spacing. ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
        )

        // Small green italic text
        let part3 = NSAttributedString(
            string: "And this is small italic green text.",
            attributes: [
                .font: UIFont.italicSystemFont(ofSize: 14),
                .foregroundColor: UIColor.systemGreen
            ]
        )

        text.append(part1)
        text.append(part2)
        text.append(part3)

        label.attributedText = text
        return label
    }

    private func createComplexLabel2() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10
        paragraphStyle.paragraphSpacing = 15
        paragraphStyle.alignment = .center

        let text = NSMutableAttributedString(
            string: "Text with custom letter spacing and line spacing\nSecond line with same formatting",
            attributes: [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.systemBlue,
                .kern: 2.0, // Letter spacing
                .paragraphStyle: paragraphStyle
            ]
        )

        label.attributedText = text
        return label
    }

    private func createComplexLabel3() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0

        let text = NSMutableAttributedString()

        // Bold text
        let bold = NSAttributedString(
            string: "Bold ",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
        )

        // Italic text
        let italic = NSAttributedString(
            string: "Italic ",
            attributes: [
                .font: UIFont.italicSystemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
        )

        // Bold + Italic
        let boldItalic: UIFont
        if let descriptor = UIFont.systemFont(ofSize: 16).fontDescriptor
            .withSymbolicTraits([.traitBold, .traitItalic]) {
            boldItalic = UIFont(descriptor: descriptor, size: 16)
        } else {
            boldItalic = UIFont.boldSystemFont(ofSize: 16)
        }

        let boldItalicText = NSAttributedString(
            string: "Bold+Italic ",
            attributes: [
                .font: boldItalic,
                .foregroundColor: UIColor.label
            ]
        )

        // Regular with different weights
        let light = NSAttributedString(
            string: "Light ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .light),
                .foregroundColor: UIColor.label
            ]
        )

        let heavy = NSAttributedString(
            string: "Heavy",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .heavy),
                .foregroundColor: UIColor.label
            ]
        )

        text.append(bold)
        text.append(italic)
        text.append(boldItalicText)
        text.append(light)
        text.append(heavy)

        label.attributedText = text
        return label
    }

    private func createComplexTextField() -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground

        // Attributed placeholder
        let placeholderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 14),
            .foregroundColor: UIColor.systemGray,
            .kern: 1.0
        ]
        textField.attributedPlaceholder = NSAttributedString(
            string: "Type something...",
            attributes: placeholderAttrs
        )

        // Attributed text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.systemPurple,
            .kern: 0.5
        ]
        textField.attributedText = NSAttributedString(
            string: "Pre-filled attributed text",
            attributes: textAttrs
        )

        textField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return textField
    }

    private func createComplexTextView() -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let text = NSMutableAttributedString()

        // Title
        let paragraphStyle1 = NSMutableParagraphStyle()
        paragraphStyle1.alignment = .center
        paragraphStyle1.paragraphSpacing = 10

        let title = NSAttributedString(
            string: "UITextView Title\n",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.systemIndigo,
                .paragraphStyle: paragraphStyle1
            ]
        )

        // Body with line spacing
        let paragraphStyle2 = NSMutableParagraphStyle()
        paragraphStyle2.lineSpacing = 6
        paragraphStyle2.alignment = .justified

        let body = NSAttributedString(
            string: "This UITextView contains multiple paragraphs with different formatting. ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle2
            ]
        )

        // Emphasized text
        let emphasized = NSAttributedString(
            string: "This part is emphasized ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: UIColor.systemOrange,
                .kern: 1.5
            ]
        )

        // More body
        let body2 = NSAttributedString(
            string: "and this is regular again with mixed colors and styles.\n\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraphStyle2
            ]
        )

        // Footer
        let footer = NSAttributedString(
            string: "— End of test text —",
            attributes: [
                .font: UIFont.italicSystemFont(ofSize: 13),
                .foregroundColor: UIColor.secondaryLabel,
                .kern: 2.0
            ]
        )

        text.append(title)
        text.append(body)
        text.append(emphasized)
        text.append(body2)
        text.append(footer)

        textView.attributedText = text
        textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        return textView
    }

    private func createWordWrappingLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        label.attributedText = NSAttributedString(
            string: "This is a long label with numberOfLines set to 0 (unlimited) and lineBreakMode set to byWordWrapping. It should wrap to multiple lines as needed without cutting off any text. The browser should render this similarly to iOS.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
                .kern: 0.3,
                .paragraphStyle: paragraphStyle
            ]
        )

        return label
    }

    private func createTruncatingLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        label.attributedText = NSAttributedString(
            string: "This label has numberOfLines set to 2 with truncating tail mode. If the text is longer than two lines, it should show an ellipsis (...) at the end. This tests the truncation behavior in session replay.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
                .kern: 0.3,
                .paragraphStyle: paragraphStyle
            ]
        )

        return label
    }
}
