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
    
    var options =  [UtilOption]()
    
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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
#if os(iOS)
        self.view.backgroundColor = .orange
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
        
        viewModel.loadApodData()
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)

        NewRelic.logInfo("ViewController viewDidLoad finished.")
    }
    
    func setupSpaceStack() {
        self.view.addSubview(zeroImageView)
        zeroImageView.translatesAutoresizingMaskIntoConstraints = false
        zeroImageView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        zeroImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
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
        
        //Text Label
        spaceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        spaceLabel.text  = "Hello, World"
        spaceLabel.textAlignment = .center
        spaceLabel.numberOfLines = 0
        spaceLabel.accessibilityIdentifier = "public" // Because this is a SecureLabel this should stay masked.
        
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
        
        self.view.addSubview(spaceStack)

        //Constraints
        spaceStack.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        spaceStack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        spaceStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        spaceStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        spaceLabel.leadingAnchor.constraint(equalTo: self.spaceStack.leadingAnchor).isActive = true
        spaceLabel.trailingAnchor.constraint(equalTo: self.spaceStack.trailingAnchor).isActive = true
    }
    
    private func setupTimeLabel() {
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        timeLabel.textColor = .white
        timeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        timeLabel.textAlignment = .center
        timeLabel.layer.cornerRadius = 8
        timeLabel.layer.masksToBounds = true
        view.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            timeLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            timeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 165),
            timeLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
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
        let tableView = UITableView()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 45
        tableView.bounces = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "utilitiesCell")
        
        self.view.addSubview(tableView)
        
        tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140.0).isActive = true
        tableView.topAnchor.constraint(equalTo: spaceStack.bottomAnchor, constant: 30.0).isActive = true
        tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        
        options.append(UtilOption(title: "SwiftUI", handler: { [self] in swiftUIViewTapped()}))

        options.append(UtilOption(title: "Utilities", handler: { [self] in utilitiesAction()}))

        options.append(UtilOption(title: "Text Masking", handler: { [self] in textMaskingAction()}))

        options.append(UtilOption(title: "Collection View", handler: { [self] in collectionViewAction()}))
        
        options.append(UtilOption(title: "Diff Test View", handler: { [self] in diffTestViewAction()}))
        
        options.append(UtilOption(title: "Infinite Images View", handler: { [self] in infiniteImagesViewAction()}))
        
        options.append(UtilOption(title: "Tinted Images View", handler: { [self] in tintedImagesViewController()}))

        options.append(UtilOption(title: "Infinite Scroll View", handler: { [self] in infiniteViewAction()}))

        options.append(UtilOption(title: "PerformanceContentView", handler: { [self] in performanceContentView()}))
        
        options.append(UtilOption(title: "SwiftUI UITabBar", handler: { [self] in showSwiftUITabBar()}))

#if os(iOS)
        options.append(UtilOption(title: "WebView", handler: { [self] in webViewAction()}))
#endif
        options.append(UtilOption(title: "Confidential View", handler: { [self] in confidentialAction()}))

        options.append(UtilOption(title: "Change Image", handler: { [self] in refreshAction()}))

        options.append(UtilOption(title: "Change Image (Async)", handler: { [self] in refreshActionAsync()}))

        options.append(UtilOption(title: "Change Image Error", handler: { [self] in brokeRefreshAction()}))

        options.append(UtilOption(title: "Change Image Error (Async)", handler: { [self] in brokeRefreshActionAsync()}))
        
        options.append(UtilOption(title: "SwiftUIViewRepresentable", handler: { [self] in swiftUIViewRepresentableTapped()}))
        
        options.append(UtilOption(title: "SwiftUICustomerViewTapped", handler: { [self] in swiftUICustomerViewTapped()}))

        options.append(UtilOption(title: "Attributed Text Test", handler: { [self] in attributedTextTestAction()}))

        options.append(UtilOption(title: "Date Time Picker", handler: { [self] in dateTimePickerAction()}))

        options.append(UtilOption(title: "UISwitch Test", handler: { [self] in switchTestAction()}))

        // BlockView examples
        options.append(UtilOption(title: "BlockView SwiftUI Example", handler: { [self] in blockViewSwiftUIAction() }))
        options.append(UtilOption(title: "BlockView UIKit Example", handler: { [self] in blockViewUIKitAction() }))
        options.append(UtilOption(title: "BlockView Propagation Test", handler: { [self] in blockViewPropagationTest() }))

        // In setupButtonsTable(), add these options:
        options.append(UtilOption(title: "Add Hello World Label", handler: { [self] in addHelloWorldLabel() }))
        options.append(UtilOption(title: "Remove Hello World Label", handler: { [self] in removeHelloWorldLabel() }))

        // Corner Radius Testing
        options.append(UtilOption(title: "🔴 UIKit Corner Radius Playground", handler: { [self] in showUIKitCornerRadiusPlayground() }))
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

    func showUIKitCornerRadiusPlayground() {
#if os(iOS)
        let playgroundController = UIKitCornerRadiusPlaygroundController()
        navigationController?.pushViewController(playgroundController, animated: true)
#endif
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "utilitiesCell", for: indexPath)

        if #available(iOS 14.0, tvOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = options[indexPath.row].title
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.text = options[indexPath.row].title
            cell.textLabel?.textColor = .black
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        options[indexPath.row].handler()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
