//
//  ViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/11/23.
//

import UIKit
import SwiftUI
import NewRelic

// MARK: - Section Model

struct TableSection {
    let title: String
    let icon: String
    let color: UIColor
    let items: [UtilOption]
    var isExpanded: Bool = true
}

// MARK: - Section Header View

class SectionHeaderView: UITableViewHeaderFooterView {
    static let reuseID = "SectionHeaderView"

    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let separatorLine = UIView()

    var onTap: (() -> Void)?

    var isExpanded: Bool = true {
        didSet {
            let angle: CGFloat = isExpanded ? 0 : -CGFloat.pi / 2
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.75,
                           initialSpringVelocity: 0.5,
                           options: .curveEaseInOut) {
                self.chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        buildViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildViews() {
        contentView.backgroundColor = UIColor.systemGroupedBackground

        // Colored icon pill
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 7
        iconContainer.clipsToBounds = true
        contentView.addSubview(iconContainer)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconContainer.addSubview(iconImageView)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        contentView.addSubview(titleLabel)

        // Chevron
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.image = UIImage(systemName: "chevron.down")
        chevronImageView.tintColor = UIColor.tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        contentView.addSubview(chevronImageView)

        // Bottom hairline separator
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = UIColor.separator
        contentView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),

            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 17),
            iconImageView.heightAnchor.constraint(equalToConstant: 17),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 11),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronImageView.leadingAnchor, constant: -8),

            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 13),
            chevronImageView.heightAnchor.constraint(equalToConstant: 13),

            separatorLine.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        contentView.addGestureRecognizer(tap)
    }

    @objc private func didTap() { onTap?() }

    func configure(title: String, icon: String, color: UIColor, expanded: Bool) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        iconContainer.backgroundColor = color
        // Set without animation on first configure
        let angle: CGFloat = expanded ? 0 : -CGFloat.pi / 2
        chevronImageView.transform = CGAffineTransform(rotationAngle: angle)
        isExpanded = expanded
    }
}

// MARK: - Hero Header View

class HeroHeaderView: UIView {
    let privateHelloLabel = UnsecureLabel()
    let spaceImageView = UIImageView()
    let spaceLabel = SecureLabel()
    let timeLabel = UILabel()
    let zeroImageView = UIImageView() // session-replay zero-dimension fixture

    private(set) var helloWorldLabel: UILabel?
    private let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildViews() {
        backgroundColor = .orange

        // Zero-size fixture (session replay test)
        zeroImageView.image = UIImage()
        zeroImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(zeroImageView)

        // Time label — floats top-right over everything
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        timeLabel.textAlignment = .center
        timeLabel.layer.cornerRadius = 8
        timeLabel.layer.masksToBounds = true
        addSubview(timeLabel)

        // Private hello label
        privateHelloLabel.text = "Secret Hello, World!"
        privateHelloLabel.textAlignment = .center
        privateHelloLabel.numberOfLines = 0
        privateHelloLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        privateHelloLabel.textColor = .white
        privateHelloLabel.accessibilityIdentifier = "private"

        // Space image
        spaceImageView.contentMode = .scaleAspectFill
        spaceImageView.clipsToBounds = true
        spaceImageView.layer.cornerRadius = 18
        spaceImageView.layer.borderWidth = 2.5
        spaceImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        spaceImageView.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        spaceImageView.isUserInteractionEnabled = true

        // Space label
        spaceLabel.text = "Hello, World"
        spaceLabel.textAlignment = .center
        spaceLabel.numberOfLines = 0
        spaceLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        spaceLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        spaceLabel.accessibilityIdentifier = "public"

        // Vertical stack
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        contentStack.addArrangedSubview(privateHelloLabel)
        contentStack.addArrangedSubview(spaceImageView)
        contentStack.addArrangedSubview(spaceLabel)

        NSLayoutConstraint.activate([
            // Zero-size fixture
            zeroImageView.topAnchor.constraint(equalTo: topAnchor),
            zeroImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            zeroImageView.heightAnchor.constraint(equalToConstant: 0),
            zeroImageView.widthAnchor.constraint(equalToConstant: 0),

            // Time label
            timeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 165),
            timeLabel.heightAnchor.constraint(equalToConstant: 28),

            // Content stack fills header, with top pad for time label
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 52),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

            // Image: square, 68% of stack width
            spaceImageView.widthAnchor.constraint(equalTo: contentStack.widthAnchor, multiplier: 0.68),
            spaceImageView.heightAnchor.constraint(equalTo: spaceImageView.widthAnchor),

            privateHelloLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            privateHelloLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            spaceLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            spaceLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])
    }

    func addHelloWorldLabel() {
        guard helloWorldLabel == nil else { return }
        let label = UILabel()
        label.text = "Hello world"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        //label.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor).isActive = true
        //label.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor).isActive = true
        contentStack.addArrangedSubview(label)
        helloWorldLabel = label
    }

    func removeHelloWorldLabel() {
        helloWorldLabel?.removeFromSuperview()
        helloWorldLabel = nil
    }
}

