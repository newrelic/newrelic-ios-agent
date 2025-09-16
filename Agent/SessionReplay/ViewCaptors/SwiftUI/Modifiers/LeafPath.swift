//
//  ViewStuff.swift
//  Agent
//
//  Created by Chris Dillard on 9/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

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

struct LeafPathPreferenceKey: PreferenceKey {
    typealias Value = [LeafPath]
    static var defaultValue: [LeafPath] = []
    static func reduce(value: inout [LeafPath], nextValue: () -> [LeafPath]) {
        value.append(contentsOf: nextValue())
    }
}
