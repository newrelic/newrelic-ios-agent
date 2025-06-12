//
//  UtilitiesViewController.swift
//  NRTestApp
//
//  Created by Chris Dillard on 5/30/25
//

import UIKit

class TextMaskingViewController: UIViewController {
    var viewModel = TextMaskingViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.title = "Text Masking"
        self.view.backgroundColor = .systemBackground
        let maskedStack = createSectionStack(title: "Masked Fields", isMasked: true)
        let unmaskedStack = createSectionStack(title: "Unmasked Fields", isMasked: false)
        let parentChildStack = createParentChildSection()

        let scrollView = UIScrollView()
        let mainStack = UIStackView(arrangedSubviews: [maskedStack, unmaskedStack, parentChildStack])
//        let mainStack = UIStackView(arrangedSubviews: [maskedStack, parentChildStack])
//        let mainStack = UIStackView(arrangedSubviews: [maskedStack])//, parentChildStack])

        mainStack.axis = .vertical
        mainStack.spacing = 32
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(mainStack)

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            mainStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            mainStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])
    }

    private func createSectionStack(title: String, isMasked: Bool) -> UIStackView {
        let sectionLabel = UILabel()
        sectionLabel.text = title
        sectionLabel.font = .boldSystemFont(ofSize: 18)

        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 12

        // UILabels
        for i in 1...4 {
            let label = UILabel()
            label.text = "\(title) UILabel \(i)"
            label.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"

            //             label.accessibilityIdentifier = isMasked ? "nr-masked-label-\(i)" : "nr-unmasked-label-\(i)"

            fieldsStack.addArrangedSubview(label)
        }
        // UITextFields
        for i in 1...4 {
            let textField = UITextField()
            textField.borderStyle = .roundedRect
            textField.placeholder = "\(title) UITextField \(i)"
            //textField.accessibilityIdentifier = isMasked ? "nr-mask-textfield-\(i)" : "nr-unmask-textfield-\(i)"
            textField.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"

            fieldsStack.addArrangedSubview(textField)
        }
        // UITextViews
        for i in 1...4 {
            let textView = UITextView()
            textView.text = "\(title) UITextView \(i)"
            textView.layer.borderWidth = 1
            textView.layer.borderColor = UIColor.systemGray4.cgColor
            textView.layer.cornerRadius = 6
            textView.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"
            // textView.accessibilityIdentifier = isMasked ? "nr-mask-textview-\(i)" : "nr-unmask-textview-\(i)"

            textView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            fieldsStack.addArrangedSubview(textView)
        }

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, fieldsStack])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
    }

    private func createParentChildSection() -> UIStackView {
        let sectionLabel = UILabel()
        sectionLabel.text = "Parent-Child Relationship"
        sectionLabel.font = .boldSystemFont(ofSize: 18)

        // Create parent container views
        let maskedParentView = createParentView(isMasked: true)
        let unmaskedParentView = createParentView(isMasked: false)

        let descriptionLabel = UILabel()
        descriptionLabel.text = "Testing masked accessibility identifier propagation to child views"
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel

        let containerStack = UIStackView(arrangedSubviews: [descriptionLabel, maskedParentView, unmaskedParentView])
        containerStack.axis = .vertical
        containerStack.spacing = 16

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, containerStack])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
    }

    private func createParentView(isMasked: Bool) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = isMasked ? .systemBlue.withAlphaComponent(0.1) : .systemGreen.withAlphaComponent(0.1)
        containerView.layer.cornerRadius = 8
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = isMasked ? UIColor.systemBlue.cgColor : UIColor.systemGreen.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Set accessibility identifier on parent
        containerView.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"
//         containerView.accessibilityIdentifier = isMasked ? "nr-masked-parent-container" : "nr-unmasked-parent-container"

        // Header label for the parent view
        let headerLabel = UILabel()
        headerLabel.text = isMasked ? "Masked Parent View" : "Unmasked Parent View"
        headerLabel.font = .boldSystemFont(ofSize: 16)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Child views that should inherit masking
        let childStack = UIStackView()
        childStack.axis = .vertical
        childStack.spacing = 8
        childStack.translatesAutoresizingMaskIntoConstraints = false

        // Add various child elements
        for i in 1...3 {
            // Add a label
            let label = UILabel()
            label.text = "Child Label \(i)"
            label.accessibilityIdentifier = "child-label-\(i)"
            childStack.addArrangedSubview(label)

            // Add a button
            let button = UIButton(type: .system)
            button.setTitle("Child Button \(i)", for: .normal)
            button.accessibilityIdentifier = "child-button-\(i)"
            childStack.addArrangedSubview(button)

            if i == 2 {
                // Add a nested container to test deep hierarchy
                let nestedContainer = UIView()
                nestedContainer.backgroundColor = .systemGray6
                nestedContainer.layer.cornerRadius = 4
                nestedContainer.accessibilityIdentifier = "nested-container-\(i)"

                let nestedLabel = UILabel()
                nestedLabel.text = "Nested Child Label"
                nestedLabel.accessibilityIdentifier = "nested-child-label"
                nestedLabel.translatesAutoresizingMaskIntoConstraints = false

                nestedContainer.addSubview(nestedLabel)

                NSLayoutConstraint.activate([
                    nestedLabel.topAnchor.constraint(equalTo: nestedContainer.topAnchor, constant: 8),
                    nestedLabel.leadingAnchor.constraint(equalTo: nestedContainer.leadingAnchor, constant: 8),
                    nestedLabel.trailingAnchor.constraint(equalTo: nestedContainer.trailingAnchor, constant: -8),
                    nestedLabel.bottomAnchor.constraint(equalTo: nestedContainer.bottomAnchor, constant: -8)
                ])

                childStack.addArrangedSubview(nestedContainer)

                // Set a height constraint for the nested container
                nestedContainer.heightAnchor.constraint(equalToConstant: 40).isActive = true
            }
        }

        containerView.addSubview(headerLabel)
        containerView.addSubview(childStack)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),

            headerLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            headerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),

            childStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 12),
            childStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            childStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            childStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])

        return containerView
    }
}
