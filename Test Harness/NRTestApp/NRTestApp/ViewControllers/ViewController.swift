//
//  ViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/11/23.
//

import UIKit
import SwiftUI
import NewRelic

class ViewController: UIViewController {
    weak var coordinator: MainCoordinator?
    var viewModel: ApodViewModel!
    
    var sections = [UtilSection]()
    
    var spaceImageView = UIImageView()
    var zeroImageView = UIImageView()
    var spaceLabel = SecureLabel()
    var privateHelloLabel = UnsecureLabel()
    var spaceStack = UIStackView()
    var helloButton = UIButton()
    var helloWorldLabel: UILabel?
        
    private var timeLabel = UILabel()
    private var appStartDate = Date()
    private var timer: Timer?

    // The whole screen is one scrolling table: `headerContainer` holds the space
    // image / label / button content and rides along as the table's header view.
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let headerContainer = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
#if os(iOS)
        self.view.backgroundColor = .orange
        self.title = "NRTestApp"
#endif
        zeroImageView.image = UIImage()
        
        setupSpaceStack()
        setupButtonsTable()
        
        setupTimeLabel()
        startTimer()
        
        viewModel.error.onUpdate = { [weak self] _ in
            if let error = self?.viewModel.error.value {
                NewRelic.recordError(error)
            }
        }

        viewModel.apodResponse.onUpdate = { [weak self] _ in
            if let url = self?.viewModel.apodResponse.value?.url {
                self?.spaceImageView.loadImage(withUrl: url)
            }
            if let title = self?.viewModel.apodResponse.value?.title, let date = self?.viewModel.apodResponse.value?.date{
                self?.spaceLabel.text = title + ", " + date
            }
        }
        
