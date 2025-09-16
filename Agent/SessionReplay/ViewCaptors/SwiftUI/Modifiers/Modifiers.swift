//
//  Modifiers.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 14.0, *)
@available(tvOS 14.0, *)
public extension View {
    /// Attaches the decompiler's data collector to a view hierarchy.
    /// Apply this to your root SwiftUI view.
    func decompile() -> some View {
        self.modifier(DecompilerCollector())
    }
    
    /// Marks a view and its children as trackable.
    func trackable() -> some View {
        // Return a custom wrapper View instead of a ViewModifier.
        // This preserves the concrete type of `self` for correct classification.
        TrackableWrapper(content: self)
    }
}

@available(iOS 14.0, *)
struct GenericLeafModifier: ViewModifier {
    @Environment(\.decompilerPath) var path
    let kind: ClassifiedKind
    init(kind: ClassifiedKind) {
        self.kind = kind
    }
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry in
                Color.clear.preference(key: LeafPathPreferenceKey.self, value: [LeafPath(fullPath: path, classification: kind, frame: geometry.frame(in: .global))])
            }
        )
    }
}

public struct LeafPath: Identifiable, Hashable {
    public var id: String { fullPath }
    public var fullPath: String
    public var classification: ClassifiedKind
    public var frame: CGRect

    public init(fullPath: String, classification: ClassifiedKind, frame: CGRect = .zero) {
        self.fullPath = fullPath
        self.classification = classification
        self.frame = frame
    }
}
// remak LeafPath as PreferenceKey
struct LeafPathPreferenceKey: PreferenceKey {
    typealias Value = [LeafPath]
    static var defaultValue: [LeafPath] = []
    static func reduce(value: inout [LeafPath], nextValue: () -> [LeafPath]) {
        value.append(contentsOf: nextValue())
    }
}

@available(iOS 14.0, *)
public extension Text {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .text("")))
            .introspect(.view, on:  .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26), scope: .receiver) { view in
                // Find the UILabel within the view hierarchy
                if let label = findUILabel(in: view) {
                    let properties = IntrospectedDataManager.shared.extractTextProperties(from: label)
                    let path = "TEXT_INTROSPECTED_\(ObjectIdentifier(view).hashValue)"
                    let data = IntrospectedUIKitData(
                        path: path,
                        kind: .text(label.text ?? ""),
                        frame: view.frame,
                        properties: properties
                    )
                    IntrospectedDataManager.shared.addIntrospectedData(data)
                    print("Introspected UILabel with text: \(label.text ?? "nil")")
                }
            }
    }

    private func findUILabel(in view: UIView) -> UILabel? {
        if let label = view as? UILabel {
            return label
        }
        for subview in view.subviews {
            if let label = findUILabel(in: subview) {
                return label
            }
        }
        return nil
    }
}

@available(iOS 14.0, *)
public extension Button {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .button))
            .introspect(.view, on:  .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26), scope: .receiver) { view in
                // Find the UIButton within the view hierarchy
                if let button = findUIButton(in: view) {
                    let properties = IntrospectedDataManager.shared.extractButtonProperties(from: button)
                    let path = "BUTTON_INTROSPECTED_\(ObjectIdentifier(view).hashValue)"
                    let data = IntrospectedUIKitData(
                        path: path,
                        kind: .button,
                        frame: view.frame,
                        properties: properties
                    )
                    IntrospectedDataManager.shared.addIntrospectedData(data)
                    print("Introspected UIButton with title: \(button.title(for: .normal) ?? "nil")")
                } else {
                    let properties = IntrospectedDataManager.shared.extractGenericViewProperties(from: view)
                    let path = "BUTTON_INTROSPECTED_\(ObjectIdentifier(view).hashValue)"
                    let data = IntrospectedUIKitData(
                        path: path,
                        kind: .button,
                        frame: view.frame,
                        properties: properties
                    )
                    IntrospectedDataManager.shared.addIntrospectedData(data)
                    print("Introspected Button view (no UIButton found): \(view)")
                }
            }
    }

    private func findUIButton(in view: UIView) -> UIButton? {
        if let button = view as? UIButton {
            return button
        }
        for subview in view.subviews {
            if let button = findUIButton(in: subview) {
                return button
            }
        }
        return nil
    }
}

