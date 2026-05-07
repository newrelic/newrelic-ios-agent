#if DEBUG

import UIKit

@available(iOS 16.0, *)
enum SRDevHUDInstaller {
    private static var window: UIWindow?
    private static var observer: NSObjectProtocol?

    /// Installs the HUD window on the next active UIWindowScene. Safe to call multiple times;
    /// subsequent calls are no-ops while a HUD window is already attached.
    static func install() {
        guard window == nil, observer == nil else { return }

        // Install immediately if a scene is already active (normal launch path).
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
            window = SRDevHUDWindow(scene: scene)
            return
        }

        // Otherwise wait for the first scene to activate.
        observer = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { note in
            guard window == nil, let scene = note.object as? UIWindowScene else { return }
            window = SRDevHUDWindow(scene: scene)
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
                Self.observer = nil
            }
        }
    }
}

#endif