// MARK: - View Controller

class ViewController: UIViewController {
    weak var coordinator: MainCoordinator?
    var viewModel: ApodViewModel!

    // Forwarded to heroHeader for any external access
    var spaceImageView: UIImageView { heroHeader.spaceImageView }
    var spaceLabel: SecureLabel { heroHeader.spaceLabel }
    var privateHelloLabel: UnsecureLabel { heroHeader.privateHelloLabel }
    var helloWorldLabel: UILabel? { heroHeader.helloWorldLabel }

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let heroHeader = HeroHeaderView()
    private var sections: [TableSection] = []

    private var appStartDate = Date()
    private var timer: Timer?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
#if os(iOS)
        view.backgroundColor = .orange
#endif
        buildSections()
        setupTableView()
        startTimer()
        bindViewModel()
        viewModel.loadApodData()

        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        NewRelic.logInfo("ViewController viewDidLoad finished.")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    // MARK: Setup

    private func buildSections() {
        sections = [
            TableSection(title: "Network Tests", icon: "network", color: .systemGreen, items: [
                UtilOption(title: "Change Image",             handler: { [weak self] in self?.refreshAction() }),
                UtilOption(title: "Change Image (Async)",     handler: { [weak self] in self?.refreshActionAsync() }),
                UtilOption(title: "Change Image Error",       handler: { [weak self] in self?.brokeRefreshAction() }),
                UtilOption(title: "Change Image Error (Async)",handler: { [weak self] in self?.brokeRefreshActionAsync() }),
            ]),
            TableSection(title: "SwiftUI", icon: "swift", color: .systemOrange, items: [
                UtilOption(title: "SwiftUI Components",       handler: { [weak self] in self?.swiftUIViewTapped() }),
                UtilOption(title: "SwiftUI UITabBar",          handler: { [weak self] in self?.showSwiftUITabBar() }),
                UtilOption(title: "SwiftUI ViewRepresentable", handler: { [weak self] in self?.swiftUIViewRepresentableTapped() }),
                UtilOption(title: "SwiftUI Customer View",     handler: { [weak self] in self?.swiftUICustomerViewTapped() }),
                UtilOption(title: "Performance View",          handler: { [weak self] in self?.performanceContentView() }),
            ]),
            TableSection(title: "UIKit Screens", icon: "iphone", color: .systemBlue, items: [
                UtilOption(title: "Utilities",           handler: { [weak self] in self?.utilitiesAction() }),
                UtilOption(title: "Collection View",     handler: { [weak self] in self?.collectionViewAction() }),
                UtilOption(title: "Infinite Images View",handler: { [weak self] in self?.infiniteImagesViewAction() }),
                UtilOption(title: "Tinted Images View",  handler: { [weak self] in self?.tintedImagesViewController() }),
                UtilOption(title: "Infinite Scroll View",handler: { [weak self] in self?.infiniteViewAction() }),
                UtilOption(title: "Diff Test View",      handler: { [weak self] in self?.diffTestViewAction() }),
                UtilOption(title: "Attributed Text Test",handler: { [weak self] in self?.attributedTextTestAction() }),
                UtilOption(title: "Date Time Picker",    handler: { [weak self] in self?.dateTimePickerAction() }),
                UtilOption(title: "UISwitch Test",       handler: { [weak self] in self?.switchTestAction() }),
                UtilOption(title: "WebView",             handler: { [weak self] in self?.webViewAction() }),
            ]),
            TableSection(title: "Session Replay", icon: "eye.slash.fill", color: .systemPurple, items: [
                UtilOption(title: "Text Masking",             handler: { [weak self] in self?.textMaskingAction() }),
                UtilOption(title: "Confidential View",        handler: { [weak self] in self?.confidentialAction() }),
                UtilOption(title: "Hello (masking fixture)",  handler: { [weak self] in self?.helloButtonTapped() }),
                UtilOption(title: "🔒 Blocked Button",         handler: { [weak self] in self?.blockViewButtonTapped() }),
                UtilOption(title: "🛡️ Accessibility Block",   handler: { [weak self] in self?.accessibilityBlockButtonTapped() }),
                UtilOption(title: "BlockView SwiftUI Example", handler: { [weak self] in self?.blockViewSwiftUIAction() }),
                UtilOption(title: "BlockView UIKit Example",   handler: { [weak self] in self?.blockViewUIKitAction() }),
                UtilOption(title: "BlockView Propagation Test",handler: { [weak self] in self?.blockViewPropagationTest() }),
            ]),
            TableSection(title: "Dynamic UI", icon: "wand.and.stars", color: .systemTeal, items: [
                UtilOption(title: "Add Hello World Label",    handler: { [weak self] in self?.addHelloWorldLabel() }),
                UtilOption(title: "Remove Hello World Label", handler: { [weak self] in self?.removeHelloWorldLabel() }),
            ]),
        ]
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SectionHeaderView.self, forHeaderFooterViewReuseIdentifier: SectionHeaderView.reuseID)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Attach image tap before setting as header
        let tap = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        heroHeader.spaceImageView.addGestureRecognizer(tap)

