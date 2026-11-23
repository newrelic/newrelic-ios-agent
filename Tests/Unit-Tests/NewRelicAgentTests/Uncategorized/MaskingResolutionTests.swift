import Foundation
import Testing
import UIKit

// Exhaustive tests for the masking decision (ViewDetails.resolveIsMasked) and for how it
// composes down a view hierarchy. The decision is a pure function of MaskInputs, so no
// agent singleton or harvest configuration is needed; "config" here means the Default /
// Custom strategy and the masked / unmasked identifier and class lists.
@MainActor
@Suite(.serialized)
struct MaskingResolutionTests {

    // MARK: - Single-view decision (every combination of inputs)

    // Oracle written as three tiers, independent of the implementation's control flow:
    // Default always defers to the global; otherwise any mask source wins over any unmask
    // source, and an inherited unmask only applies when nothing masks the view.
    private func expected(_ i: ViewDetails.MaskInputs) -> Bool? {
        if i.isDefaultMode { return nil }
        let masks = [i.tag == .mask, i.identifierInMaskedList, i.classInMaskedList,
                     i.parentState == true, i.maskApplicationText == true, i.maskUserInputText == true]
        if masks.contains(true) { return true }
        let ownUnmasks = [i.tag == .unmask, i.identifierInUnmaskedList, i.classInUnmaskedList]
        if ownUnmasks.contains(true) { return false }
        if i.parentState == false { return i.maskAllImages == true ? nil : false }
        return nil
    }

    private let tri: [Bool?] = [nil, true, false]

