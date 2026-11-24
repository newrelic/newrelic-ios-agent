//
//  NRMAUIViewDetails.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 1/16/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation
import UIKit
@_implementationOnly import NewRelicPrivate

struct ViewDetails {
    var viewId: Int
    var frame: CGRect
    var backgroundColor: UIColor?
    let alpha: CGFloat
    let isHidden: Bool
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let borderColor: UIColor?
    let viewName: String
    var parentId: Int?
    var nextId: Int?
    let clip: CGRect

    // Indicates if this view should have its content masked in session replay
    var isMasked: Bool?

    // swiftUI masking support
    var maskApplicationText: Bool?
    var maskUserInputText: Bool?
    var maskAllImages: Bool?
    var maskAllUserTouches: Bool?
    var blockView: Bool?

    // Custom identifier for the view (from NRMaskingView view)
    var viewIdentifier: String?

    // True when the view is a map (MKMapView, including the MKMapView that backs a
    // SwiftUI Map). Surfaced to the replay player as data-nr-component="map".
    var isMapView: Bool = false

    // Borders and corner radii a React Native view draws itself (NR-652282).
    var reactNativeBorder: ReactNativeBorderStyle?

    /// Width of each border edge the replay draws, top, right, bottom, left.
    var cssBorderWidths: [CGFloat] {
        var widths = Array(repeating: borderColor != nil ? borderWidth : 0, count: 4)
        if let edges = reactNativeBorder?.edges {
            for (index, edge) in edges.enumerated() where edge.width > 0 {
                widths[index] = edge.width
            }
        }
        if let borderImage = reactNativeBorder?.borderImage, borderImage.isResizable {
            widths = borderImage.widths
        }
        return widths
    }

    var cssSelector: String {
        return "\(self.viewName)-\(self.viewId)"
    }
    