        // Delay the initial image load slightly so the view hierarchy and
        // networking stack are fully set up first. This makes the initial
        // space image load more reliably on every launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.viewModel.loadApodData()
        }
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        NewRelic.logInfo("ViewController viewDidLoad finished.")
    }
    
    func setupSpaceStack() {
        headerContainer.addSubview(zeroImageView)
        zeroImageView.translatesAutoresizingMaskIntoConstraints = false
        zeroImageView.topAnchor.constraint(equalTo: headerContainer.topAnchor).isActive = true
        zeroImageView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor).isActive = true
        zeroImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 25.0).isActive = true
        zeroImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 25.0).isActive = true
        zeroImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 10.0).isActive = true
        zeroImageView.widthAnchor.constraint(greaterThanOrEqualToConstant: 10.0).isActive = true

        //Image View
        spaceImageView.contentMode = .scaleAspectFit
        spaceImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 250.0).isActive = true
        spaceImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 250.0).isActive = true
        spaceImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100.0).isActive = true
        spaceImageView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100.0).isActive = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        spaceImageView.isUserInteractionEnabled = true
        spaceImageView.addGestureRecognizer(tapGestureRecognizer)
        spaceImageView.maskAllImages = false
        
        //Text Label
        spaceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        spaceLabel.text  = "Hello, World"
        spaceLabel.textAlignment = .center
        spaceLabel.numberOfLines = 0
        spaceLabel.accessibilityIdentifier = "public" // Because this is a SecureLabel this should stay masked.
        spaceLabel.maskApplicationText = false
        
        //Text Label
        privateHelloLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        privateHelloLabel.text  = "Secret Hello, World!"
        privateHelloLabel.textAlignment = .center
        privateHelloLabel.numberOfLines = 0
        privateHelloLabel.accessibilityIdentifier = "private" // Even though this is a UnsecureLabel this tag should mark it masked.
        
        //Button
        helloButton.setTitleColor(.green, for: .normal)
        helloButton.setTitle("Hello", for: .normal)
        if let helloButtonTitleLabel = helloButton.titleLabel {
            helloButtonTitleLabel.accessibilityIdentifier = "public"
        }

        // BlockView Example Button (UIKit direct approach)
        let blockViewButton = UIButton(type: .system)
        blockViewButton.setTitle("🔒 Blocked Button", for: .normal)
        blockViewButton.setTitleColor(.white, for: .normal)
        blockViewButton.backgroundColor = .systemRed
        blockViewButton.layer.cornerRadius = 8
        blockViewButton.blockView = true // This will block the entire button
        blockViewButton.addTarget(self, action: #selector(blockViewButtonTapped), for: .touchUpInside)

        // BlockView Example using accessibility ID
        let accessibilityBlockButton = UIButton(type: .system)
        accessibilityBlockButton.setTitle("🛡️ Accessibility Block", for: .normal)
        accessibilityBlockButton.setTitleColor(.white, for: .normal)
        accessibilityBlockButton.backgroundColor = .systemPurple
        accessibilityBlockButton.layer.cornerRadius = 8
        accessibilityBlockButton.accessibilityIdentifier = "nr-block"
        accessibilityBlockButton.addTarget(self, action: #selector(accessibilityBlockButtonTapped), for: .touchUpInside)

        //Stack View
        spaceStack.axis = .vertical
        spaceStack.distribution = .equalSpacing
        spaceStack.alignment = .center
        spaceStack.spacing = 16.0

        spaceStack.addArrangedSubview(privateHelloLabel)
        spaceStack.addArrangedSubview(spaceImageView)
        spaceStack.addArrangedSubview(spaceLabel)
        spaceStack.addArrangedSubview(helloButton)
        spaceStack.addArrangedSubview(blockViewButton)
        spaceStack.addArrangedSubview(accessibilityBlockButton)
        spaceStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerContainer.addSubview(spaceStack)

        //Constraints
        spaceStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12.0).isActive = true
        spaceStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12.0).isActive = true
        spaceStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor).isActive = true
        spaceStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor).isActive = true
        spaceLabel.leadingAnchor.constraint(equalTo: self.spaceStack.leadingAnchor).isActive = true
        spaceLabel.trailingAnchor.constraint(equalTo: self.spaceStack.trailingAnchor).isActive = true
    }
    
    private func setupTimeLabel() {
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        // The nav bar supplies the background, so draw the text against it.
        timeLabel.textColor = .label
        timeLabel.backgroundColor = .clear
        timeLabel.textAlignment = .center

        NSLayoutConstraint.activate([
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 165),
            timeLabel.heightAnchor.constraint(equalToConstant: 28)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: timeLabel)
    }

    private func startTimer() {
        updateTimeLabel()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeLabel()
        }
    }

    private func updateTimeLabel() {
        let elapsed = Int(Date().timeIntervalSince(appStartDate))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60

        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        let currentTime = formatter.string(from: Date())

        timeLabel.text = String(format: "%02d:%02d:%02d  %@", hours, minutes, seconds, currentTime)
    }
    
    @objc private func appDidBecomeActive() {
        appStartDate = Date()
        timer?.invalidate()
        startTimer()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer)
    {
        guard let spaceImage = spaceImageView.image else { return }

        coordinator?.showImageViewController(image:spaceImage)
    }
    
    func swiftUIViewTapped() {
        coordinator?.showSwiftUITestView()
    }
    
    func swiftUICustomerViewTapped() {
        coordinator?.showSwiftUICustomerView()
    }
    
    func swiftUIViewRepresentableTapped() {
        coordinator?.showSwiftUIViewRepresentableTestView()
    }
    
    func setupButtonsTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 45
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "utilitiesCell")

        self.view.addSubview(tableView)

        // The table fills the screen so the space content in its header scrolls too.
        tableView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true

        tableView.tableHeaderView = headerContainer

        var controls: [UtilOption] = [
            UtilOption(title: "Date Time Picker", handler: { [self] in dateTimePickerAction() }),
            UtilOption(title: "UISwitch Test", handler: { [self] in switchTestAction() }),
            UtilOption(title: "Map View (UIKit)", handler: { [self] in mapViewAction() })
        ]
