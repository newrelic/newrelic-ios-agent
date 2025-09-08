import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, *)
public extension ViewType {

    struct ContentUnavailableView: KnownViewType {
        public static let typePrefix: String = "ContentUnavailableView"
    }
}

// MARK: - Extraction from SingleViewContent parent

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension InspectableView where View: SingleViewContent {

    func contentUnavailableView() throws -> InspectableView<ViewType.ContentUnavailableView> {
        return try .init(try child(), parent: self)
    }
}

// MARK: - Extraction from MultipleViewContent parent

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension InspectableView where View: MultipleViewContent {

    func contentUnavailableView(_ index: Int) throws -> InspectableView<ViewType.ContentUnavailableView> {
        return try .init(try child(at: index), parent: self, index: index)
    }
}

// MARK: - Non Standard Children

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension ViewType.ContentUnavailableView: SupplementaryChildrenLabelView {

    static func supplementaryChildren(_ parent: UnwrappedView) throws -> LazyGroup<SupplementaryView> {
        return .init(count: 3) { index in
            let medium = parent.content.medium.resettingViewModifiers()
            switch index {
            case 0:
                let child = try Inspector.attribute(label: "label", value: parent.content.view)
                let content = try Inspector.unwrap(content: ViewInspectorContent(child, medium: medium))
                return try InspectableView<ViewType.ClassifiedView>(
                    content, parent: parent, call: "labelView()")
            case 1:
                let child = try Inspector.attribute(label: "description", value: parent.content.view)
                let content = try Inspector.unwrap(content: ViewInspectorContent(child, medium: medium))
                return try InspectableView<ViewType.ClassifiedView>(
                    content, parent: parent, call: "description()")
            default:
                let child = try Inspector.attribute(label: "actions", value: parent.content.view)
                let content = try Inspector.unwrap(content: ViewInspectorContent(child, medium: medium))
                return try InspectableView<ViewType.ClassifiedView>(
                    content, parent: parent, call: "actions()")
            }
        }
    }
}

// MARK: - Custom Attributes

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public extension InspectableView where View == ViewType.ContentUnavailableView {

    func labelView() throws -> InspectableView<ViewType.ClassifiedView> {
        return try View.supplementaryChildren(self).element(at: 0)
            .asInspectableView(ofType: ViewType.ClassifiedView.self)
    }

    func description() throws -> InspectableView<ViewType.ClassifiedView> {
        return try View.supplementaryChildren(self).element(at: 1)
            .asInspectableView(ofType: ViewType.ClassifiedView.self)
    }

    func actions() throws -> InspectableView<ViewType.ClassifiedView> {
        return try View.supplementaryChildren(self).element(at: 2)
            .asInspectableView(ofType: ViewType.ClassifiedView.self)
    }
}