    static private func sanitizeViewNameForCSS(_ viewName: String) -> String {
        // First, simplify common SwiftUI and framework prefixes
        var sanitized = viewName
            .replacingOccurrences(of: "SwiftUI.", with: "")
            .replacingOccurrences(of: "NewRelic.", with: "NR")
            .replacingOccurrences(of: "UIKit.", with: "UI")
        
        // Use regex to replace all invalid CSS identifier characters with underscores
        // Valid CSS identifiers can contain: letters, digits, hyphens, underscores
        // But cannot start with a digit or hyphen
        sanitized = sanitized.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]",
            with: "_",
            options: .regularExpression
        )
        
        // Remove consecutive underscores and hyphens
        sanitized = sanitized.replacingOccurrences(
            of: "[_-]+",
            with: "_",
            options: .regularExpression
        )
        
        // Trim leading/trailing underscores and hyphens
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
        
        // Ensure it doesn't start with a number or hyphen (invalid CSS identifier)
        if sanitized.isEmpty || sanitized.first?.isNumber == true || sanitized.hasPrefix("-") {
            sanitized = "view_\(sanitized)"
        }
        
        // Limit length to prevent extremely long IDs that could cause performance issues
        let maxLength = 50
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }
        
        // Fallback if somehow we end up with empty string
        return sanitized.isEmpty ? "view" : sanitized
    }

    var isVisible: Bool {
        !isHidden &&
        alpha > 0 &&
        frame != .zero &&
        !frame.intersection(clip).isEmpty
    }

    var isClear: Bool {
        backgroundColor == .clear || alpha == 0
    }

    init(view: UIView) {
        if let superview = view.superview, let window = view.window {
            let rawFrame = superview.convert(view.frame, to: window)
            let clippingRect = ViewDetails.getClippingRect(for: view, in: window)
            
            let visibleFrame = rawFrame.intersection(clippingRect)
            
            self.frame = visibleFrame.isNull ? .zero : visibleFrame
            self.clip = clippingRect
        }
        else {
            self.frame = view.frame
            self.clip = view.bounds
        }
        // Validate the backing CGColor before holding the UIColor — when a layer
        // is being torn down (e.g. rootViewController swap during sign-out), its
        // CGColor can be a dangling pointer. NR-566282.
        if let bg = view.backgroundColor, bg.cgColor.safeColor != nil {
            backgroundColor = bg
        } else {
            backgroundColor = nil
        }
        alpha = view.alpha
        isHidden = view.isHidden
        cornerRadius = view.layer.cornerRadius
        borderWidth = view.layer.borderWidth

        if view.layer.borderWidth > 0,
           let borderColor = view.layer.borderColor?.safeColor {
            self.borderColor = UIColor(cgColor: borderColor)
        }
        else {
            self.borderColor = nil
        }

        let sanitizedViewName = ViewDetails.sanitizeViewNameForCSS(String(describing: type(of: view)))
        viewName = sanitizedViewName

        self.isMapView = ViewDetails.checkIsMapView(view: view)
        self.reactNativeBorder = ReactNativeStyle.borderStyle(for: view)

        if let identifier = view.sessionReplayIdentifier {
            viewId = identifier
        }
        else {
            viewId = IDGenerator.shared.getId()
            view.sessionReplayIdentifier = viewId
        }
        
        self.parentId = view.superview?.sessionReplayIdentifier
        
        // Under the Default masking strategy, per-view UNMASK overrides (a `false`
        // value) set directly on a UIKit view are dropped so the global default
        // governs — the Default strategy always masks and cannot be unmasked, even
        // via these custom direct sets. Overrides that *increase* masking (`true`)
        // are still honored. This mirrors the guard in the SwiftUI init(frame:) path.
        let overrides = ViewDetails.directSetMaskingOverrides(view: view,
                                                              isDefaultMode: ViewDetails.currentMaskingModeIsDefault())

        if let maskApplicationText = overrides.maskApplicationText {
            self.maskApplicationText = maskApplicationText
            view.maskApplicationText = maskApplicationText
        }

        if let maskUserInputText = overrides.maskUserInputText {
            self.maskUserInputText = maskUserInputText
            view.maskUserInputText = maskUserInputText
        }

        if let maskAllImages = overrides.maskAllImages {
            self.maskAllImages = maskAllImages
            view.maskAllImages = maskAllImages
        }

        if let maskAllUserTouches = overrides.maskAllUserTouches {
            self.maskAllUserTouches = maskAllUserTouches
            view.maskAllUserTouches = maskAllUserTouches
        }

        if let blockView = ViewDetails.checkBlockView(view: view) {
            self.blockView = blockView
            view.blockView = blockView
        }

        if let shouldMask = ViewDetails.checkIsMasked(view: view, viewName: viewName) {
            self.isMasked = shouldMask
            view.sessionReplayMaskState = shouldMask
        }
    }
    
    init(frame: CGRect, clip: CGRect, backgroundColor: UIColor, alpha: CGFloat, isHidden: Bool, viewName: String, parentId: Int, cornerRadius: CGFloat, borderWidth: CGFloat, borderColor: UIColor? = nil, viewId: Int?, view: UIView? = nil,

          maskApplicationText: Bool?,
          maskUserInputText: Bool?,
          maskAllImages: Bool?,
          maskAllUserTouches: Bool?,
          blockView: Bool?,
          sessionReplayIdentifier: String?,
          inheritedMaskState: Bool? = nil,
          isDefaultMaskingMode: Bool = ViewDetails.currentMaskingModeIsDefault()) {
        
        let visibleFrame = frame.intersection(clip)
        
        self.frame = visibleFrame.isNull ? .zero : visibleFrame
        self.clip = clip
        
        self.backgroundColor = backgroundColor
        self.alpha = alpha
        self.isHidden = isHidden
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth

        self.borderColor = borderColor

        self.viewName = viewName

        if let identifier = viewId {
            self.viewId = identifier
        }
        else {
            self.viewId = IDGenerator.shared.getId()
        }

        self.parentId = parentId
        
        // Under the Default masking strategy the agent masks everything and per-view
        // UNMASK overrides are not honored — "even if you accidentally add unmasking
        // code, the default strategy will always mask everything." Overrides that
        // *increase* masking (a `true` value, or blockView) are still applied. This
        // mirrors the Default-mode guard in checkIsMasked() so the SwiftUI
        // NRConditionalMaskView path enforces the same contract as the UIKit path.
        self.maskApplicationText = ViewDetails.honoringDefaultStrategy(maskApplicationText, isDefaultMode: isDefaultMaskingMode)
        self.maskUserInputText = ViewDetails.honoringDefaultStrategy(maskUserInputText, isDefaultMode: isDefaultMaskingMode)
        self.maskAllImages = ViewDetails.honoringDefaultStrategy(maskAllImages, isDefaultMode: isDefaultMaskingMode)
        self.maskAllUserTouches = ViewDetails.honoringDefaultStrategy(maskAllUserTouches, isDefaultMode: isDefaultMaskingMode)
        self.blockView = blockView

        var inMaskedList = false
        var inUnmaskedList = false
        if let sessionReplayIdentifier = sessionReplayIdentifier,
           NewRelicAgentInternal.sharedInstance() != nil,
           let config = NRMAHarvestController.configuration() {
            let rules = ViewDetails.maskRules(for: config)
            inMaskedList = rules.identifiersMasked.contains(sessionReplayIdentifier)
            inUnmaskedList = rules.identifiersUnmasked.contains(sessionReplayIdentifier)
        }
        self.isMasked = ViewDetails.resolveIdentifierOverride(
            inMaskedList: inMaskedList,
            inUnmaskedList: inUnmaskedList,
            inheritedState: inheritedMaskState,
            isDefaultMode: isDefaultMaskingMode,
            maskApplicationText: self.maskApplicationText,
            maskUserInputText: self.maskUserInputText,
            maskAllImages: self.maskAllImages)
    }

    // The mask decision for a SwiftUI view, or nil when nothing explicit applies. A masked
    // identifier masks, and so does a masked UIKit ancestor (inheritedMaskState, the resolved state
    // of the hosting view). An unmask, from the identifier list or from an unmasked ancestor, is
    // ignored under the Default strategy and when a mask property is inherited from an ancestor
    // (maskApplicationText / maskUserInputText / maskAllImages are inherited, so true means a mask applies).
    static func resolveIdentifierOverride(inMaskedList: Bool,
                                          inUnmaskedList: Bool,
                                          inheritedState: Bool? = nil,
                                          isDefaultMode: Bool,
                                          maskApplicationText: Bool?,
                                          maskUserInputText: Bool?,
                                          maskAllImages: Bool? = nil) -> Bool? {
        if inMaskedList || inheritedState == true {
            return true
        }
        if (inUnmaskedList || inheritedState == false), !isDefaultMode,
           maskApplicationText != true, maskUserInputText != true, maskAllImages != true {
            return false
        }
        return nil
    }

    // True when the active session replay masking strategy is "Default". Under the
    // Default strategy the agent masks everything and per-view unmask overrides are
    // not honored. Returns false when no harvest configuration is available yet.
    static func currentMaskingModeIsDefault() -> Bool {
        guard let mode = NRMAHarvestController.configuration()?.session_replay_mode else {
            return false
        }
        return (mode as SessionReplayMaskingMode) == SessionReplayMaskingMode.default
    }

    // Applies the Default-strategy guard to a per-view masking override. Under the
    // Default strategy an UNMASK override (`false`) is dropped so the global default
    // governs; overrides that increase masking (`true`) are left untouched.
    static func honoringDefaultStrategy(_ override: Bool?, isDefaultMode: Bool) -> Bool? {
        if isDefaultMode && override == false {
            return nil
        }
        return override
    }

    // Resolves the per-view masking overrides set directly on a UIKit view (via the
    // maskApplicationText / maskUserInputText / maskAllImages / maskAllUserTouches
    // properties), including values inherited from an ancestor. Each override is run
    // through the Default-strategy guard so a direct UNMASK (`false`) can never
    // unmask content while the Default strategy is active. Extracted so the UIKit
    // init(view:) path is unit-testable with an explicit isDefaultMode.
    static func directSetMaskingOverrides(view: UIView, isDefaultMode: Bool)
        -> (maskApplicationText: Bool?, maskUserInputText: Bool?, maskAllImages: Bool?, maskAllUserTouches: Bool?) {
        return (
            honoringDefaultStrategy(checkMaskApplicationText(view: view), isDefaultMode: isDefaultMode),
            honoringDefaultStrategy(checkMaskUserInputText(view: view), isDefaultMode: isDefaultMode),
            honoringDefaultStrategy(checkMaskAllImages(view: view), isDefaultMode: isDefaultMode),
            honoringDefaultStrategy(checkMaskAllUserTouches(view: view), isDefaultMode: isDefaultMode)
        )
    }

    
    // MapKit is not linked by the agent, so resolve MKMapView dynamically once.
    // isKind(of:) also matches the private MKMapView subclass that backs a SwiftUI Map.
    private static let mapViewClass: AnyClass? = NSClassFromString("MKMapView")

    private static func checkIsMapView(view: UIView) -> Bool {
        guard let mapViewClass = mapViewClass else { return false }
        return view.isKind(of: mapViewClass)
    }

    // How an accessibility identifier tags a view for masking.
    enum MaskTag: Equatable {
        case none, mask, unmask
    }

    // What a view renders. Each direct mask property only affects its own kind of view:
    // maskApplicationText masks text, maskUserInputText masks text inputs and maskAllImages masks
    // images. Containers and other views are not masked by those properties; their children
    // read the inherited properties themselves.
    enum MaskKind: Equatable {
        case other, text, input, image
    }

    static func maskKind(for view: UIView) -> MaskKind {
        if view is UITextField || view is UITextView || view is UISearchBar {
            return .input
        }
        #if os(iOS)
        if view is UIDatePicker || view is UISwitch {
            return .input
        }
        #endif
        if view is UIImageView {
            return .image
        }
        if let label = view as? UILabel {
            // SwiftUI renders a TextField's placeholder and value through UITextFieldLabel.
            return UILabelThingy.isTextInputLabel(label) ? .input : .text
        }
        if view is UIButton {
            return .text
        }
        return .other
    }

    // Everything checkIsMasked needs to decide, gathered from the view and the agent
    // configuration so the decision itself is a pure, unit-testable function.
    struct MaskInputs: Equatable {
        var isDefaultMode = false
        var tag = MaskTag.none
        var identifierInMaskedList = false
        var identifierInUnmaskedList = false
        var classInMaskedList = false
        var classInUnmaskedList = false
        var kind = MaskKind.other
        // The parent's resolved mask state (sessionReplayMaskState).
        var parentState: Bool?
        // The view's direct mask properties, including values inherited from ancestors.
        var maskApplicationText: Bool?
        var maskUserInputText: Bool?
        var maskAllImages: Bool?
    }

    static func maskTag(for accessibilityIdentifier: String?) -> MaskTag {
        guard let id = accessibilityIdentifier, id.count > 0 else { return .none }
        if id == "nr-mask" || id.hasSuffix(".nr-mask") { return .mask }
        if id == "nr-unmask" || id.hasSuffix(".nr-unmask") { return .unmask }
        return .none
    }

    // Returns the explicit mask decision for a view, or nil when the global default for
    // its type should decide. Precedence: the view's own mask rules, then a masked parent
    // (state), then the mask property that applies to this kind of view, then the view's own
    // unmask rules, then the inherited parent state.
    static func resolveIsMasked(_ inputs: MaskInputs) -> Bool? {
        // If masking is in default mode we want to use the default value which is determined by the global for it's type.
        if inputs.isDefaultMode {
            return nil
        }

        // The view is explicitly marked to be masked.
        if inputs.tag == .mask || inputs.identifierInMaskedList || inputs.classInMaskedList {
            return true
        }

        // A masked parent takes priority over any unmask rule on its subtree. The mask
        // state is propagated down, so this covers every masked ancestor.
        if inputs.parentState == true {
            return true
        }

        // The same holds for a mask property inherited from an ancestor, but only the property
        // for this kind of view counts: maskApplicationText does not mask a text input and
        // maskUserInputText does not mask a label. Inherited values were already assigned to
        // the view before this runs.
        if kindProperty(inputs) == true {
            return true
        }

        // The view is explicitly marked to not be masked.
        if inputs.tag == .unmask || inputs.identifierInUnmaskedList || inputs.classInUnmaskedList {
            return false
        }

        // Check if parent is marked as unmasked (propagate unmasking status to children)
        if let parentMasked = inputs.parentState {
            return parentMasked
        }

        // Return nil if no custom masked setting is found
        return nil
    }

    // Class rules are matched against the sanitized view name (see sanitizeViewNameForCSS), so a
    // registered name is sanitized the same way. A module prefix ("MyApp.CardView") is also accepted:
    // String(describing:) never includes the module, so the prefix is dropped as a second candidate.
    // Matching is exact on the class itself; subclasses are not matched.
    static func sanitizedClassNames(_ registeredNames: [Any]?) -> Set<String> {
        var names = Set<String>()
        for case let registered as String in registeredNames ?? [] where !registered.isEmpty {
            names.insert(sanitizeViewNameForCSS(registered))
            let unprefixed = droppingModulePrefix(registered)
            if !unprefixed.isEmpty {
                names.insert(sanitizeViewNameForCSS(unprefixed))
            }
        }
        return names
    }

    static func classNameMatches(_ viewName: String, in registeredNames: [Any]?) -> Bool {
        return !viewName.isEmpty && sanitizedClassNames(registeredNames).contains(viewName)
    }

    // The mask rules are set up before Session Replay starts and don't change while it runs, so the
    // lookup sets are built once per configuration object instead of on every view capture.
    struct MaskRuleSets {
        var identifiersMasked = Set<String>()
        var identifiersUnmasked = Set<String>()
        var classesMasked = Set<String>()
        var classesUnmasked = Set<String>()
    }
    private static var ruleCacheConfig: NRMAHarvesterConfiguration?
    private static var ruleCache = MaskRuleSets()
    private static let ruleCacheLock = NSLock()

    static func maskRules(for config: NRMAHarvesterConfiguration) -> MaskRuleSets {
        ruleCacheLock.lock()
        defer { ruleCacheLock.unlock() }
        if ruleCacheConfig !== config {
            ruleCacheConfig = config
            ruleCache = MaskRuleSets(
                identifiersMasked: Set(locked(config.session_replay_maskedAccessibilityIdentifiers).compactMap { $0 as? String }),
                identifiersUnmasked: Set(locked(config.session_replay_unmaskedAccessibilityIdentifiers).compactMap { $0 as? String }),
                classesMasked: sanitizedClassNames(locked(config.session_replay_maskedClassNames)),
                classesUnmasked: sanitizedClassNames(locked(config.session_replay_unmaskedClassNames)))
        }
        return ruleCache
    }

    private static func locked(_ list: NSMutableArray?) -> [Any] {
        guard let list = list else { return [] }
        objc_sync_enter(list)
        defer { objc_sync_exit(list) }
        return Array(list)
    }

    // "MyApp.CardView" -> "CardView". Only the part before any generic argument list is searched,
    // so "Box<MyApp.Item>" keeps its arguments intact.
    private static func droppingModulePrefix(_ name: String) -> String {
        let head = name.firstIndex(of: "<").map { name[..<$0] } ?? Substring(name)
        guard let dot = head.lastIndex(of: ".") else { return name }
        return String(name[name.index(after: dot)...])
    }

    // The mask property that governs this kind of view.
    private static func kindProperty(_ inputs: MaskInputs) -> Bool? {
        switch inputs.kind {
        case .text: return inputs.maskApplicationText
        case .input: return inputs.maskUserInputText
        case .image: return inputs.maskAllImages
        case .other: return nil
        }
    }

    // This function checks if there are any specfic masking rules assigned to a view. If it returns nils, the masking value will be assigned based on the value of the global based on it's type later.
    private static func checkIsMasked(view: UIView, viewName: String) -> Bool? {
        // Determine if this view should be masked
        guard NewRelicAgentInternal.sharedInstance() != nil else { return true }
        guard let config = NRMAHarvestController.configuration() else { return true }

        let accessibilityId = view.accessibilityIdentifier
        let rules = maskRules(for: config)
        let inputs = MaskInputs(
            isDefaultMode: config.session_replay_mode as SessionReplayMaskingMode == SessionReplayMaskingMode.default,
            tag: maskTag(for: accessibilityId),
            identifierInMaskedList: accessibilityId.map { rules.identifiersMasked.contains($0) } ?? false,
            identifierInUnmaskedList: accessibilityId.map { rules.identifiersUnmasked.contains($0) } ?? false,
            classInMaskedList: rules.classesMasked.contains(viewName),
            classInUnmaskedList: rules.classesUnmasked.contains(viewName),
            kind: maskKind(for: view),
            parentState: view.superview?.sessionReplayMaskState,
            maskApplicationText: view.maskApplicationText,
            maskUserInputText: view.maskUserInputText,
            maskAllImages: view.maskAllImages)
        return resolveIsMasked(inputs)
    }

    // Whether an image-like element is masked: the resolved mask decision wins, then the
    // view's maskAllImages override, then the session_replay_maskAllImages config (default on).
    static func resolveImageIsMasked(_ viewDetails: ViewDetails) -> Bool {
        if let isMasked = viewDetails.isMasked {
            return isMasked
        }
        if let maskAllImages = viewDetails.maskAllImages {
            return maskAllImages
        }
        return NRMAHarvestController.configuration()?.session_replay_maskAllImages ?? true
    }

    // Whether a text input control (text field, text view, custom text) is masked. Secure
    // entry is always masked. Otherwise the resolved mask decision wins, then the view's
    // maskUserInputText override, then session_replay_maskUserInputText. A per-view
    // UNMASK override is only honored in Custom masking mode: under the Default
    // strategy the agent masks everything and unmask overrides are dropped.
    static func resolveTextInputIsMasked(_ viewDetails: ViewDetails, isSecureTextEntry: Bool) -> Bool {
        if isSecureTextEntry {
            return true
        }
        if let isMasked = viewDetails.isMasked {
            return isMasked
        }
        if let maskUserInputText = honoringDefaultStrategy(viewDetails.maskUserInputText,
                                                           isDefaultMode: currentMaskingModeIsDefault()) {
            return maskUserInputText
        }
        return NRMAHarvestController.configuration()?.session_replay_maskUserInputText ?? true
    }

    // A masked (`true`) parent takes priority over the view's own override, so a child
    // cannot unmask content inside a masked parent. Otherwise the view's own value
    // wins, falling back to the parent's.
    static func resolveMaskOverride(own: Bool?, parent: Bool?) -> Bool? {
        if parent == true {
            return true
        }
        return own ?? parent
    }

    private static func checkMaskApplicationText(view: UIView) -> Bool? {
        return resolveMaskOverride(own: view.maskApplicationText, parent: view.superview?.maskApplicationText)
    }
    
    private static func checkMaskUserInputText(view: UIView) -> Bool? {
        return resolveMaskOverride(own: view.maskUserInputText, parent: view.superview?.maskUserInputText)
    }
    
    private static func checkMaskAllImages(view: UIView) -> Bool? {
        return resolveMaskOverride(own: view.maskAllImages, parent: view.superview?.maskAllImages)
    }
    
    private static func checkMaskAllUserTouches(view: UIView) -> Bool? {
        return resolveMaskOverride(own: view.maskAllUserTouches, parent: view.superview?.maskAllUserTouches)
    }

    private static func checkBlockView(view: UIView) -> Bool? {
        // Check for explicit blockView flag first
        if let blockView = view.blockView {
            return blockView
        }

        // Check for "nr-block" accessibility identifier
        if let accessibilityId = view.accessibilityIdentifier,
           accessibilityId.count > 0,
           accessibilityId == "nr-block" || accessibilityId.hasSuffix(".nr-block") {
            return true
        }

        // Recursively check parent view hierarchy for blockView inheritance
        if let parentView = view.superview {
            // Check if parent has explicit blockView flag
            if let parentBlockView = parentView.blockView, parentBlockView {
                return true
            }

            // Check if parent has "nr-block" accessibility identifier
            if let parentAccessibilityId = parentView.accessibilityIdentifier,
               parentAccessibilityId.count > 0,
               parentAccessibilityId == "nr-block" || parentAccessibilityId.hasSuffix(".nr-block") {
                return true
            }

            // Recursively check parent's ancestors
            if let ancestorBlocked = checkBlockView(view: parentView), ancestorBlocked {
                return true
            }
        }

        return nil
    }
    
    private static func getClippingRect(for view: UIView, in window: UIWindow) -> CGRect {
        // Check if this view has skipAggressiveClipping flag
        if view.skipAggressiveClipping == true {
            return window.bounds
        }

        let clippingRect = contentClip(of: view.superview, in: window)
        return clippingRect.isNull ? .zero : clippingRect
    }

    /// Clip, in window coordinates, of everything inside `ancestor`: every clipping view from it
    /// up, not just the nearest. Content in a scroll view nested in another (e.g. a horizontal
    /// carousel inside a vertical page) is clipped by both, and stopping at the inner one draws
    /// it over whatever sits outside the outer.
    private static func contentClip(of ancestor: UIView?, in window: UIWindow) -> CGRect {
        guard let ancestor, ancestor !== window else {
            return window.bounds
        }
        let key = ObjectIdentifier(ancestor)
        if let cached = ancestorClipCache?[key] {
            return cached
        }
        var clip = contentClip(of: ancestor.superview, in: window)
        if ancestor is UIScrollView || ancestor.clipsToBounds {
            clip = clip.intersection(ancestor.convert(ancestor.bounds, to: window))
        }
        ancestorClipCache?[key] = clip
        return clip
    }

    // Every view under an ancestor shares its clip; during a capture it's worked out once per
    // ancestor rather than once per descendant. Nil outside a capture, where the hierarchy may
    // change between calls.
    private static var ancestorClipCache: [ObjectIdentifier: CGRect]?

    /// Runs one capture of the view hierarchy, which mustn't change while it runs.
    static func withAncestorClipCache<T>(_ capture: () -> T) -> T {
        ancestorClipCache = [:]
        defer { ancestorClipCache = nil }
        return capture()
    }
    
    // Helper method to find scrollview ancestor
    static func findScrollViewAncestor(for view: UIView) -> UIScrollView? {
        var current: UIView? = view.superview
        while current != nil {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            current = current?.superview
        }
        return nil
    }
}

