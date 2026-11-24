//
//  UtilitiesViewController.swift
//  NRTestApp
//
//  Created by Chris Dillard on 5/30/25
//

import UIKit
import SwiftUI
import NewRelic

#if os(iOS)

class TextMaskingViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var viewModel = TextMaskingViewModel()

    let data = [("Title 1", "Subtitle 1"), ("Title 2", "Subtitle 2"), ("Title 3", "Subtitle 3")]


    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.title = "Text Masking"
        self.view.backgroundColor = .systemBackground

        let blockedStack = createBlockedSection()
        let searchAndCredentialsStack = createSearchAndCredentialsSection()
        let maskedStack = createSectionStack(title: "Masked Fields", isMasked: true, isCustom: false)
        let unmaskedStack = createSectionStack(title: "Unmasked Fields", isMasked: false, isCustom: false)
        
        let customMaskedStack = createSectionStack(title: "Custom Masked Fields", isMasked: true, isCustom: true)
        let customUnmaskedStack = createSectionStack(title: "Custom Unmasked Fields", isMasked: false, isCustom: true)
        
        let parentChildStack = createParentChildSection()
        let inheritanceStack = createInheritanceMatrixSection()
        let perPropertyStack = createPerPropertySection()
        let multiLevelStack = createMultiLevelSection()
        let blockCombinationsStack = createBlockCombinationsSection()
        let swiftUIInUIKitStack = createSwiftUIInUIKitSection()
        let textVsInputStack = createTextVersusInputSection()
        let childRulesStack = createSwiftUIChildRulesSection()
        let textVsOtherStack = createTextVersusImagesSection()

        let tableViewStack = createTableViewSection()

        let scrollView = UIScrollView()
        let mainStack = UIStackView(arrangedSubviews: [blockedStack, searchAndCredentialsStack, maskedStack, unmaskedStack, customMaskedStack, customUnmaskedStack, parentChildStack, inheritanceStack, perPropertyStack, multiLevelStack, blockCombinationsStack, swiftUIInUIKitStack, childRulesStack, textVsInputStack, textVsOtherStack, tableViewStack])
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


    // MARK: - Inheritance combinations
    //
    // Rule under test: a masked ancestor always wins, a child can add masking inside an
    // unmasked parent, and unset children inherit. Expectations assume the Custom strategy;
    // under Default everything is masked. "list" uses the "private" / "public" identifiers,
    // which are only honored when they are in the masked / unmasked lists.

    private enum MaskMechanism: String, CaseIterable {
        case tag       // nr-mask / nr-unmask accessibility identifiers
        case list      // "private" / "public" identifiers from the local lists
        case property  // maskApplicationText / maskUserInputText direct sets

        func apply(to view: UIView, masked: Bool) {
            switch self {
            case .tag:
                view.accessibilityIdentifier = masked ? "nr-mask" : "nr-unmask"
            case .list:
                view.accessibilityIdentifier = masked ? "private" : "public"
            case .property:
                view.maskApplicationText = masked
                view.maskUserInputText = masked
            }
        }
    }

    private func sectionHeader(_ title: String, description: String) -> [UIView] {
        let sectionLabel = UILabel()
        sectionLabel.text = title
        sectionLabel.font = .boldSystemFont(ofSize: 18)
        sectionLabel.numberOfLines = 0

        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.numberOfLines = 0
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        return [sectionLabel, descriptionLabel]
    }

    private func sectionStack(_ arranged: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }

    private func makeContainer(color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 6
        container.layer.borderWidth = 1
        container.layer.borderColor = color.cgColor
        return container
    }

    // Masked rows are blue, unmasked rows are green.
    private func expectationColor(masked: Bool) -> UIColor {
        return masked ? .systemBlue : .systemGreen
    }

    private func makeLabel(_ text: String, expectMasked: Bool? = nil) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.numberOfLines = 0
        if let expectMasked = expectMasked {
            label.textColor = expectationColor(masked: expectMasked)
        }
        return label
    }

    // Pins `child` inside `parent` with a uniform inset.
    private func embed(_ child: UIView, in parent: UIView, inset: CGFloat = 8) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }

    // Every pairing of parent/child mechanism and state. A label is masked when either the
    // parent or the child masks it.
    private func createInheritanceMatrixSection() -> UIStackView {
        var rows = sectionHeader("Inheritance Matrix",
                                 description: "Parent mechanism/state x child mechanism/state. Expect masked if parent OR child is masked.")
        for parentMechanism in MaskMechanism.allCases {
            for childMechanism in MaskMechanism.allCases {
                for parentMasked in [true, false] {
                    for childMasked in [true, false] {
                        let expectMasked = parentMasked || childMasked
                        let container = makeContainer(color: expectationColor(masked: expectMasked))
                        parentMechanism.apply(to: container, masked: parentMasked)

                        let expected = expectMasked ? "masked" : "unmasked"
                        let label = makeLabel("P:\(parentMechanism.rawValue)-\(parentMasked ? "M" : "U") > C:\(childMechanism.rawValue)-\(childMasked ? "M" : "U") (expect \(expected))", expectMasked: expectMasked)
                        childMechanism.apply(to: label, masked: childMasked)
                        embed(label, in: container)
                        rows.append(container)
                    }
                }
            }
        }
        // Parent set, child untagged: the child inherits.
        for mechanism in MaskMechanism.allCases {
            for masked in [true, false] {
                let container = makeContainer(color: expectationColor(masked: masked))
                mechanism.apply(to: container, masked: masked)
                let label = makeLabel("P:\(mechanism.rawValue)-\(masked ? "M" : "U") > C:unset (expect \(masked ? "masked" : "unmasked"))", expectMasked: masked)
                embed(label, in: container)
                rows.append(container)
            }
        }
        return sectionStack(rows)
    }

    // Parent masks every property; the child unmasks one (or the reverse). Only the
    // properties that end up masked should be hidden.
    private func createPerPropertySection() -> UIStackView {
        var rows = sectionHeader("Per-Property Inheritance",
                                 description: "Direct maskApplicationText / maskUserInputText / maskAllImages / maskAllUserTouches sets.")

        for parentMasked in [true, false] {
            // Every child property ends up masked: the parent wins when masked, and the
            // child's own mask applies when the parent is unmasked.
            let container = makeContainer(color: expectationColor(masked: true))
            container.maskApplicationText = parentMasked
            container.maskUserInputText = parentMasked
            container.maskAllImages = parentMasked
            container.maskAllUserTouches = parentMasked

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 6

            let title = makeLabel(parentMasked ? "Parent masks all four; child flips ONE (expect all masked)"
                                               : "Parent unmasks all four; child masks ONE (expect only that one masked)")
            title.font = .boldSystemFont(ofSize: 13)
            title.textColor = .label // A heading, not part of the test: no expected outcome.
            stack.addArrangedSubview(title)

            let childValue = !parentMasked

            let textLabel = makeLabel("Child maskApplicationText = \(childValue)", expectMasked: true)
            textLabel.maskApplicationText = childValue
            stack.addArrangedSubview(textLabel)

            let field = UITextField()
            field.borderStyle = .roundedRect
            field.text = "Child maskUserInputText = \(childValue)"
            field.textColor = expectationColor(masked: true)
            field.maskUserInputText = childValue
            stack.addArrangedSubview(field)

            let imageView = UIImageView(image: UIImage(systemName: "star.fill"))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = expectationColor(masked: true)
            imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true
            imageView.maskAllImages = childValue
            stack.addArrangedSubview(imageView)

            let button = UIButton(type: .system)
            button.setTitle("Child maskAllUserTouches = \(childValue)", for: .normal)
            // Under a masked parent the title is masked text. Under an unmasked parent only touches
            // are masked, so the title text stays visible: purple marks touch-only masking.
            button.setTitleColor(parentMasked ? expectationColor(masked: true) : .systemPurple, for: .normal)
            button.maskAllUserTouches = childValue
            stack.addArrangedSubview(button)

            embed(stack, in: container)
            rows.append(container)
        }
        return sectionStack(rows)
    }

    // Three-deep nesting for every masked/unmasked sequence of the three levels, using tags.
    private func createMultiLevelSection() -> UIStackView {
        var rows = sectionHeader("Three-Level Nesting",
                                 description: "L1 > L2 > L3 with nr-mask / nr-unmask tags. L3 is masked if any level is masked.")
        for l1 in [true, false] {
            for l2 in [true, false] {
                for l3 in [true, false] {
                    let expectMasked = l1 || l2 || l3
                    let outer = makeContainer(color: expectationColor(masked: expectMasked))
                    MaskMechanism.tag.apply(to: outer, masked: l1)
                    let middle = makeContainer(color: expectationColor(masked: expectMasked))
                    MaskMechanism.tag.apply(to: middle, masked: l2)
                    let label = makeLabel("L1-\(l1 ? "M" : "U") > L2-\(l2 ? "M" : "U") > L3-\(l3 ? "M" : "U") (expect \(expectMasked ? "masked" : "unmasked"))", expectMasked: expectMasked)
                    MaskMechanism.tag.apply(to: label, masked: l3)
                    embed(label, in: middle)
                    embed(middle, in: outer)
                    rows.append(outer)
                }
            }
        }

        // An untagged middle view must not break inheritance from the grandparent.
        for masked in [true, false] {
            let outer = makeContainer(color: expectationColor(masked: masked))
            MaskMechanism.tag.apply(to: outer, masked: masked)
            let middle = makeContainer(color: expectationColor(masked: masked))
            let label = makeLabel("L1-\(masked ? "M" : "U") > L2 untagged > L3-U (expect \(masked ? "masked" : "unmasked"))", expectMasked: masked)
            MaskMechanism.tag.apply(to: label, masked: false)
            embed(label, in: middle)
            embed(middle, in: outer)
            rows.append(outer)
        }
        return sectionStack(rows)
    }

    // Block always wins over mask/unmask on either side of the relationship.
    private func createBlockCombinationsSection() -> UIStackView {
        var rows = sectionHeader("Block Combinations",
                                 description: "nr-block on a parent blocks the whole subtree regardless of child mask/unmask tags.")
        let cases: [(parent: String, child: String?, text: String)] = [
            ("nr-block", "nr-unmask", "nr-block parent > nr-unmask child (expect blocked)"),
            ("nr-block", "nr-mask", "nr-block parent > nr-mask child (expect blocked)"),
            ("nr-block", nil, "nr-block parent > unset child (expect blocked)"),
            ("nr-mask", "nr-block", "nr-mask parent > nr-block child (expect blocked)"),
            ("nr-unmask", "nr-block", "nr-unmask parent > nr-block child (expect blocked)")
        ]
        for testCase in cases {
            let container = makeContainer(color: .systemRed)
            container.accessibilityIdentifier = testCase.parent
            let label = makeLabel(testCase.text)
            label.accessibilityIdentifier = testCase.child
            embed(label, in: container)
            rows.append(container)
        }
        return sectionStack(rows)
    }

    // A UIHostingController's SwiftUI Text next to a UILabel, both inside a UIKit container that is
    // masked or unmasked by tag, by identifier list, or by a direct property.
    private func createSwiftUIInUIKitSection() -> UIStackView {
        var rows = sectionHeader("SwiftUI Inside a UIKit Parent",
                                 description: "The SwiftUI Text should follow the same masked UIKit ancestor as the UILabel beside it.")

        func hostedText(_ text: String, masked: Bool) -> UIView {
            let host = UIHostingController(rootView: Text(text)
                .font(.footnote)
                .foregroundColor(Color(expectationColor(masked: masked))))
            addChild(host)
            host.view.backgroundColor = .clear
            host.didMove(toParent: self)
            return host.view
        }

        let cases: [(title: String, masked: Bool, configure: (UIView) -> Void)] = [
            ("nr-mask container", true, { $0.accessibilityIdentifier = "nr-mask" }),
            ("masked identifier list container (my-masked-id)", true, { $0.accessibilityIdentifier = "my-masked-id" }),
            ("maskApplicationText = true container", true, { $0.maskApplicationText = true }),
            ("nr-unmask container", false, { $0.accessibilityIdentifier = "nr-unmask" }),
            ("unmasked identifier list container (unmasked-1)", false, { $0.accessibilityIdentifier = "unmasked-1" })
        ]
        for testCase in cases {
            let container = makeContainer(color: expectationColor(masked: testCase.masked))
            testCase.configure(container)
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 4
            stack.addArrangedSubview(makeLabel("UILabel in \(testCase.title) (expect \(testCase.masked ? "masked" : "unmasked"))",
                                               expectMasked: testCase.masked))
            let hosted = hostedText("SwiftUI Text in \(testCase.title) (expect \(testCase.masked ? "masked" : "unmasked"))",
                                    masked: testCase.masked)
            stack.addArrangedSubview(hosted)
            embed(stack, in: container)
            rows.append(container)
        }

        // A SwiftUI child that adds an image mask keeps it under an unmasked UIKit ancestor.
        for (title, identifier) in [("nr-unmask container", "nr-unmask"), ("unmasked identifier list container (unmasked-1)", "unmasked-1")] {
            let container = makeContainer(color: expectationColor(masked: true))
            container.accessibilityIdentifier = identifier
            let maskedColor = Color(expectationColor(masked: true))
            let unmaskedColor = Color(expectationColor(masked: false))
            let host = UIHostingController(rootView: VStack(alignment: .leading, spacing: 4) {
                Text("\(title) > NRConditionalMaskView(maskAllImages: true) > Image")
                    .font(.footnote)
                NRConditionalMaskView(maskAllImages: true) {
                    Image(systemName: "star.fill")
                        .foregroundColor(maskedColor)
                        .font(.title)
                }
                Text("^ star: expect masked (the child adds an image mask)")
                    .font(.footnote)
                NRConditionalMaskView(maskAllImages: false) {
                    Image(systemName: "star.fill")
                        .foregroundColor(unmaskedColor)
                        .font(.title)
                }
                Text("^ star: expect unmasked (no image mask applies)")
                    .font(.footnote)
            })
            addChild(host)
            host.view.backgroundColor = .clear
            host.didMove(toParent: self)
            embed(host.view, in: container)
            rows.append(container)
        }
        return sectionStack(rows)
    }

    // How a UIKit parent is configured for a table row.
    private struct ParentSpec {
        var name: String
        var identifier: String?
        var text: Bool?
        var input: Bool?
        var images: Bool?
    }

    private struct ChildRow {
        var parent: ParentSpec
        var content: HostedChildCase.Content
        var rule: HostedChildCase.Rule
        var expectMasked: Bool
    }

    // Table-driven: a UIKit parent, a hosted SwiftUI element, and the rule (if any) the SwiftUI element
    // adds for itself. Blue is expected masked, green expected visible.
    private func createSwiftUIChildRulesSection() -> UIStackView {
        var rows = sectionHeader("SwiftUI Child Rules in a UIKit Parent",
                                 description: "A UIKit parent above a UIHostingController, with the SwiftUI element adding its own rule.")

        let nrUnmask = ParentSpec(name: "nr-unmask", identifier: "nr-unmask")
        let unmaskedList = ParentSpec(name: "unmasked identifier list (unmasked-1)", identifier: "unmasked-1")
        let nrMask = ParentSpec(name: "nr-mask", identifier: "nr-mask")
        let maskedList = ParentSpec(name: "masked identifier list (my-masked-id)", identifier: "my-masked-id")

        let groups: [(String, [ChildRow])] = [
            ("1. Child adds a mask under an unmasked parent", [nrUnmask, unmaskedList].flatMap { parent in
                [ChildRow(parent: parent, content: .text, rule: .propertyMask, expectMasked: true),
                 ChildRow(parent: parent, content: .input, rule: .propertyMask, expectMasked: true),
                 ChildRow(parent: parent, content: .text, rule: .identifierMask, expectMasked: true)]
            }),
            ("2. Child tries to unmask under a masked parent (parent wins)", [nrMask, maskedList].flatMap { parent in
                [ChildRow(parent: parent, content: .text, rule: .propertyUnmask, expectMasked: true),
                 ChildRow(parent: parent, content: .text, rule: .identifierUnmask, expectMasked: true),
                 ChildRow(parent: parent, content: .image, rule: .propertyUnmask, expectMasked: true)]
            }),
            ("3. Parent masks through a property", [
                ChildRow(parent: ParentSpec(name: "maskAllImages = true", text: nil, input: nil, images: true),
                         content: .image, rule: .none, expectMasked: true),
                ChildRow(parent: ParentSpec(name: "maskAllImages = true", text: nil, input: nil, images: true),
                         content: .image, rule: .propertyUnmask, expectMasked: true),
                ChildRow(parent: ParentSpec(name: "maskApplicationText = true, maskAllImages = false", text: true, input: nil, images: false),
                         content: .text, rule: .none, expectMasked: true),
                ChildRow(parent: ParentSpec(name: "maskApplicationText = true, maskAllImages = false", text: true, input: nil, images: false),
                         content: .image, rule: .none, expectMasked: false),
                ChildRow(parent: ParentSpec(name: "maskUserInputText = true, maskApplicationText = false", text: false, input: true, images: nil),
                         content: .input, rule: .none, expectMasked: true)
            ]),
            ("4. Other hosted content under tags", [
                ChildRow(parent: nrMask, content: .image, rule: .none, expectMasked: true),
                ChildRow(parent: nrMask, content: .input, rule: .none, expectMasked: true),
                ChildRow(parent: nrUnmask, content: .image, rule: .none, expectMasked: false),
                ChildRow(parent: nrUnmask, content: .input, rule: .none, expectMasked: false)
            ])
        ]

        for (title, groupRows) in groups {
            let heading = makeLabel(title)
            heading.font = .boldSystemFont(ofSize: 14)
            heading.maskApplicationText = false
            rows.append(heading)

            for row in groupRows {
                let color = expectationColor(masked: row.expectMasked)
                let kind: String
                switch row.content {
                case .text: kind = "Text"
                case .input: kind = "TextField"
                case .image: kind = "Image"
                }
                let rule: String
                switch row.rule {
                case .none: rule = "no rule"
                case .propertyMask: rule = "property mask"
                case .propertyUnmask: rule = "property unmask"
                case .identifierMask: rule = "masked identifier"
                case .identifierUnmask: rule = "unmasked identifier"
                }
                let text = "\(row.parent.name) > \(kind), \(rule) (expect \(row.expectMasked ? "masked" : "unmasked"))"

                let container = makeContainer(color: color)
                container.accessibilityIdentifier = row.parent.identifier
                container.maskApplicationText = row.parent.text
                container.maskUserInputText = row.parent.input
                container.maskAllImages = row.parent.images

                let host = UIHostingController(rootView: HostedChildCase(content: row.content,
                                                                          rule: row.rule,
                                                                          label: text,
                                                                          color: Color(color)))
                addChild(host)
                host.view.backgroundColor = .clear
                host.didMove(toParent: self)
                embed(host.view, in: container)
                rows.append(container)
            }
        }
        return sectionStack(rows)
    }

    // maskApplicationText covers static text and maskUserInputText covers text inputs; each
    // should only affect its own kind.
    private func createTextVersusInputSection() -> UIStackView {
        var rows = sectionHeader("Application Text vs User Input",
                                 description: "maskApplicationText masks labels, maskUserInputText masks text inputs. Setting one must not mask the other kind.")
        let cases: [(text: Bool, input: Bool)] = [(true, false), (false, true)]
        for testCase in cases {
            let container = makeContainer(color: .systemGray)
            container.maskApplicationText = testCase.text
            container.maskUserInputText = testCase.input
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 6
            let title = makeLabel("Parent maskApplicationText = \(testCase.text), maskUserInputText = \(testCase.input)")
            title.font = .boldSystemFont(ofSize: 13)
            stack.addArrangedSubview(title)
            stack.addArrangedSubview(makeLabel("UILabel (expect \(testCase.text ? "masked" : "unmasked"))", expectMasked: testCase.text))
            let field = UITextField()
            field.borderStyle = .roundedRect
            field.text = "UITextField (expect \(testCase.input ? "masked" : "unmasked"))"
            field.textColor = expectationColor(masked: testCase.input)
            stack.addArrangedSubview(field)
            let textView = UITextView()
            textView.text = "UITextView (expect \(testCase.input ? "masked" : "unmasked"))"
            textView.textColor = expectationColor(masked: testCase.input)
            textView.isScrollEnabled = false
            textView.backgroundColor = .clear
            stack.addArrangedSubview(textView)
            embed(stack, in: container)
            rows.append(container)
        }
        return sectionStack(rows)
    }

    // A mask set for one kind of content must not mask the others: a text-only mask leaves images
    // alone, and an images-only mask leaves text alone.
    private func createTextVersusImagesSection() -> UIStackView {
        var rows = sectionHeader("Text Mask vs Images",
                                 description: "Each parent masks one kind of content. Only that kind should be masked (blue); the rest stays visible (green).")

        struct Case {
            let title: String
            let text: Bool?
            let input: Bool?
            let images: Bool?
        }
        let cases = [
            Case(title: "maskApplicationText true, maskAllImages false, maskUserInputText false", text: true, input: false, images: false),
            Case(title: "maskApplicationText true only (images and input unset)", text: true, input: nil, images: nil),
            Case(title: "maskAllImages true, maskApplicationText false, maskUserInputText false", text: false, input: false, images: true),
            Case(title: "maskUserInputText true, maskApplicationText false, maskAllImages false", text: false, input: true, images: false)
        ]
        for testCase in cases {
            // An unset property falls to the config default, so only an explicit value has an expectation.
            let container = makeContainer(color: .systemGray)
            container.maskApplicationText = testCase.text
            container.maskUserInputText = testCase.input
            container.maskAllImages = testCase.images

            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 6
            let title = makeLabel(testCase.title)
            title.font = .boldSystemFont(ofSize: 13)
            title.textColor = .label
            title.maskApplicationText = false // keep the heading readable
            stack.addArrangedSubview(title)

            func tag(_ kind: String, _ masked: Bool?) -> String {
                guard let masked = masked else { return "\(kind) (config default)" }
                return "\(kind) (expect \(masked ? "masked" : "unmasked"))"
            }
            stack.addArrangedSubview(makeLabel(tag("UILabel", testCase.text), expectMasked: testCase.text))

            let imageRow = UIStackView()
            imageRow.spacing = 8
            let imageView = UIImageView(image: UIImage(systemName: "star.fill"))
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = testCase.images.map { expectationColor(masked: $0) } ?? .systemGray
            imageView.widthAnchor.constraint(equalToConstant: 28).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 28).isActive = true
            imageRow.addArrangedSubview(imageView)
            imageRow.addArrangedSubview(makeLabel(tag("UIImageView", testCase.images), expectMasked: nil))
            stack.addArrangedSubview(imageRow)

            let field = UITextField()
            field.borderStyle = .roundedRect
            field.text = tag("UITextField", testCase.input)
            field.textColor = testCase.input.map { expectationColor(masked: $0) } ?? .label
            stack.addArrangedSubview(field)

            embed(stack, in: container)
            rows.append(container)
        }
        return sectionStack(rows)
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
        NewRelic.logVerbose("Selected row at \(indexPath.row)")
    }


    // nr-block views whose text should never reach the replay, in colors that do or don't
    // contrast with the agent's black block box.
    private func createBlockedSection() -> UIStackView {
        let sectionLabel = UILabel()
        sectionLabel.text = "Blocked Fields"
        sectionLabel.font = .boldSystemFont(ofSize: 18)

        let fieldsStack = UIStackView()
        fieldsStack.axis = .vertical
        fieldsStack.spacing = 12

        let defaultLabel = UILabel()
        defaultLabel.text = "blocked-default-label"
        defaultLabel.accessibilityIdentifier = "nr-block"
        fieldsStack.addArrangedSubview(defaultLabel)

        let whiteLabel = UILabel()
        whiteLabel.text = "blocked-white-label"
        whiteLabel.textColor = .white
        whiteLabel.backgroundColor = .darkGray
        whiteLabel.accessibilityIdentifier = "nr-block"
        fieldsStack.addArrangedSubview(whiteLabel)

        let redLabel = UILabel()
        redLabel.text = "blocked-red-label"
        redLabel.textColor = .systemRed
        redLabel.accessibilityIdentifier = "nr-block"
        fieldsStack.addArrangedSubview(redLabel)

        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.text = "blocked-textfield-text"
        textField.accessibilityIdentifier = "nr-block"
        fieldsStack.addArrangedSubview(textField)

        let textView = UITextView()
        textView.text = "blocked-textview-text"
        textView.textColor = .systemRed
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.accessibilityIdentifier = "nr-block"
        textView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        fieldsStack.addArrangedSubview(textView)

        // Block on a container; the child label has no tag and should be blocked through it.
        let container = UIView()
        container.backgroundColor = .systemYellow.withAlphaComponent(0.3)
        container.accessibilityIdentifier = "nr-block"
        let childLabel = UILabel()
        childLabel.text = "blocked-container-child"
        childLabel.textColor = .systemGreen
        childLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(childLabel)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 36),
            childLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            childLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        fieldsStack.addArrangedSubview(container)

        // Blocked at runtime: the button adds or removes nr-block on a label that's already on
        // screen, so the replay has to switch it between plain text and a black box.
        let toggleLabel = UILabel()
        toggleLabel.text = "blocked-toggle-label"
        toggleLabel.textColor = .systemRed
        fieldsStack.addArrangedSubview(toggleLabel)

        let toggleButton = UIButton(type: .system)
        toggleButton.tintColor = .purple
        toggleButton.setTitle("Toggle block on label above", for: .normal)
        toggleButton.addAction(UIAction { _ in
            let isBlocked = toggleLabel.accessibilityIdentifier != "nr-block"
            toggleLabel.accessibilityIdentifier = isBlocked ? "nr-block" : nil
            NewRelic.logVerbose("Blocked Fields: toggle label blocked=\(isBlocked) at \(Int(Date().timeIntervalSince1970 * 1000))")
        }, for: .touchUpInside)
        fieldsStack.addArrangedSubview(toggleButton)

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, fieldsStack])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
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
        fieldsStack.addArrangedSubview(cvvField)

        let sectionStack = UIStackView(arrangedSubviews: [sectionLabel, fieldsStack])
        sectionStack.axis = .vertical
        sectionStack.spacing = 8
        return sectionStack
    }
}

