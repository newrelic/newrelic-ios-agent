import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension ViewType {
    
    struct ClassifiedView: KnownViewType {
        public static let typePrefix: String = ""
        public static var isTransitive: Bool { true }
    }
    
    struct ParentView: KnownViewType {
        public static let typePrefix: String = ""
    }
}

// MARK: - Content Extraction

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension ViewType.ClassifiedView: SingleViewContent {
    
    public static func child(_ content: ViewInspectorContent) throws -> ViewInspectorContent {
        return content
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension ViewType.ParentView: SingleViewContent {
    
    public static func child(_ content: ViewInspectorContent) throws -> ViewInspectorContent {
        return content
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
extension ViewType.ClassifiedView: MultipleViewContent {
    
    public static func children(_ content: ViewInspectorContent) throws -> LazyGroup<ViewInspectorContent> {
        return try Inspector.viewsInContainer(view: content.view, medium: content.medium)
    }
}
