//
//  SwiftUIDisplayList.swift
//  Agent
//
//  Created by Chris Dillard on 9/25/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
internal struct SwiftUIDisplayList {
    let items: [DisplayListItem]

    internal struct Identity: Hashable {
        let value: UInt32
    }

    internal struct DisplayListSeed: Hashable {
        let value: UInt16
    }

    internal struct ViewRenderer {
        let renderer: SwiftUIViewUpdater
    }

    internal struct SwiftUIViewUpdater {
        let lastList: SwiftUIDisplayList.Lazy
        let viewCache: ViewCache
        
        internal struct ViewCache {
            let map: [ViewCache.CacheKey: ViewInfo]

            internal struct CacheKey: Hashable {
                let id: Index.ID
            }

        }

        internal struct ViewInfo {
            let frame: CGRect
            let backgroundColor: CGColor?
            let borderColor: CGColor?
            let borderWidth: CGFloat
            let cornerRadius: CGFloat
            let alpha: CGFloat
            let isHidden: Bool
            let intrinsicContentSize: CGSize
        }
    }
    
    internal struct Index {
        internal struct ID: Hashable {
            let identity: Identity
        }
    }
    
    internal enum Effect {
        case identify
        case clip(SwiftUI.Path, SwiftUI.FillStyle)
        case filter(SwiftUIGraphicsFilter)
        case platformGroup
        case unknown
    }

    internal struct Content {
        internal enum Value {
            case text(StyledTextSwiftUIView, CGSize)
            case image(SwiftUIGraphicsImage)
            case drawing(ErasedSwiftUIImageRepresentable)
            case shape(SwiftUI.Path, ResolvedColor, SwiftUI.FillStyle)
            case platformView
            case color(Color._ResFoundColor)
            case unknown
        }

        let seed: DisplayListSeed
        let value: Value
    }

    internal struct DisplayListItem {
        internal enum Value {
            case effect(Effect, SwiftUIDisplayList)
            case content(Content)
            case unknown
        }

        let identity: Identity
        let frame: CGRect
        let value: Value
    }
}
