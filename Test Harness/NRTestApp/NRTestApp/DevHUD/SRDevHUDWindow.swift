#if DEBUG

import UIKit
import SwiftUI
import NewRelic

/// A separate UIWindow at alert level that hosts the Dev HUD overlay and the
/// captured-view debug overlay. Touches outside the HUD pass through to the app
/// window below; the debug overlay is always pass-through.
///
/// Subclassing `SessionReplayDebugOverlayMarkerWindow` lets the agent's debug
/// capture skip this window when picking the key window to record.
@available(iOS 16.0, *)
final class SRDevHUDWindow: SessionReplayDebugOverlayMarkerWindow {

    /// The actual HUD content view (UIHostingController.view). Touches that don't
    /// land inside this view's tree are passed through to the window beneath.
    private weak var hudContentView: UIView?

    /// Strong reference — the controller owns a Timer, and `SRDebugOverlayController.shared`
    /// is a weak pointer. Without this strong ref the controller deallocates immediately
    /// and the HUD toggle has nothing to start.
    private let overlayController: SRDebugOverlayController

    init(scene: UIWindowScene) {
        let overlay = SRDebugOverlayView(frame: .zero)
        overlay.isHidden = true
        self.overlayController = SRDebugOverlayController(view: overlay)

        super.init(windowScene: scene)
        self.windowLevel = .alert + 1
        self.backgroundColor = .clear
        self.isUserInteractionEnabled = true

        let host = UIHostingController(rootView: SRDevHUDView())
        host.view.backgroundColor = .clear
        host.sizingOptions = [.intrinsicContentSize]
        self.hudContentView = host.view

        self.rootViewController = SRDevHUDRootViewController(content: host, overlay: overlay)
        self.isHidden = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    /// Only consume a touch if it lands inside the HUD's hosting view tree.
    /// Anything else returns nil so UIKit walks to the next window.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        guard let hud = hudContentView else { return nil }
        return (hit === hud || hit.isDescendant(of: hud)) ? hit : nil
    }
}

@available(iOS 16.0, *)
final class SRDevHUDRootViewController: UIViewController {
    private let content: UIViewController
    private let overlay: SRDebugOverlayView

    init(content: UIViewController, overlay: SRDebugOverlayView) {
        self.content = content
        self.overlay = overlay
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    override func loadView() {
        self.view = UIView()
        self.view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Overlay is added first so it sits behind the HUD pill/panel.
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        content.view.backgroundColor = .clear
        view.addSubview(content.view)
        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            content.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
        content.didMove(toParent: self)
    }
}

#endif
