//
//  RandomWalkController.swift
//  NRTestApp
//

import UIKit
import NewRelic

// MARK: - RandomWalkController

/// Monkey-tests the app by randomly navigating to screens and firing New Relic telemetry.
/// Start from the main menu so it has access to the coordinator.
final class RandomWalkController {

    static let shared = RandomWalkController()
    private init() {}

    private(set) var isRunning = false
    private(set) var stepCount = 0
    private var isNavigating = false

    weak var coordinator: MainCoordinator?
    private weak var overlayView: RandomWalkOverlayView?

    private let stepInterval: ClosedRange<Double> = 1.5...4.0
    private let navDwellTime: ClosedRange<Double> = 2.5...5.0

    // MARK: - Public

    func start(with coordinator: MainCoordinator) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.start(with: coordinator) }
            return
        }
        guard !isRunning else { return }
        self.coordinator = coordinator
        isRunning = true
        stepCount = 0
        isNavigating = false
        attachOverlay()
        NewRelic.recordBreadcrumb("RandomWalk.started", attributes: [:])
        scheduleNextStep()
    }

    func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.stop() }
            return
        }
        guard isRunning else { return }
        isRunning = false
        NewRelic.recordBreadcrumb("RandomWalk.stopped", attributes: ["totalSteps": stepCount])
        coordinator = nil
        detachOverlay()
    }

    // MARK: - Step Loop

    private func scheduleNextStep() {
        let delay = Double.random(in: stepInterval)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.isRunning else { return }
            self.performStep()
            self.scheduleNextStep()
        }
    }

    private func performStep() {
        stepCount += 1
        overlayView?.stepCount = stepCount

        // 25% chance to navigate, rest fires NR telemetry
        if !isNavigating, Double.random(in: 0...1) < 0.25 {
            performRandomNavigation()
        } else {
            performRandomTelemetry()
        }
    }

    // MARK: - Navigation

    private func performRandomNavigation() {
        guard let coordinator else { return }
        isNavigating = true
        coordinator.navigationController.popToRootViewController(animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let coordinator = self.coordinator else { return }
            self.pushRandomView(using: coordinator)
        }
    }

    private func pushRandomView(using coordinator: MainCoordinator) {
        var actions: [() -> Void] = [
            { coordinator.showUtilitiesViewController() },
            { coordinator.showCollectionController() },
            { coordinator.showInfiniteScrollController() },
            { coordinator.showInfiniteImageScrollController() },
            { coordinator.showDiffTestController() },
            { coordinator.showConfidentialController() },
            { coordinator.showAttributedTextTestViewController() },
            { coordinator.showSwiftUITestView() },
            { coordinator.showSwiftUIViewRepresentableTestView() },
            { coordinator.showMapViewController() },
        ]

#if os(iOS)
        actions.append(contentsOf: [
            { coordinator.showWebViewController() },
            { coordinator.showTextMaskingController() },
            { coordinator.showDateTimePickerViewController() },
            { coordinator.showTintedImagesViewController() },
            { coordinator.showSwitchTestViewController() },
        ])
        if #available(iOS 16.0, *) {
            actions.append({ coordinator.showSwiftUICustomerView() })
        }
        if #available(iOS 17.0, *) {
            actions.append({ coordinator.showPerformanceContentView() })
        }
        if #available(iOS 18.0, *) {
            actions.append({ coordinator.showSwiftUITabBar() })
        }
