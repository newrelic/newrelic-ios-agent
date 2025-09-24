//
//  SessionReplaySwiftUITagging.swift
//  Agent
//
//  Provides a SwiftUI ViewModifier and supporting UIKit plumbing to allow
//  developers to explicitly declare the semantic type of a SwiftUI view
//  for session replay masking purposes (application text, user input text, image).
//
//  Usage:
//      Text("Hello")
//          .sessionReplayType(.applicationText)
//
//      TextField("Email", text: $email)
//          .sessionReplayType(.userInputText)
//
//      Image("Logo")
//          .sessionReplayType(.image)
//
//  The modifier injects an invisible marker view (SRTagMarkerView) whose lifecycle
//  is used to locate the nearest non-marker ancestor UIView (typically a SwiftUI
//  hosting view) and assigns an associated property `sessionReplayDeclaredType`.
//  The traversal/capture layer (SessionReplayCapture.findRecorderForView) will
//  read this property first and choose the correct Thingy + masking policy.
//

import Foundation
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

@objc public enum SessionReplayDeclaredType: Int {
    case applicationText
    case userInputText
    case image
}

@available(iOS 13.0, *)
private enum SRAssociatedKeys {
    // Use a stable address key; avoids UnsafeRawPointer warnings with String.
    static var declaredTypeKey: UInt8 = 0
}

@available(iOS 13.0, *)
internal extension UIView {
    var sessionReplayDeclaredType: SessionReplayDeclaredType? {
        get {
            if let num = objc_getAssociatedObject(self, &SRAssociatedKeys.declaredTypeKey) as? NSNumber {
                return SessionReplayDeclaredType(rawValue: num.intValue)
            }
            return nil
        }
        set {
            if let v = newValue {
                objc_setAssociatedObject(self, &SRAssociatedKeys.declaredTypeKey, NSNumber(value: v.rawValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &SRAssociatedKeys.declaredTypeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }

    var sessionReplayEffectiveDeclaredType: SessionReplayDeclaredType? {
        var v: UIView? = self
        while let current = v {
            if let t = current.sessionReplayDeclaredType { return t }
            v = current.superview
        }
        return nil
    }
}

@available(iOS 13.0, *)
class SRTagMarkerView: UIView {
    var declaredType: SessionReplayDeclaredType?
    var masked: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        accessibilityIdentifier = "sr-tag-marker"
        isAccessibilityElement = false
        alpha = 0.0
        isHidden = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        accessibilityIdentifier = "sr-tag-marker"
        isAccessibilityElement = false
        alpha = 0.0
        isHidden = true
    }

    // Make sure it never participates in layout sizing.
    override var intrinsicContentSize: CGSize { .zero }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        applyToSuperview()
    }

    func applyToSuperview() {
        guard let host = superview else { return }
        if let t = declaredType { host.sessionReplayDeclaredType = t }
        host.sessionReplayMaskState = masked
        // Keep the marker invisible at all times.
        isHidden = true
        alpha = 0.0
    }
}

@available(iOS 13.0, *)
struct SessionReplayTagAnchorView: UIViewRepresentable {
    let declaredType: SessionReplayDeclaredType?
    let masked: Bool

    func makeUIView(context: Context) -> SRTagMarkerView {
        let v = SRTagMarkerView(frame: .zero)
        v.isUserInteractionEnabled = false
        v.isHidden = true
        return v
    }

    func updateUIView(_ uiView: SRTagMarkerView, context: Context) {
        uiView.declaredType = declaredType
        uiView.masked = masked
        // If already in the hierarchy, apply immediately; otherwise it runs in didMoveToSuperview.
        uiView.applyToSuperview()
    }
}

@available(iOS 13.0, *)
public struct SessionReplayTagModifier: ViewModifier {
    let declaredType: SessionReplayDeclaredType?
    let masked: Bool

    public func body(content: Content) -> some View {
        // Use background with zero size so it never overlays or affects snapshots.
        if #available(iOS 14.0, *) {
            content.background(
                SessionReplayTagAnchorView(declaredType: declaredType, masked: masked)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            )
        }
    }
}

@available(iOS 13.0, *)
public extension View {
    func sessionReplayType(_ type: SessionReplayDeclaredType, masked: Bool = true) -> some View {
        modifier(SessionReplayTagModifier(declaredType: type, masked: masked))
    }

