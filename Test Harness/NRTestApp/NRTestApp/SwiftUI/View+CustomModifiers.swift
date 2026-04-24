//
//  View+ViewDidLoad.swift
//  New Relic
//
//  Created by Justin Snider on 2/17/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

import SwiftUI
import Combine

struct TabIdKey: EnvironmentKey {
    static let defaultValue: String? = nil // Provide a default value; adjust the type as needed.
}

extension EnvironmentValues {
    var tabId: String? {
        get { self[TabIdKey.self] }
        set { self[TabIdKey.self] = newValue }
    }
}

extension View {
    func apply<Content: View>(@ViewBuilder transform: (Self) -> Content) -> Content {
        transform(self)
    }
    
    @ViewBuilder func modifyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    @ViewBuilder func modifyIfLet<T, U>(_ optional1: T?, _ optional2: U?, @ViewBuilder modifier: (Self, T, U) -> some View) -> some View {
            if let unwrapped1 = optional1, let unwrapped2 = optional2 {
                modifier(self, unwrapped1, unwrapped2)
            } else {
                self
            }
        }
    
    @ViewBuilder func overlayIf<Content: View>(_ condition: Bool, _ content: () -> Content) -> some View {
        if condition {
            self.overlay(content())
        } else {
            self
        }
    }
    
    func onFirstAppear(perform action: (() -> Void)? = nil) -> some View {
        self.modifier(OnFirstAppearModifier(action: action))
    }
  
}

struct OnFirstAppearModifier: ViewModifier {
    @State private var hasAppeared = false
    let action: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if hasAppeared == false {
                    hasAppeared = true
                    action?()
                }
            }
    }
}