@available(iOS 14.0, *)
public extension TextField {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .textField))
            .introspect(.textField, on:  .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26), scope: .receiver) { textField in
                let properties = IntrospectedDataManager.shared.extractTextFieldProperties(from: textField)
                let path = "TEXTFIELD_INTROSPECTED_\(ObjectIdentifier(textField).hashValue)"
                let data = IntrospectedUIKitData(
                    path: path,
                    kind: .textField,
                    frame: textField.frame,
                    properties: properties
                )
                IntrospectedDataManager.shared.addIntrospectedData(data)
                print("Introspected UITextField with text: \(textField.text ?? "nil"), placeholder: \(textField.placeholder ?? "nil")")
            }
    }
}

@available(iOS 14.0, *)
public extension ScrollView {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .scrollView))
            .introspect(.scrollView, on:  .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26), scope: .receiver) { enity in
                print("Introspected a scrollView: \(enity)")
                
            }
    }
}

@available(iOS 16.0, *)
public extension Table {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .table))
            .introspect(.table, on: .iOS(.v16, .v17, .v18, .v26)) {
                print(type(of: $0)) // UICollectionView
                print("Introspected a table: \($0)")
                
            }
    }
}

@available(iOS 14.0, *)
public extension List {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .list))
        // SwiftUI list is diff iOS 13 -> 15
            .introspect(.list, on: .iOS(.v13, .v14, .v15)) {
                print("Introspected a List table: \($0)")
                // Introspected a List collection: <SwiftUI.UpdateCoalescingCollectionView: 0x107021600; baseClass = UICollectionView; frame = (0 0; 440 956); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600000c0de90>; backgroundColor = <UIDynamicSystemColor: 0x60000171a540; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x60000029e800>; contentOffset: {0, -152.33333333333334}; contentSize: {440, 187}; adjustedContentInset: {152.33333333333331, 0, 34.000000000000114, 0}; layout: <UICollectionViewCompositionalLayout: 0x10521b9b0>; dataSource: <_TtGC7SwiftUI31UICollectionViewListCoordinatorGVS_28CollectionViewListDataSourceOs5Never_GOS_19SelectionManagerBoxS2___: 0x105208830>>
                
            }
            .introspect(.list, on: .iOS(.v16, .v17, .v18, .v26)) {
                print("Introspected a List collection: \($0)")
                
                
                // Introspected a List collection: <SwiftUI.UpdateCoalescingCollectionView: 0x107021600; baseClass = UICollectionView; frame = (0 0; 440 956); clipsToBounds = YES; autoresize = W+H; gestureRecognizers = <NSArray: 0x600000c0de90>; backgroundColor = <UIDynamicSystemColor: 0x60000171a540; name = systemGroupedBackgroundColor>; layer = <CALayer: 0x60000029e800>; contentOffset: {0, -152.33333333333334}; contentSize: {440, 187}; adjustedContentInset: {152.33333333333331, 0, 34.000000000000114, 0}; layout: <UICollectionViewCompositionalLayout: 0x10521b9b0>; dataSource: <_TtGC7SwiftUI31UICollectionViewListCoordinatorGVS_28CollectionViewListDataSourceOs5Never_GOS_19SelectionManagerBoxS2___: 0x105208830>>
                
            }
    }
}

@available(iOS 14.0, *)
public extension Image {
    @MainActor func pathLeaf() -> some View {
        modifier(GenericLeafModifier(kind: .image))
            .introspect(.view, on:  .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26), scope: .receiver) { view in
                // Find the UIImageView within the view hierarchy
                if let imageView = findUIImageView(in: view) {
                    let properties = IntrospectedDataManager.shared.extractImageViewProperties(from: imageView)
                    let path = "IMAGE_INTROSPECTED_\(ObjectIdentifier(view).hashValue)"
                    let data = IntrospectedUIKitData(
                        path: path, kind: .image, frame: imageView.frame,
                        properties: properties
                    )
                    IntrospectedDataManager.shared.addIntrospectedData(data)
                    print("Introspected UIImageView with image: \(String(describing: imageView.image))")
                }
            }
    }

    private func findUIImageView(in view: UIView) -> UIImageView? {
        if let imageView = view as? UIImageView {
            return imageView
        }
        for subview in view.subviews {
            if let imageView = findUIImageView(in: subview) {
                return imageView
            }
        }
        return nil
    }
}
