//
//  ClassifiedKind.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

public enum ClassifiedKind: CustomStringConvertible, Equatable, Hashable {
    case text(String)
    case button
    case textField
    case image
    case toggle
    case slider
    case stepper
    case datePicker
    case picker
    case scrollView
    case table
    case list

   // case view

    case other(name: String)

    public var description: String {
        switch self {
        case .text(let text):
            // Sanitize text for use in a path identifier
            let sanitizedText = text.prefix(20).trimmingCharacters(in: .whitespacesAndNewlines)
            return "Text(\"\(sanitizedText)\")"
        case .button: return "Button"
        case .textField: return "TextField"
        case .image: return "Image"
        case .toggle: return "Toggle"
        case .slider: return "Slider"
        case .stepper: return "Stepper"
        case .datePicker: return "DatePicker"
        case .picker: return "Picker"
       // case .view: return "View"
        case .scrollView: return "ScrollView"
        case .table: return "Table"
        case .list: return "List"
        case .other(let name): return name
        }
    }
}

@available(iOS 14.0, *)
/// Recursively unwraps `ModifiedContent` to classify the underlying view.
func classifyView(_ view: some View) -> ClassifiedKind {
    return recursivelyClassifyView(value: view)
}

@available(iOS 14.0, *)
private func recursivelyClassifyView(value: Any) -> ClassifiedKind {
    let mirror = Mirror(reflecting: value)
    let viewType = String(describing: mirror.subjectType)

    print("Classifying view of type: \(viewType)")
    // --- Recursive Step ---
    // If the view is a modifier, unwrap it and recurse on its content.
    if viewType == ("ModifiedContent"), let content = mirror.children.first(where: { $0.label == "content" })?.value {
        return recursivelyClassifyView(value: content)
    }

    // --- Base Case ---
    // The view is not a modifier, so we classify the concrete type.
    if let text = getTextFromMirror(mirror) {
        return .text(text)
    }

    if viewType == ("List") { return .list }

    if viewType == ("Button") { return .button }
    if viewType == ("TextField") { return .textField }
//    if viewType.contains("Image") { return .image }
    if viewType == ("Toggle") { return .toggle }
    if viewType == ("Slider") { return .slider }
    if viewType == ("Stepper") { return .stepper }
    if viewType == ("DatePicker") { return .datePicker }
    if viewType == ("Picker") { return .picker }
    
    return .other(name: viewType)
}
@available(iOS 14.0, *)
private func getTextFromMirror(_ mirror: Mirror) -> String? {
    // Attempt to find a 'text', 'label', 'title', or similar property via Mirror
    for child in mirror.children {
        if let label = child.label, ["text", "_text", "label", "title", "_title"].contains(label) {
            if let text = child.value as? String {
                return text
            }
            if let localizedStringKey = child.value as? LocalizedStringKey {
                 let keyMirror = Mirror(reflecting: localizedStringKey)
                 if let key = keyMirror.children.first(where: { $0.label == "key" })?.value as? String {
                     return key
                 }
            }
        }
    }
    return nil
}
