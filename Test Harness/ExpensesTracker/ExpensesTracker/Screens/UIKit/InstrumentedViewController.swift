//
//  InstrumentedViewController.swift
//  ExpensesTracker
//
//  The base class for every UIKit screen in the app. It carries the instrumentation the Android
//  Activities and Fragments each repeated by hand.
//
//  What it does, and why each piece is here:
//
//    * Reports the screen with `NewRelic.setCurrentView(_:attributes:)` on appear, using a `ViewName`
//      case. Automatic view tracking is also on, so the agent independently emits events named after
//      the view controller *class* — that is intentional, not an oversight. This app is a validation
//      vehicle: having both means a MobileView query shows the automatic name and the deliberate one
//      side by side, and the manual API gets exercised on every screen rather than on one. The
//      readable names in `ViewName` are the ones NRQL expectations should be written against.
//
//    * Logs the lifecycle. The Android app peppered onCreate/onResume/onPause/onDestroy with
//      NewRelic.logInfo and logDebug calls; doing it once here covers every screen instead of the
//      three that happened to get it.
//
//    * Reports rotation. MainActivity and incomeFragment both overrode onConfigurationChanged to log
//      the new orientation and record an `<screen>_orientation_change` custom event, then toast it.
//      `viewWillTransition(to:with:)` is the iOS hook for the same moment, and every screen gets it.
//
//  Screens override `viewName`; nothing else is required of them.
//

import UIKit
import NewRelic

class InstrumentedViewController: UIViewController {

    /// The name this screen reports. Every subclass overrides it.
    var viewName: ViewName { .home }

    /// Attributes merged into this screen's MobileView event. Subclasses that have something worth
    /// faceting on — a record's purpose, a ledger's kind — override this.
    var viewAttributes: [String: Any] { [:] }

    /// Set by screens that should open an interaction trace around their own work, the way the Android
    /// app wrapped MainActivity in startInteraction/endInteraction. Off by default: an interaction per
    /// screen would say nothing that the view events do not already say.
    var tracksInteraction: Bool { false }

    /// Whether `viewDidAppear` reports the view by itself.
    ///
    /// True for every screen you navigate to. False for a screen that is installed as a child view
    /// controller but only *shown* later — the side menu is added to Home at load time, so its
    /// `viewDidAppear` fires when Home appears, with the drawer still off-screen. Such a screen calls
    /// `reportView()` at the moment it actually becomes visible.
    var reportsViewOnAppear: Bool { true }

    private var interactionID: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        // Light-mode only, matching the Android app's palette. See Theme.
        overrideUserInterfaceStyle = .light

        NewRelic.logInfo("\(viewName.rawValue): viewDidLoad")

        if tracksInteraction {
            interactionID = NewRelic.startInteraction(withName: viewName.rawValue)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if reportsViewOnAppear {
            reportView()
        }
        NewRelic.logDebug("\(viewName.rawValue): viewDidAppear")

        if let interactionID {
            NewRelic.stopCurrentInteraction(interactionID)
            self.interactionID = nil
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NewRelic.logDebug("\(viewName.rawValue): viewWillDisappear")
    }

    /// Reports this screen as the current view. Called from `viewDidAppear` unless
    /// `reportsViewOnAppear` is false, in which case the screen's owner calls it.
    func reportView() {
        NewRelic.setCurrentView(viewName.rawValue, attributes: viewAttributes)
    }

    // MARK: - Rotation

    override func viewWillTransition(to size: CGSize,
                                    with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        let orientation = size.width > size.height ? "landscape" : "portrait"

        NewRelic.logDebug("\(viewName.rawValue)_orientation - \(orientation.uppercased())")
        NewRelic.recordCustomEvent("orientation_change", attributes: [
            "orientation": orientation,
            "screen": viewName.rawValue
        ])

        showToast("Mode: \(orientation)")
    }
}