// One hosted SwiftUI element, optionally wrapped in an NRConditionalMaskView that adds its own rule.
private struct HostedChildCase: View {
    enum Content { case text, input, image }
    enum Rule {
        case none
        case propertyMask, propertyUnmask
        case identifierMask, identifierUnmask
    }

    let content: Content
    let rule: Rule
    let label: String
    let color: Color

    var body: some View {
        switch rule {
        case .none:
            element
        case .propertyMask, .propertyUnmask:
            let value: Bool = rule == .propertyMask
            NRConditionalMaskView(maskApplicationText: content == .text ? value : nil,
                                  maskUserInputText: content == .input ? value : nil,
                                  maskAllImages: content == .image ? value : nil) {
                element
            }
        case .identifierMask:
            NRConditionalMaskView(sessionReplayIdentifier: "masked-1") { element }
        case .identifierUnmask:
            NRConditionalMaskView(sessionReplayIdentifier: "unmasked-1") { element }
        }
    }

    @ViewBuilder private var element: some View {
        switch content {
        case .text:
            Text(label).font(.footnote).foregroundColor(color)
        case .input:
            TextField("", text: .constant(label))
                .textFieldStyle(.roundedBorder)
                .font(.footnote)
                .foregroundColor(color)
        case .image:
            HStack {
                Image(systemName: "star.fill").font(.title).foregroundColor(color)
                Text(label).font(.footnote).foregroundColor(color)
            }
        }
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
#endif
