//
//  UtilitiesViewController.swift
//  NRTestApp
//
//  Created by Chris Dillard on 5/30/25
//

import UIKit

class TextMaskingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var viewModel = TextMaskingViewModel()

    let data = [("Title 1", "Subtitle 1"), ("Title 2", "Subtitle 2"), ("Title 3", "Subtitle 3")]


    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.title = "Text Masking"
        self.view.backgroundColor = .systemBackground

        let searchAndCredentialsStack = createSearchAndCredentialsSection()
        let maskedStack = createSectionStack(title: "Masked Fields", isMasked: true, isCustom: false)
        let unmaskedStack = createSectionStack(title: "Unmasked Fields", isMasked: false, isCustom: false)
        
        let customMaskedStack = createSectionStack(title: "Custom Masked Fields", isMasked: true, isCustom: true)
        let customUnmaskedStack = createSectionStack(title: "Custom Unmasked Fields", isMasked: false, isCustom: true)
        
        let parentChildStack = createParentChildSection()

        let tableViewStack = createTableViewSection()

        let scrollView = UIScrollView()
        let mainStack = UIStackView(arrangedSubviews: [searchAndCredentialsStack, maskedStack, unmaskedStack, customMaskedStack, customUnmaskedStack, parentChildStack, tableViewStack])
//        let mainStack = UIStackView(arrangedSubviews: [maskedStack, parentChildStack])
//        let mainStack = UIStackView(arrangedSubviews: [maskedStack])//, parentChildStack])

        mainStack.axis = .vertical
        mainStack.spacing = 32
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = true

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
            mainStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            mainStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func createSectionStack(title: String, isMasked: Bool, isCustom: Bool) -> UIStackView {
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
            if isCustom {
                label.accessibilityIdentifier = isMasked ? "private" : "public"
            } else {
                label.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"
            }
            //             label.accessibilityIdentifier = isMasked ? "nr-masked-label-\(i)" : "nr-unmasked-label-\(i)"

            fieldsStack.addArrangedSubview(label)
        }
        // UITextFields
        for i in 1...4 {
            let textField = UITextField()
            textField.borderStyle = .roundedRect
            textField.placeholder = "\(title) UITextField \(i)"
            //textField.accessibilityIdentifier = isMasked ? "nr-mask-textfield-\(i)" : "nr-unmask-textfield-\(i)"
            if isCustom {
                textField.accessibilityIdentifier = isMasked ? "private" : "public"
            } else {
                textField.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"
            }
            fieldsStack.addArrangedSubview(textField)
        }
        // UITextViews
        for i in 1...4 {
            let textView = UITextView()
            textView.text = "\(title) UITextView \(i)"
            textView.layer.borderWidth = 1
            textView.layer.borderColor = UIColor.systemGray4.cgColor
            textView.layer.cornerRadius = 6
            if isCustom {
                textView.accessibilityIdentifier = isMasked ? "private" : "public"
            } else {
                textView.accessibilityIdentifier = isMasked ? "nr-mask" : "nr-unmask"
            }
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


    private func createTableViewSection() -> UIStackView {
        let sectionLabel = UILabel()
        sectionLabel.text = "TableView Masking Test"
        sectionLabel.font = .boldSystemFont(ofSize: 18)

        // Create a container for the tableview with proper label
        let tableViewContainer = UIView()
        tableViewContainer.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = "Testing masking propagation in TableView hierarchy"
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        // Create the tableview with masking identifier
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(MaskTestTableViewCell.self, forCellReuseIdentifier: "MaskTestCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 80
        tableView.accessibilityIdentifier = "nr-mask"
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemBlue.cgColor
        tableView.layer.cornerRadius = 8

        // Add views to container
        tableViewContainer.addSubview(descriptionLabel)
        tableViewContainer.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableViewContainer.heightAnchor.constraint(equalToConstant: 300),

            descriptionLabel.topAnchor.constraint(equalTo: tableViewContainer.topAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: tableViewContainer.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: tableViewContainer.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: tableViewContainer.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: tableViewContainer.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: tableViewContainer.bottomAnchor)
        ])

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, tableViewContainer])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MaskTestCell", for: indexPath) as? MaskTestTableViewCell else {
            return UITableViewCell()
        }
        let (title, subtitle) = data[indexPath.row]
        cell.titleLabel.text = title
        cell.subtitleLabel.text = subtitle
        return cell
    }

    // UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("Selected row at \(indexPath.row)")
    }


    private func createSearchAndCredentialsSection() -> UIStackView {
        let sectionLabel = UILabel()
        sectionLabel.text = "Search & Credentials Fields"
        sectionLabel.font = .boldSystemFont(ofSize: 18)

        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 12

        // Search Bar
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search query (masked)"
        searchBar.accessibilityIdentifier = "nr-mask"
        fieldsStack.addArrangedSubview(searchBar)

        // Username TextField
        let usernameField = UITextField()
        usernameField.borderStyle = .roundedRect
        usernameField.placeholder = "Username (unmasked)"
        usernameField.accessibilityIdentifier = "nr-unmask"
        fieldsStack.addArrangedSubview(usernameField)

        // Password TextField
        let passwordField = UITextField()
        passwordField.borderStyle = .roundedRect
        passwordField.placeholder = "Password (masked)"
        passwordField.isSecureTextEntry = true
        passwordField.accessibilityIdentifier = "nr-mask"
        fieldsStack.addArrangedSubview(passwordField)

        // Credit Card Number TextField
        let cardNumberField = UITextField()
        cardNumberField.borderStyle = .roundedRect
        cardNumberField.placeholder = "Credit Card Number (masked)"
        cardNumberField.keyboardType = .numberPad
        cardNumberField.accessibilityIdentifier = "nr-mask"
        fieldsStack.addArrangedSubview(cardNumberField)

        // CVV TextField
        let cvvField = UITextField()
        cvvField.borderStyle = .roundedRect
        cvvField.placeholder = "CVV (masked)"
        cvvField.keyboardType = .numberPad
        cvvField.isSecureTextEntry = true
        cvvField.accessibilityIdentifier = "nr-mask"
        fieldsStack.addArrangedSubview(cvvField)

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, fieldsStack])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
    }
}

class MaskTestTableViewCell: UITableViewCell {
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let accessoryButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // Configure titleLabel
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Configure subtitleLabel
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .gray
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // Configure accessoryButton
        accessoryButton.setTitle("Action", for: .normal)
        accessoryButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(accessoryButton)

        // Add constraints
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: accessoryButton.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

            accessoryButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            accessoryButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
