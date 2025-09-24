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
//  NOTE: This intentionally avoids relying on private SwiftUI APIs; it uses
//  a best-effort parent chain search on the next run loop pass when the view
//  has been added to the hierarchy.
//

import Foundation
import UIKit
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Declared Type Enum
@objc public enum SessionReplayDeclaredType: Int {
    case applicationText
    case userInputText
    case image
}

// MARK: - Marker View
/// Internal marker view inserted by the SwiftUI modifier. It remains hidden.
/// We skip capturing this view directly and only use it to stamp the parent.
class SRTagMarkerView: UIView {}

// MARK: - UIView Associated Property
private var associatedDeclaredTypeKey: UInt8 = 0

extension UIView {
    // Removed @objc to avoid Objective-C representability issue with optional enum property
    var sessionReplayDeclaredType: SessionReplayDeclaredType? {
        get {
            guard let raw = objc_getAssociatedObject(self, &associatedDeclaredTypeKey) as? Int,
                  let value = SessionReplayDeclaredType(rawValue: raw) else { return nil }
            return value
        }
        set {
            if let v = newValue {
                objc_setAssociatedObject(self, &associatedDeclaredTypeKey, v.rawValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &associatedDeclaredTypeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
}

#if canImport(SwiftUI)
@available(iOS 13.0, *)
private struct SessionReplayTypeModifier: ViewModifier {
    let type: SessionReplayDeclaredType
    func body(content: Content) -> some View {
        content.background(SessionReplayTypeSetter(type: type).frame(width: 0, height: 0))
    }
}

@available(iOS 13.0, *)
private struct SessionReplayTypeSetter: UIViewRepresentable {
    let type: SessionReplayDeclaredType

    func makeUIView(context: Context) -> SRTagMarkerView {
        let view = SRTagMarkerView(frame: .zero)
        view.isHidden = true
        propagateTypeAsync(from: view)
        return view
    }

    func updateUIView(_ uiView: SRTagMarkerView, context: Context) {
        propagateTypeAsync(from: uiView)
    }

    private func propagateTypeAsync(from marker: SRTagMarkerView) {
        DispatchQueue.main.async { [weak marker] in
            guard let marker = marker else { return }
            // Climb up until we find a non-marker view to tag.
            var parent = marker.superview
            while let p = parent, p is SRTagMarkerView { parent = p.superview }
            // If we found a parent, set the declared type.
            parent?.sessionReplayDeclaredType = type
        }
    }
}

@available(iOS 13.0, *)
public extension View {
    /// Assign an explicit session replay semantic type to this SwiftUI view so masking rules can apply correctly.
    /// - Parameter type: The declared semantic type (.applicationText, .userInputText, .image)
    /// - Returns: Modified view carrying the semantic type.
    func sessionReplayType(_ type: SessionReplayDeclaredType) -> some View {
        modifier(SessionReplayTypeModifier(type: type))
    }
}
#endif