    func sessionReplayMasked(_ masked: Bool = true) -> some View {
        modifier(SessionReplayTagModifier(declaredType: nil, masked: masked))
    }
}

//// Hidden marker view that requests retagging when hierarchy changes.
//class SRTagMarkerView: UIView {
//    var onHierarchyChange: (() -> Void)?
//
//    override func didMoveToSuperview() {
//        super.didMoveToSuperview()
//        scheduleRetag()
//    }
//
//    override func didMoveToWindow() {
//        super.didMoveToWindow()
//        scheduleRetag()
//    }
//
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        // Layout can reflect SwiftUI reparenting/promotions; throttle retag.
//        scheduleRetag()
//    }
//
//    private var isScheduled = false
//    private func scheduleRetag() {
//        guard !isScheduled else { return }
//        isScheduled = true
//        DispatchQueue.main.async { [weak self] in
//            self?.isScheduled = false
//            self?.onHierarchyChange?()
//        }
//    }
//}
//
//private var associatedDeclaredTypeKey: UInt8 = 0
//
//extension UIView {
//    private func sr_findEffectiveTag<T>(_ getter: (UIView) -> T?, maxHops: Int = 32) -> T? {
//        var hops = 0
//        var node: UIView? = self
//        while let cur = node, hops < maxHops {
//            // 1) direct tag on this node
//            if let val = getter(cur) { return val }
//
//            // 2) SR marker siblings on the same level
//            if let parent = cur.superview {
//                for sib in parent.subviews where sib !== cur {
//                    if sib is SRTagMarkerView, let val = getter(sib) {
//                        return val
//                    }
//                }
//            }
//
//            // 3) Some SwiftUI containers tag the single content child
//            let nonMarkerChildren = cur.subviews.filter { !($0 is SRTagMarkerView) }
//            if nonMarkerChildren.count == 1, let only = nonMarkerChildren.first {
//                if let val = getter(only) { return val }
//            }
//
//            // 4) ascend
//            node = cur.superview
//            hops += 1
//        }
//        return nil
//    }
//    
//    var sessionReplayEffectiveDeclaredType: SessionReplayDeclaredType? {
//        sr_findEffectiveTag { $0.sessionReplayDeclaredType }
//    }
//
//    var sessionReplayEffectiveMaskState: Bool? {
//        sr_findEffectiveTag { $0.sessionReplayMaskState }
//    }
//    
//    var sessionReplayDeclaredType: SessionReplayDeclaredType? {
//        get {
//            guard let raw = objc_getAssociatedObject(self, &associatedDeclaredTypeKey) as? Int,
//                  let value = SessionReplayDeclaredType(rawValue: raw) else { return nil }
//            return value
//        }
//        set {
//            if let v = newValue {
//                objc_setAssociatedObject(self, &associatedDeclaredTypeKey, v.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//            } else {
//                objc_setAssociatedObject(self, &associatedDeclaredTypeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
//            }
//        }
//    }
//}
//
//#if canImport(SwiftUI)
//@available(iOS 13.0, *)
//private struct SessionReplayTypeModifier: ViewModifier {
//    let type: SessionReplayDeclaredType
//    let isMasked: Bool
//
//    func body(content: Content) -> some View {
//        if #available(iOS 14.0, *) {
//            content
//                .background(SessionReplayTypeSetter(type: type, isMasked: isMasked).frame(width: 0, height: 0))
//                .allowsHitTesting(false)
//                .accessibilityHidden(true)
//        } else {
//            // Fallback on iOS 13: still inject the marker without extra modifiers
//            content
//                .background(SessionReplayTypeSetter(type: type, isMasked: isMasked).frame(width: 0, height: 0))
//        }
//    }
//}
//
//@available(iOS 13.0, *)
//private struct SessionReplayTypeSetter: UIViewRepresentable {
//    let type: SessionReplayDeclaredType
//    let isMasked: Bool
//
//    func makeCoordinator() -> Coordinator { Coordinator(type: type, isMasked: isMasked) }
//
//    func makeUIView(context: Context) -> SRTagMarkerView {
//        let view = SRTagMarkerView(frame: .zero)
//        view.isHidden = true
//        let coordinator = context.coordinator
//        view.onHierarchyChange = { [weak view, coordinator] in
//            guard let view = view else { return }
//            coordinator.applyTag(from: view)
//        }
//        // First pass after insertion.
//        DispatchQueue.main.async { [weak view, coordinator] in
//            guard let view = view else { return }
//            coordinator.applyTag(from: view)
//        }
//        return view
//    }
//
//    func updateUIView(_ uiView: SRTagMarkerView, context: Context) {
//        // Re-apply in case SwiftUI reparented or rehosted the view.
//        context.coordinator.applyTag(from: uiView)
//    }
//
//    final class Coordinator {
//        let type: SessionReplayDeclaredType
//        let isMasked: Bool
//
//        init(type: SessionReplayDeclaredType, isMasked: Bool) {
//            self.type = type
//            self.isMasked = isMasked
//        }
//
//        func applyTag(from marker: SRTagMarkerView) {
//            guard let target = nearestNonMarkerAncestor(from: marker) else { return }
//            // Stamp only the nearest concrete ancestor, mirroring PostHog's approach.
//            if target.sessionReplayDeclaredType != type {
//                target.sessionReplayDeclaredType = type
//            }
//            if target.sessionReplayMaskState != isMasked {
//                target.sessionReplayMaskState = isMasked
//            }
//        }
//
//        private func nearestNonMarkerAncestor(from marker: SRTagMarkerView) -> UIView? {
//            var parent: UIView? = marker.superview
//            // Skip our marker(s)
//            while let p = parent, p is SRTagMarkerView { parent = p.superview }
//            guard let start = parent else { return nil }
//
//            // Prefer a likely SwiftUI content container if present by walking down
//            // one level to a single SwiftUI content child; otherwise use start.
//            if let content = singleSwiftUIContentChild(of: start) {
//                return content
//            }
//            return start
//        }
//
//        private func singleSwiftUIContentChild(of view: UIView) -> UIView? {
//            let children = view.subviews
//            guard children.count == 1 else { return nil }
//            let child = children[0]
//            let name = NSStringFromClass(Swift.type(of: child))
//            // Heuristic similar to PostHog: prefer SwiftUI hosting internals as the content node.
//            if name.contains("SwiftUI") || name.contains("UIHosting") || name.hasPrefix("_Tt") {
//                return child
//            }
//            return nil
//        }
//    }
//}
//
//@available(iOS 13.0, *)
//public extension View {
//    func sessionReplayType(_ type: SessionReplayDeclaredType, isMasked: Bool = false) -> some View {
//        modifier(SessionReplayTypeModifier(type: type, isMasked: isMasked))
//    }
//}
//#endif