        // Give the hero a preliminary frame so Auto Layout can resolve on first pass
        heroHeader.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        tableView.tableHeaderView = heroHeader
    }

    private func sizeHeaderToFit() {
        guard let header = tableView.tableHeaderView else { return }
        let targetSize = CGSize(width: tableView.bounds.width,
                                height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel).height
        if abs(header.frame.height - height) > 1 {
            var f = header.frame
            f.size.height = height
            header.frame = f
            tableView.tableHeaderView = header
        }
    }

    private func bindViewModel() {
        viewModel.error.onUpdate = { [weak self] _ in
            if let error = self?.viewModel.error.value {
                NewRelic.recordError(error)
            }
        }
        viewModel.apodResponse.onUpdate = { [weak self] _ in
            if let url = self?.viewModel.apodResponse.value?.url {
                self?.heroHeader.spaceImageView.loadImage(withUrl: url)
            }
            if let title = self?.viewModel.apodResponse.value?.title,
               let date = self?.viewModel.apodResponse.value?.date {
                self?.heroHeader.spaceLabel.text = title + ", " + date
            }
        }
    }

    // MARK: Timer

    private func startTimer() {
        updateTimeLabel()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }
    }

    private func updateTimeLabel() {
        let elapsed = Int(Date().timeIntervalSince(appStartDate))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let currentTime = formatter.string(from: Date())
        heroHeader.timeLabel.text = String(format: "%02d:%02d:%02d  %@", h, m, s, currentTime)
    }

    @objc private func appDidBecomeActive() {
        appStartDate = Date()
        timer?.invalidate()
        startTimer()
    }

    // MARK: Actions

    @objc private func imageTapped() {
        guard let image = heroHeader.spaceImageView.image else { return }
        coordinator?.showImageViewController(image: image)
    }

    func swiftUIViewTapped() { coordinator?.showSwiftUITestView() }
    func swiftUICustomerViewTapped() { coordinator?.showSwiftUICustomerView() }
    func swiftUIViewRepresentableTapped() { coordinator?.showSwiftUIViewRepresentableTestView() }
    func utilitiesAction() { coordinator?.showUtilitiesViewController() }
    func webViewAction() { coordinator?.showWebViewController() }
    func refreshAction() { viewModel.loadApodData() }
    func brokeRefreshAction() { viewModel.loadApodDataBrokeData() }
    func refreshActionAsync() { Task { await viewModel.loadApodDataAsync() } }
    func brokeRefreshActionAsync() { Task { await viewModel.loadApodDataAsyncBrokeData() } }
    func textMaskingAction() { coordinator?.showTextMaskingController() }
    func collectionViewAction() { coordinator?.showCollectionController() }
    func diffTestViewAction() { coordinator?.showDiffTestController() }
    func confidentialAction() { coordinator?.showConfidentialController() }
    func infiniteViewAction() { coordinator?.showInfiniteScrollController() }
    func infiniteImagesViewAction() { coordinator?.showInfiniteImageScrollController() }
    func performanceContentView() { coordinator?.showPerformanceContentView() }
    func attributedTextTestAction() { coordinator?.showAttributedTextTestViewController() }
    func dateTimePickerAction() { coordinator?.showDateTimePickerViewController() }
    func switchTestAction() { coordinator?.showSwitchTestViewController() }

    func showSwiftUITabBar() {
#if os(iOS)
        coordinator?.showSwiftUITabBar()
#endif
    }

    func tintedImagesViewController() {
#if os(iOS)
        coordinator?.showTintedImagesViewController()
#endif
    }

    func addHelloWorldLabel() {
        heroHeader.addHelloWorldLabel()
        sizeHeaderToFit()
    }

    func removeHelloWorldLabel() {
        heroHeader.removeHelloWorldLabel()
        sizeHeaderToFit()
    }

    @objc func helloButtonTapped() {
        let alert = UIAlertController(title: "Hello",
                                      message: "Hello! (masking fixture)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func blockViewButtonTapped() {
        let alert = UIAlertController(title: "Blocked Button",
                                      message: "This button is blocked in session replay!",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func accessibilityBlockButtonTapped() {
        let alert = UIAlertController(title: "Accessibility Block",
                                      message: "This button is blocked using accessibility ID!",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func blockViewSwiftUIAction() {
#if os(iOS)
        let hostingController = BlockViewSwiftUIHostingController()
        navigationController?.pushViewController(hostingController, animated: true)
#endif
    }

    func blockViewUIKitAction() {
#if os(iOS)
        let keypadController = KeypadUIKitViewController()
        navigationController?.pushViewController(keypadController, animated: true)
#endif
    }

    func blockViewPropagationTest() {
#if os(iOS)
        let propagationTestController = BlockViewPropagationTestController()
        navigationController?.pushViewController(propagationTestController, animated: true)
#endif
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].isExpanded ? sections[section].items.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        let color = sections[indexPath.section].color

        if #available(iOS 14.0, *) {
            var config = cell.defaultContentConfiguration()
            config.text = item.title
            cell.contentConfiguration = config
        } else {
            cell.textLabel?.text = item.title
        }
        if item.title == "🔒 Blocked Button" {
            cell.blockView = true
        }
        if item.title == "🛡️ Accessibility Block" {
            cell.accessibilityIdentifier = "nr-block"
        }
        if item.title == "Hello (masking fixture)" {
            cell.accessibilityIdentifier = "public"

        }

        cell.accessoryType = .disclosureIndicator

        // Colored left pip — tag 999 so reuse clears it
        cell.contentView.subviews.filter { $0.tag == 999 }.forEach { $0.removeFromSuperview() }
        let pip = UIView()
        pip.tag = 999
        pip.backgroundColor = color
        pip.layer.cornerRadius = 2.5
        pip.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(pip)
        NSLayoutConstraint.activate([
            pip.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            pip.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            pip.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
            pip.widthAnchor.constraint(equalToConstant: 4),
        ])

        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: SectionHeaderView.reuseID) as! SectionHeaderView
        let sec = sections[section]
        header.configure(title: sec.title, icon: sec.icon, color: sec.color, expanded: sec.isExpanded)
        header.onTap = { [weak self] in self?.toggleSection(section) }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 52
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        sections[indexPath.section].items[indexPath.row].handler()
        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func toggleSection(_ section: Int) {
        sections[section].isExpanded.toggle()
        let expanded = sections[section].isExpanded

        if let header = tableView.headerView(forSection: section) as? SectionHeaderView {
            header.isExpanded = expanded
        }

        let count = sections[section].items.count
        let indexPaths = (0..<count).map { IndexPath(row: $0, section: section) }

        tableView.performBatchUpdates {
            if expanded {
                tableView.insertRows(at: indexPaths, with: .top)
            } else {
                tableView.deleteRows(at: indexPaths, with: .top)
            }
        }
    }
}
