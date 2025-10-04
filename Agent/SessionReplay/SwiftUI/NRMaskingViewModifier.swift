//
//  NRMaskingViewModifier.swift
//  Agent
//
//  Copyright © 2025 New Relic. All rights reserved.
//

import SwiftUI

// MARK: - Masking Configuration

/// Represents the masking state for a SwiftUI view
@available(iOS 13.0, tvOS 13.0, *)
public enum NRMaskingState: Equatable {
    /// View content should be masked (hidden/redacted in session replay)
    case masked
    /// View content should not be masked (visible in session replay)
    case unmasked
    /// Custom identifier for the view (can be used for selective masking rules)
    case custom(String)

    public static func == (lhs: NRMaskingState, rhs: NRMaskingState) -> Bool {
        switch (lhs, rhs) {
        case (.masked, .masked), (.unmasked, .unmasked):
            return true
        case (.custom(let lhsId), .custom(let rhsId)):
            return lhsId == rhsId
        default:
            return false
        }
    }

    /// Returns the custom identifier if present, nil otherwise
    var customIdentifier: String? {
        if case .custom(let identifier) = self {
            return identifier
        }
        return nil
    }

    /// Returns whether this state represents masked content
    var isMasked: Bool {
        switch self {
        case .masked:
            return true
        case .unmasked:
            return false
        case .custom:
            // Custom identifiers don't imply masking by default
            return false
        }
    }
}

// MARK: - Environment Key

@available(iOS 13.0, tvOS 13.0, *)
private struct NRMaskingStateKey: EnvironmentKey {
    static let defaultValue: NRMaskingState? = nil
}

@available(iOS 13.0, tvOS 13.0, *)
extension EnvironmentValues {
    var nrMaskingState: NRMaskingState? {
        get { self[NRMaskingStateKey.self] }
        set { self[NRMaskingStateKey.self] = newValue }
    }
}

// MARK: - View Modifier

@available(iOS 13.0, tvOS 13.0, *)
private struct NRMaskingViewModifier: ViewModifier {
    let maskingState: NRMaskingState

    func body(content: Content) -> some View {
        content
            .environment(\.nrMaskingState, maskingState)
    }
}

// MARK: - Public API

@available(iOS 13.0, tvOS 13.0, *)
extension View {
    /// Marks this view as masked (content will be hidden in session replay)
    /// - Returns: A view with masking applied
    public func nrMasked() -> some View {
        modifier(NRMaskingViewModifier(maskingState: .masked))
    }

    /// Marks this view as unmasked (content will be visible in session replay)
    /// - Returns: A view with masking disabled
    public func nrUnmasked() -> some View {
        modifier(NRMaskingViewModifier(maskingState: .unmasked))
    }

    /// Marks this view with a custom identifier
    /// - Parameter identifier: The custom identifier string
    /// - Returns: A view with the custom identifier
    public func nrMaskingIdentifier(_ identifier: String) -> some View {
        modifier(NRMaskingViewModifier(maskingState: .custom(identifier)))
    }

    /// Marks this view with a masking state
    /// - Parameter state: The masking state (masked, unmasked, or custom)
    /// - Returns: A view with the masking state applied
    public func nrMasking(_ state: NRMaskingState) -> some View {
        modifier(NRMaskingViewModifier(maskingState: state))
    }

    /// Conditionally marks this view as masked or unmasked
    /// - Parameter masked: If true, masks the view; if false, unmasks it
    /// - Returns: A view with the conditional masking applied
    public func nrMasking(_ masked: Bool) -> some View {
        modifier(NRMaskingViewModifier(maskingState: masked ? .masked : .unmasked))
    }
}

// MARK: - Internal Extraction Helpers

@available(iOS 13.0, tvOS 13.0, *)
extension NRMaskingState {
    /// Creates a masking state from a boolean value (for backward compatibility)
    static func from(bool: Bool) -> NRMaskingState {
        return bool ? .masked : .unmasked
    }

    /// Creates a masking state from an optional string identifier
    static func from(identifier: String?) -> NRMaskingState? {
        guard let identifier = identifier else { return nil }
        return .custom(identifier)
    }
}
