import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
internal extension ViewType {
    struct ConditionalContent { }
    struct StaticIf { }
}

// MARK: - Content Extraction

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension ViewType.ConditionalContent: SingleViewContent {
    
    static func child(_ content: ViewInspectorContent) throws -> ViewInspectorContent {
        let storage = try Inspector.attribute(label: "storage", value: content.view)
        let medium = content.medium
        if let trueContent = try? Inspector.attribute(label: "trueContent", value: storage) {
            return try Inspector.unwrap(view: trueContent, medium: medium)
        }
        let falseContent = try Inspector.attribute(label: "falseContent", value: storage)
        return try Inspector.unwrap(view: falseContent, medium: medium)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension ViewType.StaticIf: SingleViewContent {

    static func child(_ content: ViewInspectorContent) throws -> ViewInspectorContent {
        let medium = content.medium
        if let trueContent = try? Inspector.attribute(label: "trueBody", value: content.view) {
            return try Inspector.unwrap(view: trueContent, medium: medium)
        }
        let falseContent = try Inspector.attribute(label: "falseBody", value: content.view)
        return try Inspector.unwrap(view: falseContent, medium: medium)
    }
}
