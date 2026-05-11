#if DEBUG

import UIKit
import NewRelic

/// Renders the Session Replay capture's view geometry as colored rectangles
/// over the app. Rects come from `SessionReplayManager.debugCaptureOverlayRects()`
/// and use the exact frames the agent would serialize into the replay.
@available(iOS 13.0, *)
final class SRDebugOverlayView: UIView {

    var rects: [SRDebugOverlayRect] = [] {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) unused") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !rects.isEmpty else { return }

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: UIColor.white
        ]

        for r in rects {
            let color = Self.color(for: r.kind)
            ctx.setStrokeColor(color.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(1.0)
            ctx.setFillColor(color.withAlphaComponent(0.08).cgColor)

            ctx.addRect(r.frame)
            ctx.drawPath(using: .fillStroke)

            // Skip labels on very small rects so we don't scribble over them.
            guard r.frame.width >= 60, r.frame.height >= 14 else { continue }

            let label = "\(r.viewName)#\(r.viewId)" as NSString
            let size = label.size(withAttributes: labelAttrs)
            let padding: CGFloat = 3
            let bgRect = CGRect(
                x: r.frame.minX,
                y: r.frame.minY,
                width: min(size.width + padding * 2, r.frame.width),
                height: size.height + padding * 2
            )
            ctx.setFillColor(color.withAlphaComponent(0.85).cgColor)
            ctx.fill(bgRect)

            let textOrigin = CGPoint(x: bgRect.minX + padding, y: bgRect.minY + padding)
            label.draw(at: textOrigin, withAttributes: labelAttrs)
        }
    }

    static func color(for kind: SRDebugOverlayKind) -> UIColor {
        switch kind {
        case .regular:     return UIColor.systemGreen
        case .masked:      return UIColor.systemOrange
        case .blocked:     return UIColor.systemRed
        case .swiftUIHost: return UIColor.systemPurple
        case .clear:       return UIColor.systemYellow
        @unknown default:  return UIColor.systemGray
        }
    }
}

#endif
