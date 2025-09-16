//
//  IntrospectedDataManager.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

@available(iOS 14.0, *)
public struct IntrospectedUIKitData {
    public let path: String
    public let kind: ClassifiedKind
    public let frame: CGRect
    public let properties: [String: Any]

    public init(path: String, kind: ClassifiedKind, frame: CGRect, properties: [String: Any] = [:]) {
        self.path = path
        self.kind = kind
        self.frame = frame
        self.properties = properties
    }
}

@available(iOS 14.0, *)
@MainActor
public class IntrospectedDataManager {
    public static let shared = IntrospectedDataManager()
    private init() {}

    public private(set) var introspectedData: [String: IntrospectedUIKitData] = [:]

    public func addIntrospectedData(_ data: IntrospectedUIKitData) {
        introspectedData[data.path] = data
        print("[IntrospectedDataManager] Added introspected data for path: \(data.path)")
    }

    public func getIntrospectedData(for path: String) -> IntrospectedUIKitData? {
        return introspectedData[path]
    }

    public func clearAll() {
        introspectedData.removeAll()
        print("[IntrospectedDataManager] Cleared all introspected data")
    }

    public func extractTextProperties(from label: UILabel) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["text"] = label.text
        properties["font"] = label.font
        properties["textColor"] = label.textColor
        properties["textAlignment"] = label.textAlignment.rawValue
        properties["numberOfLines"] = label.numberOfLines
        properties["lineBreakMode"] = label.lineBreakMode.rawValue
        return properties
    }

    public func extractTextFieldProperties(from textField: UITextField) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["text"] = textField.text
        properties["placeholder"] = textField.placeholder
        properties["font"] = textField.font
        properties["textColor"] = textField.textColor
        properties["textAlignment"] = textField.textAlignment.rawValue
        properties["isSecureTextEntry"] = textField.isSecureTextEntry
        properties["keyboardType"] = textField.keyboardType.rawValue
        properties["returnKeyType"] = textField.returnKeyType.rawValue
        properties["isEnabled"] = textField.isEnabled
        return properties
    }

    public func extractButtonProperties(from button: UIButton) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["title"] = button.title(for: .normal)
        properties["titleColor"] = button.titleColor(for: .normal)
        properties["font"] = button.titleLabel?.font
        properties["isEnabled"] = button.isEnabled
        properties["isHighlighted"] = button.isHighlighted
        properties["isSelected"] = button.isSelected
        properties["backgroundImage"] = button.backgroundImage(for: .normal) != nil
        properties["image"] = button.image(for: .normal) != nil
        return properties
    }

    public func extractGenericViewProperties(from view: UIView) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["backgroundColor"] = view.backgroundColor
        properties["alpha"] = view.alpha
        properties["isHidden"] = view.isHidden
        properties["isUserInteractionEnabled"] = view.isUserInteractionEnabled
        properties["clipsToBounds"] = view.clipsToBounds
        properties["contentMode"] = view.contentMode.rawValue
        return properties
    }
}