#if os(iOS)
        controls.append(UtilOption(title: "WebView", handler: { [self] in webViewAction() }))
#endif

        sections = [
            UtilSection(title: "Space Image", options: [
                UtilOption(title: "Change Image", handler: { [self] in refreshAction() }),
                UtilOption(title: "Change Image (Async)", handler: { [self] in refreshActionAsync() }),
                UtilOption(title: "Change Image Error", handler: { [self] in brokeRefreshAction() }),
                UtilOption(title: "Change Image Error (Async)", handler: { [self] in brokeRefreshActionAsync() }),
                UtilOption(title: "Add Hello World Label", handler: { [self] in addHelloWorldLabel() }),
                UtilOption(title: "Remove Hello World Label", handler: { [self] in removeHelloWorldLabel() })
            ]),
            UtilSection(title: "SwiftUI", options: [
                UtilOption(title: "SwiftUI", handler: { [self] in swiftUIViewTapped() }),
                UtilOption(title: "SwiftUICustomerViewTapped", handler: { [self] in swiftUICustomerViewTapped() }),
                UtilOption(title: "SwiftUIViewRepresentable", handler: { [self] in swiftUIViewRepresentableTapped() }),
                UtilOption(title: "SwiftUI UITabBar", handler: { [self] in showSwiftUITabBar() }),
                UtilOption(title: "PerformanceContentView", handler: { [self] in performanceContentView() })
            ]),
            UtilSection(title: "Masking & Privacy", options: [
                UtilOption(title: "Text Masking", handler: { [self] in textMaskingAction() }),
                UtilOption(title: "Confidential View", handler: { [self] in confidentialAction() }),
                UtilOption(title: "Attributed Text Test", handler: { [self] in attributedTextTestAction() }),
                UtilOption(title: "BlockView SwiftUI Example", handler: { [self] in blockViewSwiftUIAction() }),
                UtilOption(title: "BlockView UIKit Example", handler: { [self] in blockViewUIKitAction() }),
                UtilOption(title: "BlockView Propagation Test", handler: { [self] in blockViewPropagationTest() })
            ]),
            UtilSection(title: "Scrolling & Collections", options: [
                UtilOption(title: "Collection View", handler: { [self] in collectionViewAction() }),
                UtilOption(title: "Infinite Images View", handler: { [self] in infiniteImagesViewAction() }),
                UtilOption(title: "Infinite Scroll View", handler: { [self] in infiniteViewAction() }),
                UtilOption(title: "Tinted Images View", handler: { [self] in tintedImagesViewController() }),
                UtilOption(title: "Diff Test View", handler: { [self] in diffTestViewAction() })
            ]),
            UtilSection(title: "Controls", options: controls),
            UtilSection(title: "Agent & Diagnostics", options: [
                UtilOption(title: "Utilities", handler: { [self] in utilitiesAction() }),
                // NR-566282 — exercises the Session Replay sign-out / rootViewController-swap crash repro.
                UtilOption(title: "Sign-Out Crash Repro", handler: { [self] in signOutCrashReproAction() }),
                // PR #691 – On the new event system, recording one event with invalid attributes drops all events at harvest time.
                UtilOption(title: "Record an event with invalid attributes", handler: { [self] in recordEventBatchWithInvalidAttributes() }),
                UtilOption(title: "Start Random Walk", handler: { [self] in startRandomWalk() }),
                UtilOption(title: "Stop Random Walk", handler: { RandomWalkController.shared.stop() }),
                UtilOption(title: "Capture Viewer", handler: { [self] in showCaptureViewer() })
            ])
        ]
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeTableHeaderToFit()
    }

    /// A `tableHeaderView` is frame-sized, so measure the Auto Layout content and
    /// re-assign the header whenever that height changes (rotation, label growth).
    private func sizeTableHeaderToFit() {
        guard let header = tableView.tableHeaderView, tableView.bounds.width > 0 else { return }

        header.frame.size.width = tableView.bounds.width
        let height = header.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel).height

        if abs(header.frame.height - height) > 0.5 {
            header.frame.size.height = height
            tableView.tableHeaderView = header
        }
    }

    func signOutCrashReproAction() {
        coordinator?.showSignOutCrashReproViewController()
    }

    func recordEventBatchWithInvalidAttributes() {
        coordinator?.recordEventBatchWithInvalidAttributes()
    }

    func utilitiesAction() {
        coordinator?.showUtilitiesViewController()
    }
  
    func webViewAction() {
        self.coordinator?.showWebViewController()
    }

    func refreshAction() {
        viewModel.loadApodData()
    }
    func brokeRefreshAction() {
        viewModel.loadApodDataBrokeData()
    }

    func refreshActionAsync() {
        Task {
            await viewModel.loadApodDataAsync()
        }
    }

    func brokeRefreshActionAsync() {
         Task {
             await viewModel.loadApodDataAsyncBrokeData()
         }
     }

    func textMaskingAction() {
        coordinator?.showTextMaskingController()
    }

    func collectionViewAction() {
        coordinator?.showCollectionController()
    }
    
    func diffTestViewAction() {
        coordinator?.showDiffTestController()
    }
    
    func confidentialAction() {
        coordinator?.showConfidentialController()
    }
    
    func infiniteViewAction() {
        coordinator?.showInfiniteScrollController()
    }
    
    func infiniteImagesViewAction() {
        coordinator?.showInfiniteImageScrollController()
    }
    
    func performanceContentView() {
        coordinator?.showPerformanceContentView()
    }

    func attributedTextTestAction() {
        coordinator?.showAttributedTextTestViewController()
    }

    func dateTimePickerAction() {
        coordinator?.showDateTimePickerViewController()
    }

    func switchTestAction() {
        coordinator?.showSwitchTestViewController()
    }

    func makeButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.widthAnchor.constraint(equalToConstant: self.view.frame.width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
        
        return button
    }
    
    // Add these methods to your ViewController class
    func addHelloWorldLabel() {
        guard helloWorldLabel == nil else { return }
        let label = UILabel()
        label.text = "Hello world"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        self.spaceStack.addArrangedSubview(label)

        helloWorldLabel = label
    }

    func removeHelloWorldLabel() {
        helloWorldLabel?.removeFromSuperview()
        helloWorldLabel = nil
    }

    // MARK: - BlockView Example Actions

    @objc func blockViewButtonTapped() {
        // This button will appear as a black rectangle in session replay
        let alert = UIAlertController(title: "Blocked Button", message: "This button is blocked in session replay!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc func accessibilityBlockButtonTapped() {
        // This button will also appear as a black rectangle in session replay
        let alert = UIAlertController(title: "Accessibility Block", message: "This button is blocked using accessibility ID!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func blockViewSwiftUIAction() {
#if os(iOS)
        let hostingController = BlockViewSwiftUIHostingController()
        navigationController?.pushViewController(hostingController, animated: true)
#endif
    }
    
    func showSwiftUITabBar() {
#if os(iOS)
        coordinator?.showSwiftUITabBar()
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
    
    func tintedImagesViewController() {
#if os(iOS)
        coordinator?.showTintedImagesViewController()
#endif
    }

    func mapViewAction() {
        coordinator?.showMapViewController()
    }

    func startRandomWalk() {
        guard let coordinator else { return }
        RandomWalkController.shared.start(with: coordinator)
    }

    func showCaptureViewer() {
        coordinator?.showCaptureViewer()
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return sections[section].options.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "utilitiesCell", for: indexPath)
        let option = sections[indexPath.section].options[indexPath.row]

        if #available(iOS 14.0, tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = option.title
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = option.title
            cell.textLabel?.textColor = .black
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        sections[indexPath.section].options[indexPath.row].handler()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