extension ViewDetails: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(viewId)
        hasher.combine(frame.origin.x)
        hasher.combine(frame.origin.y)
        hasher.combine(frame.size.width)
        hasher.combine(frame.size.height)
        hasher.combine(alpha)
        hasher.combine(isHidden)
        hasher.combine(cornerRadius)
        hasher.combine(borderWidth)
        hasher.combine(viewName)
        hasher.combine(parentId)
        hasher.combine(nextId)
        hasher.combine(clip.origin.x)
        hasher.combine(clip.origin.y)
        hasher.combine(clip.size.width)
        hasher.combine(clip.size.height)
        hasher.combine(isMasked)
        hasher.combine(maskApplicationText)
        hasher.combine(maskUserInputText)
        hasher.combine(maskAllImages)
        hasher.combine(maskAllUserTouches)
        hasher.combine(blockView)
        hasher.combine(viewIdentifier)
        hasher.combine(isMapView)
        hasher.combine(reactNativeBorder)

        // Convert UIColors to hex strings before hashing to ensure thread safety
        if let bgColor = backgroundColor {
            hasher.combine(bgColor.toHexString(includingAlpha: true))
        }
        if let bColor = borderColor {
            hasher.combine(bColor.toHexString(includingAlpha: true))
        }
    }
}

fileprivate var associatedSessionReplayViewIDKey: String = "SessionReplayID"
fileprivate var associatedSessionReplayMaskStateKey: String = "SessionReplayMasked"
fileprivate var associatedSwiftUISessionReplayIdentifierKey: String = "SessionReplayIdentifier"

internal extension UIView {
    var sessionReplayIdentifier: Int? {
        set {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSessionReplayViewIDKey) {
                objc_getAssociatedObject(self, $0) as? Int
            }
        }
    }

    var sessionReplayMaskState: Bool? {
        set {
            withUnsafePointer(to: &associatedSessionReplayMaskStateKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSessionReplayMaskStateKey) {
                objc_getAssociatedObject(self, $0) as? Bool
            }
        }
    }
    
    var swiftUISessionReplayIdentifier: String? {
        set {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_setAssociatedObject(self, $0, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }

        get {
            withUnsafePointer(to: &associatedSwiftUISessionReplayIdentifierKey) {
                objc_getAssociatedObject(self, $0) as? String
            }
        }
    }
}