#endif

        actions.randomElement()?()
        NewRelic.recordBreadcrumb("RandomWalk.navigate", attributes: ["step": stepCount])

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: navDwellTime)) { [weak self] in
            guard let self, let coordinator = self.coordinator else { return }
            coordinator.navigationController.popViewController(animated: true)
            self.isNavigating = false
        }
    }

    // MARK: - Telemetry Dispatch

    private func performRandomTelemetry() {
        let actions: [() -> Void] = [
            recordRandomEvent,
            recordRandomEvent,
            recordRandomBreadcrumb,
            recordRandomError,
            recordRandomLog,
            setRandomAttribute,
            simulateRandomNetworkRequest,
        ]
        actions.randomElement()?()
    }

    // MARK: - Custom Events

    private let eventNames = [
        "ScreenView", "ButtonTap", "FormSubmit",
        "SearchQuery", "ItemSelected", "ContentLoaded", "PurchaseIntent",
        "FeatureUsed", "OnboardingStep", "SessionMilestone", "AppInteraction",
    ]

    private let eventAttributeSets: [[String: Any]] = [
        ["screen": "home", "source": "organic"],
        ["component": "header", "variant": "v2"],
        ["userId": "u_1234", "platform": "ios"],
        ["feature": "search", "region": "us-east"],
        ["category": "entertainment", "duration": 42],
        ["campaign": "spring_promo", "itemCount": 3],
        ["errorCode": 404, "retryCount": 2],
        ["theme": "dark", "language": "en"],
        ["tabIndex": 2, "scrollDepth": 75],
        ["loadTime": 312, "cacheHit": "false"],
    ]

    private func recordRandomEvent() {
        var attrs = eventAttributeSets.randomElement()!
        attrs["step"] = stepCount
        attrs["randomValue"] = Int.random(in: 1...999)
        NewRelic.recordCustomEvent(eventNames.randomElement()!, attributes: attrs)
    }

    // MARK: - Breadcrumbs

    private let breadcrumbNames = [
        "NavigationEvent", "UserAction", "AppLifecycle", "DataLoaded",
        "NetworkRequest", "CacheHit", "CacheMiss", "AuthCheck",
        "PermissionRequest", "BackgroundTask", "DeepLinkHandled", "PushReceived",
    ]

    private func recordRandomBreadcrumb() {
        NewRelic.recordBreadcrumb(
            breadcrumbNames.randomElement()!,
            attributes: ["step": stepCount, "random": Int.random(in: 1...9999)]
        )
    }

    // MARK: - Errors

    private enum WalkError: Error {
        case timeout, networkFailure, parseError, authExpired, resourceNotFound, validationFailed, rateLimited
    }

    private func recordRandomError() {
        let errors: [Error] = [
            WalkError.timeout,
            WalkError.networkFailure,
            WalkError.parseError,
            WalkError.authExpired,
            WalkError.resourceNotFound,
            WalkError.validationFailed,
            WalkError.rateLimited,
            URLError(.timedOut),
            URLError(.cannotConnectToHost),
            URLError(.networkConnectionLost),
            URLError(.badServerResponse),
        ]
        NewRelic.recordError(
            errors.randomElement()!,
            attributes: ["step": stepCount, "source": "RandomWalk"]
        )
    }

    // MARK: - Logs

    private let logMessages = [
        "User navigated to home screen",
        "Cache miss for key: user_prefs",
        "Network request completed",
        "Background sync started",
        "Feature flag evaluated: new_ui=true",
        "Memory pressure warning received",
        "Push notification received",
        "App entered background",
        "Session token refreshed",
        "Local data persisted successfully",
        "UI layout recalculated",
        "Scheduled background task fired",
    ]

    private func recordRandomLog() {
        let msg = (logMessages.randomElement() ?? "log") + " [step:\(stepCount)]"
        let loggers: [() -> Void] = [
            { NewRelic.logInfo(msg) },
            { NewRelic.logDebug(msg) },
            { NewRelic.logWarning(msg) },
            { NewRelic.logVerbose(msg) },
        ]
        loggers.randomElement()?()
    }

    // MARK: - Attributes

    private let attributePool: [(String, Any)] = [
        ("walkTheme", "dark"), ("walkTheme", "light"),
        ("walkUserType", "free"), ("walkUserType", "premium"), ("walkUserType", "trial"),
        ("walkLanguage", "en"), ("walkLanguage", "es"), ("walkLanguage", "fr"), ("walkLanguage", "de"),
        ("walkRegion", "us-east"), ("walkRegion", "eu-west"), ("walkRegion", "ap-south"),
        ("walkFeature", "search"), ("walkFeature", "checkout"), ("walkFeature", "profile"),
        ("walkBuild", "release"), ("walkBuild", "beta"),
    ]

    private func setRandomAttribute() {
        let (key, value) = attributePool.randomElement()!
        NewRelic.setAttribute(key, value: value)
    }

    // MARK: - Network

    private let simulatedURLs = [
        "https://api.example.com/v2/users",
        "https://api.example.com/v2/posts",
        "https://cdn.example.com/assets/images",
        "https://analytics.example.com/events",
        "https://auth.example.com/token/refresh",
        "https://api.example.com/v2/products",
        "https://search.example.com/query",
        "https://payments.example.com/checkout",
    ]

    private let httpMethods = ["GET", "POST", "PUT", "DELETE", "PATCH"]

    private func simulateRandomNetworkRequest() {
        guard let url = URL(string: simulatedURLs.randomElement()!) else { return }
        let method = httpMethods.randomElement()!

        if Double.random(in: 0...1) < 0.15 {
            let failureCodes = [
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
            ]
            NewRelic.noticeNetworkFailure(
                for: url, httpMethod: method,
                with: NRTimer(), andFailureCode: failureCodes.randomElement()!
            )
        } else {
            let statusCodes = [200, 200, 200, 201, 204, 400, 401, 403, 404, 422, 500, 503]
            NewRelic.noticeNetworkRequest(
                for: url, httpMethod: method,
                with: NRTimer(), responseHeaders: [:],
                statusCode: statusCodes.randomElement()!,
                bytesSent: UInt.random(in: 64...8192),
                bytesReceived: UInt.random(in: 128...65536),
                responseData: Data(), traceHeaders: nil, andParams: nil
            )
        }
    }

    // MARK: - Overlay

    private func attachOverlay() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return }

        let overlay = RandomWalkOverlayView(frame: .zero)
        overlay.onStop = { [weak self] in self?.stop() }
        window.addSubview(overlay)

        let size = CGSize(width: 164, height: 40)
        let insets = window.safeAreaInsets
        let x = window.bounds.maxX - insets.right - size.width - 16
        let y = window.bounds.maxY - insets.bottom - size.height - 20
        overlay.frame = CGRect(origin: CGPoint(x: x, y: y), size: size)

        self.overlayView = overlay
    }

    private func detachOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }
}

// MARK: - RandomWalkOverlayView

final class RandomWalkOverlayView: UIView {

    var onStop: (() -> Void)?

    var stepCount: Int = 0 {
        didSet { statusLabel.text = "🐒 \(stepCount) steps" }
    }

    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(white: 0.1, alpha: 0.88)
        layer.cornerRadius = 14
        layer.masksToBounds = true
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        layer.borderWidth = 0.5

        statusLabel.text = "🐒 0 steps"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)

        let stopButton = UIButton(type: .system)
        stopButton.setTitle("✕", for: .normal)
        stopButton.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
        stopButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        stopButton.setContentHuggingPriority(.required, for: .horizontal)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, stopButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    @objc private func stopTapped() { onStop?() }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let t = gesture.translation(in: superview)
        center = CGPoint(x: center.x + t.x, y: center.y + t.y)
        gesture.setTranslation(.zero, in: superview)
    }
}