    @Test func `Every input combination resolves per the precedence rules`() {
        var failures: [String] = []
        var count = 0
        for isDefault in [false, true] {
            for tag in [ViewDetails.MaskTag.none, .mask, .unmask] {
                for flags in 0..<16 {
                    for parent in tri {
                        for text in tri {
                            for input in tri {
                                for images in tri {
                                    let inputs = ViewDetails.MaskInputs(
                                        isDefaultMode: isDefault, tag: tag,
                                        identifierInMaskedList: flags & 1 != 0,
                                        identifierInUnmaskedList: flags & 2 != 0,
                                        classInMaskedList: flags & 4 != 0,
                                        classInUnmaskedList: flags & 8 != 0,
                                        parentState: parent, maskApplicationText: text,
                                        maskUserInputText: input, maskAllImages: images)
                                    count += 1
                                    if ViewDetails.resolveIsMasked(inputs) != expected(inputs) {
                                        failures.append("\(inputs)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        #expect(count == 2 * 3 * 16 * 81)
        #expect(failures.isEmpty, "\(failures.count) mismatches, first: \(failures.first ?? "")")
    }

    // Property checks that state the intent directly, over the same input space.
    @Test func `Mask beats unmask and Default never decides`() {
        for flags in 0..<64 {
            var masked = ViewDetails.MaskInputs()
            masked.tag = flags & 1 != 0 ? .mask : .unmask          // unmask tag is always present when not mask
            masked.identifierInUnmaskedList = true
            masked.classInUnmaskedList = true
            masked.parentState = flags & 2 != 0 ? false : nil
            masked.identifierInMaskedList = flags & 4 != 0
            masked.classInMaskedList = flags & 8 != 0
            masked.maskApplicationText = flags & 16 != 0 ? true : nil
            masked.maskUserInputText = flags & 32 != 0 ? true : nil
            let hasMask = masked.tag == .mask || masked.identifierInMaskedList || masked.classInMaskedList
                || masked.maskApplicationText == true || masked.maskUserInputText == true
            #expect(ViewDetails.resolveIsMasked(masked) == (hasMask ? true : false))

            var inDefault = masked
            inDefault.isDefaultMode = true
            #expect(ViewDetails.resolveIsMasked(inDefault) == nil)
        }
    }

    @Test func `Masked parent state wins over every own unmask rule`() {
        var i = ViewDetails.MaskInputs()
        i.parentState = true
        i.tag = .unmask
        i.identifierInUnmaskedList = true
        i.classInUnmaskedList = true
        #expect(ViewDetails.resolveIsMasked(i) == true)
    }

    @Test func `Unmasked parent state yields to the view's own mask`() {
        var i = ViewDetails.MaskInputs()
        i.parentState = false
        #expect(ViewDetails.resolveIsMasked(i) == false)
        i.tag = .mask
        #expect(ViewDetails.resolveIsMasked(i) == true)
        i.tag = .none
        i.maskApplicationText = true
        #expect(ViewDetails.resolveIsMasked(i) == true)
        i.maskApplicationText = nil
        i.maskAllImages = true
        #expect(ViewDetails.resolveIsMasked(i) == nil)
    }

    @Test func `Mask tag parsing accepts exact and suffixed identifiers only`() {
        #expect(ViewDetails.maskTag(for: nil) == .none)
        #expect(ViewDetails.maskTag(for: "") == .none)
        #expect(ViewDetails.maskTag(for: "nr-mask") == .mask)
        #expect(ViewDetails.maskTag(for: "screen.nr-mask") == .mask)
        #expect(ViewDetails.maskTag(for: "nr-unmask") == .unmask)
        #expect(ViewDetails.maskTag(for: "screen.nr-unmask") == .unmask)
        #expect(ViewDetails.maskTag(for: "my-nr-mask") == .none)
        #expect(ViewDetails.maskTag(for: "nr-masked") == .none)
    }

    // MARK: - Class-name rule matching

    @Test func `Class rules match plain, module-prefixed and sanitized names`() {
        #expect(ViewDetails.classNameMatches("UILabel", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("UILabel", in: ["UITextField"]))
        #expect(!ViewDetails.classNameMatches("", in: [""]))
        #expect(!ViewDetails.classNameMatches("UILabel", in: nil))
        // Module prefix is accepted because String(describing:) never includes it.
        #expect(ViewDetails.classNameMatches("CardView", in: ["MyApp.CardView"]))
        // Generics are sanitized exactly like the view name: Box<Item> -> Box_Item.
        #expect(ViewDetails.classNameMatches("Box_Item", in: ["Box<Item>"]))
        #expect(ViewDetails.classNameMatches("Box_Item", in: ["MyApp.Box<Item>"]))
        // The module inside a generic argument list is not treated as the class's own prefix.
        #expect(ViewDetails.classNameMatches("Box_MyApp_Item", in: ["Box<MyApp.Item>"]))
        // Nested types keep their outer type.
        #expect(ViewDetails.classNameMatches("Outer_Inner", in: ["Outer.Inner"]))
        // Prefix rewrites match the sanitizer: NewRelic. -> NR, SwiftUI. removed.
        #expect(ViewDetails.classNameMatches("NRFoo", in: ["NewRelic.Foo"]))
        #expect(ViewDetails.classNameMatches("Text", in: ["SwiftUI.Text"]))
    }

    @Test func `Class rules do not match subclasses or partial names`() {
        #expect(!ViewDetails.classNameMatches("MyLabel", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("UILabelSubclass", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("Label", in: ["UILabel"]))
    }

    @Test func `Class rules longer than the view name cap still match`() {
        let long = "ThisIsAnExtremelyLongViewClassNameThatGoesWellBeyondFiftyCharacters"
        let viewName = String(long.prefix(50))
        #expect(ViewDetails.classNameMatches(viewName, in: [long]))
    }

    // MARK: - Mask rule sets (cached lookup built from the harvest configuration)

    private func withConfiguration(_ body: (NRMAHarvesterConfiguration) -> Void) {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        body(config)
    }

    @Test func `Rule sets are built from the configuration lists`() {
        withConfiguration { config in
            config.session_replay_maskedAccessibilityIdentifiers = ["secret", "private"]
            config.session_replay_unmaskedAccessibilityIdentifiers = ["public"]
            config.session_replay_maskedClassNames = ["SecureLabel", "MyApp.Card<Item>"]
            config.session_replay_unmaskedClassNames = ["UnsecureLabel"]

            let rules = ViewDetails.maskRules(for: config)
            #expect(rules.identifiersMasked == ["secret", "private"])
            #expect(rules.identifiersUnmasked == ["public"])
            // Class names are stored sanitized, with and without the module prefix.
            #expect(rules.classesMasked == ["SecureLabel", "MyApp_Card_Item", "Card_Item"])
            #expect(rules.classesUnmasked == ["UnsecureLabel"])
        }
    }

    @Test func `Rule sets are empty for empty or missing lists`() {
        withConfiguration { config in
            config.session_replay_maskedAccessibilityIdentifiers = NSMutableArray()
            config.session_replay_unmaskedAccessibilityIdentifiers = nil
            config.session_replay_maskedClassNames = nil
            config.session_replay_unmaskedClassNames = NSMutableArray()

            let rules = ViewDetails.maskRules(for: config)
            #expect(rules.identifiersMasked.isEmpty)
            #expect(rules.identifiersUnmasked.isEmpty)
            #expect(rules.classesMasked.isEmpty)
            #expect(rules.classesUnmasked.isEmpty)
        }
    }

    @Test func `Rule sets ignore non-string entries and empty class names`() {
        withConfiguration { config in
            config.session_replay_maskedAccessibilityIdentifiers = ["id", 5, NSNull()]
            config.session_replay_maskedClassNames = ["", 7, "UILabel"]

            let rules = ViewDetails.maskRules(for: config)
            #expect(rules.identifiersMasked == ["id"])
            #expect(rules.classesMasked == ["UILabel"])
            #expect(!rules.classesMasked.contains(""))
        }
    }

    @Test func `Rule sets are built once per configuration`() {
        withConfiguration { config in
            config.session_replay_maskedAccessibilityIdentifiers = ["first"]
            config.session_replay_maskedClassNames = ["First"]
            #expect(ViewDetails.maskRules(for: config).identifiersMasked == ["first"])

            // The lists are fixed while replay runs: a later change to the same configuration
            // object is not picked up, which is what makes the per-view lookup cheap.
            config.session_replay_maskedAccessibilityIdentifiers?.add("second")
            config.session_replay_maskedClassNames?.add("Second")
            let cached = ViewDetails.maskRules(for: config)
            #expect(cached.identifiersMasked == ["first"])
            #expect(cached.classesMasked == ["First"])
        }
    }

    @Test func `Rule sets are rebuilt when the configuration object changes`() {
        withConfiguration { first in
            first.session_replay_maskedAccessibilityIdentifiers = ["one"]
            #expect(ViewDetails.maskRules(for: first).identifiersMasked == ["one"])

            withConfiguration { second in
                second.session_replay_maskedAccessibilityIdentifiers = ["two"]
                #expect(ViewDetails.maskRules(for: second).identifiersMasked == ["two"])
            }
            // Going back to the first configuration rebuilds from its own lists.
            #expect(ViewDetails.maskRules(for: first).identifiersMasked == ["one"])
        }
    }

    @Test func `Rule sets drive the mask decision for a view`() {
        withConfiguration { config in
            config.session_replay_mode = SessionReplayMaskingMode.custom
            config.session_replay_maskedAccessibilityIdentifiers = ["secret"]
            config.session_replay_unmaskedAccessibilityIdentifiers = ["public"]
            config.session_replay_maskedClassNames = ["UILabel"]

            let rules = ViewDetails.maskRules(for: config)
            let masked = ViewDetails.MaskInputs(
                isDefaultMode: false, tag: .none,
                identifierInMaskedList: rules.identifiersMasked.contains("secret"),
                identifierInUnmaskedList: rules.identifiersUnmasked.contains("secret"),
                classInMaskedList: rules.classesMasked.contains("UILabel"),
                classInUnmaskedList: false,
                parentState: nil, maskApplicationText: nil, maskUserInputText: nil, maskAllImages: nil)
            #expect(ViewDetails.resolveIsMasked(masked) == true)

            let unmasked = ViewDetails.MaskInputs(
                isDefaultMode: false, tag: .none,
                identifierInMaskedList: rules.identifiersMasked.contains("public"),
                identifierInUnmaskedList: rules.identifiersUnmasked.contains("public"),
                classInMaskedList: rules.classesMasked.contains("UITextField"),
                classInUnmaskedList: false,
                parentState: nil, maskApplicationText: nil, maskUserInputText: nil, maskAllImages: nil)
            #expect(ViewDetails.resolveIsMasked(unmasked) == false)
        }
    }

    // MARK: - Hierarchy composition (parent > child > grandchild)

    private enum Mechanism: CaseIterable {
        case none, tag, identifierList, classList, property
    }

    private struct Level: CustomStringConvertible {
        var mechanism: Mechanism
        var masked: Bool
        var description: String { mechanism == .none ? "none" : "\(mechanism)-\(masked ? "M" : "U")" }
    }

    private var allLevels: [Level] {
        var levels = [Level(mechanism: .none, masked: false)]
        for mechanism in Mechanism.allCases where mechanism != .none {
            levels.append(Level(mechanism: mechanism, masked: true))
            levels.append(Level(mechanism: mechanism, masked: false))
        }
        return levels
    }

    // What the leaf's captor receives from the capture pipeline.
    private struct LeafResolution {
        var decision: Bool?
        var maskApplicationText: Bool?
        var maskUserInputText: Bool?
        var maskAllImages: Bool?
    }

    // Mirrors ViewDetails.init(view:) for a chain of nested views: direct properties are
    // resolved and assigned first, then the mask decision runs, and its result is stored
    // as the view's mask state for descendants.
    private func leafResolution(chain: [Level], isDefaultMode: Bool) -> LeafResolution {
        var parent: UIView?
        var result = LeafResolution()
        for level in chain {
            let view = UIView()
            var inputs = ViewDetails.MaskInputs(isDefaultMode: isDefaultMode)
            switch level.mechanism {
            case .none: break
            case .tag: view.accessibilityIdentifier = level.masked ? "nr-mask" : "nr-unmask"
            case .identifierList:
                inputs.identifierInMaskedList = level.masked
                inputs.identifierInUnmaskedList = !level.masked
            case .classList:
                inputs.classInMaskedList = level.masked
                inputs.classInUnmaskedList = !level.masked
            case .property:
                view.maskApplicationText = level.masked
                view.maskUserInputText = level.masked
            }
            parent?.addSubview(view)

            let overrides = ViewDetails.directSetMaskingOverrides(view: view, isDefaultMode: isDefaultMode)
            if let text = overrides.maskApplicationText { view.maskApplicationText = text }
            if let input = overrides.maskUserInputText { view.maskUserInputText = input }
            if let images = overrides.maskAllImages { view.maskAllImages = images }

            inputs.tag = ViewDetails.maskTag(for: view.accessibilityIdentifier)
            inputs.parentState = parent?.sessionReplayMaskState
            inputs.maskApplicationText = view.maskApplicationText
            inputs.maskUserInputText = view.maskUserInputText
            inputs.maskAllImages = view.maskAllImages

            let decision = ViewDetails.resolveIsMasked(inputs)
            if let decision = decision { view.sessionReplayMaskState = decision }
            result = LeafResolution(decision: decision,
                                    maskApplicationText: overrides.maskApplicationText,
                                    maskUserInputText: overrides.maskUserInputText,
                                    maskAllImages: overrides.maskAllImages)
            parent = view
        }
        return result
    }

    // What the leaf's captor sees for application text: the decision, else the text override.
    private func leafOutcome(chain: [Level], isDefaultMode: Bool) -> Bool? {
        let resolution = leafResolution(chain: chain, isDefaultMode: isDefaultMode)
        return resolution.decision ?? resolution.maskApplicationText
    }

    // Under Custom: any masking level masks the leaf, otherwise any unmasking level
    // unmasks it, otherwise the global default applies. Under Default only a direct
    // property mask is honored (it only adds masking); everything else defers to the
    // global default, which masks.
    private func expectedLeaf(chain: [Level], isDefaultMode: Bool) -> Bool? {
        if isDefaultMode {
            return chain.contains { $0.mechanism == .property && $0.masked } ? true : nil
        }
        let active = chain.filter { $0.mechanism != .none }
        if active.contains(where: { $0.masked }) { return true }
        return active.isEmpty ? nil : false
    }

    @Test func `Every parent child grandchild chain composes correctly`() {
        var failures: [String] = []
        var count = 0
        for isDefault in [false, true] {
            for depth in 1...3 {
                var chains: [[Level]] = [[]]
                for _ in 0..<depth {
                    chains = chains.flatMap { chain in allLevels.map { chain + [$0] } }
                }
                for chain in chains {
                    count += 1
                    let actual = leafOutcome(chain: chain, isDefaultMode: isDefault)
                    let wanted = expectedLeaf(chain: chain, isDefaultMode: isDefault)
                    if actual != wanted {
                        failures.append("default=\(isDefault) \(chain) actual=\(String(describing: actual)) expected=\(String(describing: wanted))")
                    }
                }
            }
        }
        #expect(count == 2 * (9 + 81 + 729))
        #expect(failures.isEmpty, "\(failures.count) mismatches, first: \(failures.first ?? "")")
    }

    // The scenarios reported while building the test-harness screens.
    @Test func `Reported scenarios resolve as documented`() {
        let propertyM = Level(mechanism: .property, masked: true)
        let tagU = Level(mechanism: .tag, masked: false)
        let tagM = Level(mechanism: .tag, masked: true)
        let listU = Level(mechanism: .identifierList, masked: false)
        let propertyU = Level(mechanism: .property, masked: false)
        #expect(leafOutcome(chain: [tagM, tagU], isDefaultMode: false) == true)
        #expect(leafOutcome(chain: [tagU, propertyM], isDefaultMode: false) == true)
        #expect(leafOutcome(chain: [propertyM, listU], isDefaultMode: false) == true)
        #expect(leafOutcome(chain: [propertyM, tagU], isDefaultMode: false) == true)
        #expect(leafOutcome(chain: [propertyM, propertyU], isDefaultMode: false) == true)
        #expect(leafOutcome(chain: [tagU, Level(mechanism: .none, masked: false)], isDefaultMode: false) == false)
    }

    // MARK: - Leaf captors with config defaults
    // Labels and text fields run through the real captors. The image captors depend on SwiftUI
    // display-list sources the unit-test target doesn't compile, so images go through the shared
    // ViewDetails.resolveImageIsMasked that all of them call.

    private struct ConfigDefaults {
        var maskApplicationText: Bool
        var maskUserInputText: Bool
        var maskAllImages: Bool
    }

    private func makeDetails(_ resolution: LeafResolution, isDefaultMode: Bool) -> ViewDetails {
        var details = ViewDetails(
            frame: .zero, clip: .zero, backgroundColor: .clear, alpha: 1, isHidden: false,
            viewName: "UIView", parentId: 0, cornerRadius: 0, borderWidth: 0, borderColor: nil,
            viewId: 1, view: nil,
            maskApplicationText: resolution.maskApplicationText,
            maskUserInputText: resolution.maskUserInputText,
            maskAllImages: resolution.maskAllImages,
            maskAllUserTouches: nil, blockView: nil, sessionReplayIdentifier: nil,
            isDefaultMaskingMode: isDefaultMode)
        details.isMasked = resolution.decision
        return details
    }

    // Expected masking of each captor type for a chain, written from the documented rules:
    // Custom: any mask wins, else any unmask wins, else the type's config default. A direct
    // property unmask changes the captor types that read that property.
    // Default: only a direct property mask is honored; everything else uses the config default.
    private func expectedCaptors(chain: [Level], isDefaultMode: Bool, defaults: ConfigDefaults)
        -> (label: Bool, field: Bool, image: Bool) {
        let active = chain.filter { $0.mechanism != .none }
        let anyPropertyMask = active.contains { $0.mechanism == .property && $0.masked }
        if isDefaultMode {
            return (anyPropertyMask ? true : defaults.maskApplicationText,
                    anyPropertyMask ? true : defaults.maskUserInputText,
                    defaults.maskAllImages)
        }
        if active.contains(where: { $0.masked }) { return (true, true, true) }
        if active.contains(where: { $0.mechanism != .property }) { return (false, false, false) }
        if active.contains(where: { $0.mechanism == .property }) {
            return (false, false, defaults.maskAllImages)
        }
        return (defaults.maskApplicationText, defaults.maskUserInputText, defaults.maskAllImages)
    }

    @Test func `Leaf captors honor hierarchy and config defaults for every chain`() {
        let configuration = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }

        var failures: [String] = []
        var count = 0
        for isDefault in [false, true] {
            configuration.session_replay_mode = isDefault ? SessionReplayMaskingMode.default : SessionReplayMaskingMode.custom
            for flags in 0..<8 {
                let defaults = ConfigDefaults(maskApplicationText: flags & 1 != 0,
                                              maskUserInputText: flags & 2 != 0,
                                              maskAllImages: flags & 4 != 0)
                configuration.session_replay_maskApplicationText = defaults.maskApplicationText
                configuration.session_replay_maskUserInputText = defaults.maskUserInputText
                configuration.session_replay_maskAllImages = defaults.maskAllImages

                for depth in 1...3 {
                    var chains: [[Level]] = [[]]
                    for _ in 0..<depth {
                        chains = chains.flatMap { chain in allLevels.map { chain + [$0] } }
                    }
                    for chain in chains {
                        count += 1
                        let resolution = leafResolution(chain: chain, isDefaultMode: isDefault)
                        let details = makeDetails(resolution, isDefaultMode: isDefault)
                        let actual = (UILabelThingy(view: UILabel(), viewDetails: details).isMasked,
                                      UITextFieldThingy(view: UITextField(), viewDetails: details).isMasked,
                                      ViewDetails.resolveImageIsMasked(details))
                        let wanted = expectedCaptors(chain: chain, isDefaultMode: isDefault, defaults: defaults)
                        // The text view and custom text captors call the same shared function.
                        if ViewDetails.resolveTextInputIsMasked(details, isSecureTextEntry: false) != actual.1 {
                            failures.append("shared text-input rule disagrees with text field: \(chain)")
                        }
                        // The date picker is user input and follows the text-field rule too.
                        if UIDatePickerThingy(view: UIDatePicker(), viewDetails: details).isMasked != actual.1 {
                            failures.append("date picker disagrees with text field: \(chain)")
                        }
                        if actual != wanted {
                            failures.append("default=\(isDefault) cfg=\(defaults) \(chain) actual=\(actual) expected=\(wanted)")
                        }
                    }
                }
            }
        }
        #expect(count == 2 * 8 * (9 + 81 + 729))
        #expect(failures.isEmpty, "\(failures.count) mismatches, first: \(failures.first ?? "")")
    }

    // An unmask override that reaches a captor unguarded (ViewDetails built as if Custom while
    // the configured strategy is Default) must still be dropped by every text-input captor.
    @Test func `Text input captors drop an unguarded unmask under Default`() {
        let configuration = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        configuration.session_replay_mode = SessionReplayMaskingMode.default
        configuration.session_replay_maskUserInputText = true

        let unguarded = makeDetails(LeafResolution(maskUserInputText: false), isDefaultMode: false)
        #expect(UITextFieldThingy(view: UITextField(), viewDetails: unguarded).isMasked)
        #expect(UIDatePickerThingy(view: UIDatePicker(), viewDetails: unguarded).isMasked)
        #expect(ViewDetails.resolveTextInputIsMasked(unguarded, isSecureTextEntry: false))
    }

    @Test func `Secure text field is masked regardless of hierarchy or config`() {
        let configuration = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        configuration.session_replay_mode = SessionReplayMaskingMode.custom
        configuration.session_replay_maskUserInputText = false

        let field = UITextField()
        field.isSecureTextEntry = true
        let unmasked = [Level(mechanism: .tag, masked: false), Level(mechanism: .property, masked: false)]
        let details = makeDetails(leafResolution(chain: unmasked, isDefaultMode: false), isDefaultMode: false)
        #expect(UITextFieldThingy(view: field, viewDetails: details).isMasked)
        #expect(ViewDetails.resolveTextInputIsMasked(details, isSecureTextEntry: true))
    }
}
