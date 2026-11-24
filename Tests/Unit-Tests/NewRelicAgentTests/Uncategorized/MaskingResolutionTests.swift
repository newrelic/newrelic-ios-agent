import Foundation
import Testing
import UIKit

// A plain top-level class, so its qualified runtime name is predictable (Module.RuleTestLabel).
class RuleTestLabel: UILabel {}

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
    // source, and an inherited unmask only applies when nothing masks the view. Only the mask
    // property that governs the view's kind counts.
    private func relevantProperty(_ i: ViewDetails.MaskInputs) -> Bool? {
        switch i.kind {
        case .text: return i.maskApplicationText
        case .input: return i.maskUserInputText
        case .image: return i.maskAllImages
        case .other: return nil
        }
    }

    private func expected(_ i: ViewDetails.MaskInputs) -> Bool? {
        if i.isDefaultMode { return nil }
        let masks = [i.tag == .mask, i.identifierInMaskedList, i.classInMaskedList,
                     i.parentState == true, relevantProperty(i) == true]
        if masks.contains(true) { return true }
        let ownUnmasks = [i.tag == .unmask, i.identifierInUnmaskedList, i.classInUnmaskedList]
        if ownUnmasks.contains(true) { return false }
        if i.parentState == false { return false }
        return nil
    }

    private let tri: [Bool?] = [nil, true, false]
    private let kinds: [ViewDetails.MaskKind] = [.other, .text, .input, .image]

    @Test func `Every input combination resolves per the precedence rules`() {
        var failures: [String] = []
        var count = 0
        for isDefault in [false, true] {
            for tag in [ViewDetails.MaskTag.none, .mask, .unmask] {
                for kind in kinds {
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
                                            kind: kind,
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
        }
        #expect(count == 2 * 3 * 4 * 16 * 81)
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
            masked.kind = .text
            masked.maskApplicationText = flags & 16 != 0 ? true : nil
            // maskUserInputText never masks a text view.
            masked.maskUserInputText = flags & 32 != 0 ? true : nil
            let hasMask = masked.tag == .mask || masked.identifierInMaskedList || masked.classInMaskedList
                || masked.maskApplicationText == true
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
        i.kind = .text
        i.maskApplicationText = true
        #expect(ViewDetails.resolveIsMasked(i) == true)
        i.maskApplicationText = nil
        i.kind = .image
        i.maskAllImages = true
        #expect(ViewDetails.resolveIsMasked(i) == true)
    }

    // Each mask property only affects its own kind of view.
    @Test func `Mask properties only affect their own kind of view`() {
        func resolve(_ kind: ViewDetails.MaskKind, app: Bool? = nil, input: Bool? = nil, images: Bool? = nil) -> Bool? {
            var i = ViewDetails.MaskInputs()
            i.kind = kind
            i.maskApplicationText = app
            i.maskUserInputText = input
            i.maskAllImages = images
            return ViewDetails.resolveIsMasked(i)
        }
        #expect(resolve(.text, app: true) == true)
        #expect(resolve(.text, input: true, images: true) == nil)
        #expect(resolve(.input, input: true) == true)
        #expect(resolve(.input, app: true, images: true) == nil)
        #expect(resolve(.image, images: true) == true)
        #expect(resolve(.image, app: true, input: true) == nil)
        // A container is never masked by a property; its children read the inherited properties.
        #expect(resolve(.other, app: true, input: true, images: true) == nil)
    }

    @Test func `View kinds follow the UIKit class`() {
        #expect(ViewDetails.maskKind(for: UILabel()) == .text)
        #expect(ViewDetails.maskKind(for: UIButton()) == .text)
        #expect(ViewDetails.maskKind(for: UITextField()) == .input)
        #expect(ViewDetails.maskKind(for: UITextView()) == .input)
        #expect(ViewDetails.maskKind(for: UISearchBar()) == .input)
        #expect(ViewDetails.maskKind(for: UIDatePicker()) == .input)
        #expect(ViewDetails.maskKind(for: UISwitch()) == .input)
        #expect(ViewDetails.maskKind(for: UIImageView()) == .image)
        #expect(ViewDetails.maskKind(for: UIView()) == .other)
        #expect(ViewDetails.maskKind(for: UIStackView()) == .other)
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

    @Test func `Class rules match plain and module-prefixed names exactly`() {
        #expect(ViewDetails.classNameMatches("UILabel", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("UILabel", in: ["UITextField"]))
        #expect(!ViewDetails.classNameMatches("", in: [""]))
        #expect(!ViewDetails.classNameMatches("UILabel", in: nil))
        // Module prefix is accepted because String(describing:) never includes the module.
        #expect(ViewDetails.classNameMatches("CardView", in: ["MyApp.CardView"]))
        // A module-qualified view name (NSStringFromClass) matches the registered qualified name.
        #expect(ViewDetails.classNameMatches("MyApp.CardView", in: ["MyApp.CardView"]))
        // Generics match as written; the module before the generic list is dropped, not the one inside it.
        #expect(ViewDetails.classNameMatches("Box<Item>", in: ["Box<Item>"]))
        #expect(ViewDetails.classNameMatches("Box<Item>", in: ["MyApp.Box<Item>"]))
        #expect(ViewDetails.classNameMatches("Box<MyApp.Item>", in: ["Box<MyApp.Item>"]))
        #expect(!ViewDetails.classNameMatches("Box<Item>", in: ["Box<MyApp.Item>"]))
        // Nested types: String(describing:) gives the innermost name.
        #expect(ViewDetails.classNameMatches("Inner", in: ["Outer.Inner"]))
    }

    @Test func `Class rules do not match subclasses or partial names`() {
        #expect(!ViewDetails.classNameMatches("MyLabel", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("UILabelSubclass", in: ["UILabel"]))
        #expect(!ViewDetails.classNameMatches("Label", in: ["UILabel"]))
    }

    // Sanitizing a name (as done for CSS ids) is lossy; class rules must not inherit that, or an
    // unmask rule could match a class the app never listed.
    @Test func `Class rules do not collide the way sanitized names do`() {
        let long = "ThisIsAnExtremelyLongViewClassNameThatGoesWellBeyondFiftyCharacters"
        let other = String(long.prefix(50)) + "Different"
        #expect(ViewDetails.classNameMatches(long, in: [long]))
        #expect(!ViewDetails.classNameMatches(other, in: [long]))
        #expect(!ViewDetails.classNameMatches(String(long.prefix(50)), in: [long]))
        // Punctuation is not merged: Box<A.B> and Box_A_B are different classes.
        #expect(!ViewDetails.classNameMatches("Box_A_B", in: ["Box<A.B>"]))
        // Prefixes are not rewritten: UIKit.Foo is not UIFoo, and NewRelic.Foo is not NRFoo.
        #expect(!ViewDetails.classNameMatches("UIFoo", in: ["UIKit.Foo"]))
        #expect(!ViewDetails.classNameMatches("NRFoo", in: ["NewRelic.Foo"]))
    }

    @Test func `A view is matched by its runtime class name`() {
        let candidates = ViewDetails.classNameCandidates(for: RuleTestLabel())
        #expect(candidates.contains("RuleTestLabel"))
        #expect(candidates.contains { $0.hasSuffix(".RuleTestLabel") })
        #expect(ViewDetails.classNameCandidates(for: UILabel()).contains("UILabel"))
        // The superclass is not a candidate: subclasses don't inherit their parent's rule.
        #expect(!candidates.contains("UILabel"))
    }

    // MARK: - Mask rule sets (cached lookup built from the harvest configuration)

    @Test func `Rule sets are built from the configuration lists`() {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        config.session_replay_maskedAccessibilityIdentifiers = ["secret", "private"]
        config.session_replay_unmaskedAccessibilityIdentifiers = ["public"]
        config.session_replay_maskedClassNames = ["SecureLabel", "MyApp.Card<Item>"]
        config.session_replay_unmaskedClassNames = ["UnsecureLabel"]

        let rules = ViewDetails.maskRules(for: config)
        #expect(rules.identifiersMasked == ["secret", "private"])
        #expect(rules.identifiersUnmasked == ["public"])
        // Class names are stored sanitized, with and without the module prefix.
        #expect(rules.classesMasked == ["SecureLabel", "MyApp.Card<Item>", "Card<Item>"])
        #expect(rules.classesUnmasked == ["UnsecureLabel"])
    }

    @Test func `Rule sets are empty for empty or missing lists`() {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
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

    @Test func `Rule sets ignore non-string entries and empty class names`() {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        config.session_replay_maskedAccessibilityIdentifiers = ["id", 5, NSNull()]
        config.session_replay_maskedClassNames = ["", 7, "UILabel"]

        let rules = ViewDetails.maskRules(for: config)
        #expect(rules.identifiersMasked == ["id"])
        #expect(rules.classesMasked == ["UILabel"])
        #expect(!rules.classesMasked.contains(""))
    }

    @Test func `Rule sets are built once per configuration`() {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
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

    @Test func `Rule sets are rebuilt when the configuration object changes`() {
        let first = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        first.session_replay_maskedAccessibilityIdentifiers = ["one"]
        #expect(ViewDetails.maskRules(for: first).identifiersMasked == ["one"])

        let second = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        second.session_replay_maskedAccessibilityIdentifiers = ["two"]
        #expect(ViewDetails.maskRules(for: second).identifiersMasked == ["two"])
        // Going back to the first configuration rebuilds from its own lists.
        #expect(ViewDetails.maskRules(for: first).identifiersMasked == ["one"])
    }

    @Test func `Rule sets drive the mask decision for a view`() {
        let config = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
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

    // MARK: - SwiftUI identifier override

    @Test func `An unmask identifier does not beat a masked ancestor`() {
        for tri in [true, false, nil] as [Bool?] {
            // maskApplicationText / maskUserInputText are inherited from ancestors: true means masked.
            let masked = tri == true
            for (app, input) in [(tri, nil), (nil, tri)] as [(Bool?, Bool?)] {
                let result = ViewDetails.resolveIdentifierOverride(
                    inMaskedList: false, inUnmaskedList: true, isDefaultMode: false,
                    maskApplicationText: app, maskUserInputText: input)
                #expect(result == (masked ? nil : false))
            }
        }
    }

    @Test func `Identifier override precedence`() {
        func resolve(masked: Bool, unmasked: Bool, isDefault: Bool = false,
                     app: Bool? = nil, input: Bool? = nil) -> Bool? {
            ViewDetails.resolveIdentifierOverride(inMaskedList: masked, inUnmaskedList: unmasked,
                                                  isDefaultMode: isDefault,
                                                  maskApplicationText: app, maskUserInputText: input)
        }
        #expect(resolve(masked: false, unmasked: false) == nil)
        #expect(resolve(masked: true, unmasked: false) == true)
        #expect(resolve(masked: false, unmasked: true) == false)
        // A mask rule beats an unmask rule on the same identifier, in any mode or ancestry.
        #expect(resolve(masked: true, unmasked: true) == true)
        #expect(resolve(masked: true, unmasked: true, app: true) == true)
        // Default mode ignores unmask but still honors mask.
        #expect(resolve(masked: false, unmasked: true, isDefault: true) == nil)
        #expect(resolve(masked: true, unmasked: false, isDefault: true) == true)
        // An unmask beneath a masked ancestor is dropped; an unmasked ancestor does not block it.
        #expect(resolve(masked: false, unmasked: true, app: true) == nil)
        #expect(resolve(masked: false, unmasked: true, input: true) == nil)
        #expect(resolve(masked: false, unmasked: true, app: false, input: false) == false)
    }

    // A SwiftUI view inside a UIKit hosting view follows the hosting view's resolved mask state.
    @Test func `SwiftUI content inherits the UIKit ancestor mask state`() {
        func resolve(inherited: Bool?, masked: Bool = false, unmasked: Bool = false, isDefault: Bool = false,
                     app: Bool? = nil, input: Bool? = nil) -> Bool? {
            ViewDetails.resolveIdentifierOverride(inMaskedList: masked, inUnmaskedList: unmasked,
                                                  inheritedState: inherited, isDefaultMode: isDefault,
                                                  maskApplicationText: app, maskUserInputText: input)
        }
        // A masked UIKit ancestor (nr-mask, identifier list, class list) masks the SwiftUI subtree,
        // even against an unmask identifier on the SwiftUI view.
        #expect(resolve(inherited: true) == true)
        #expect(resolve(inherited: true, unmasked: true) == true)
        // An unmasked UIKit ancestor unmasks it, unless a mask property is inherited.
        #expect(resolve(inherited: false) == false)
        #expect(resolve(inherited: false, app: true) == nil)
        #expect(resolve(inherited: false, input: true) == nil)
        // Own mask identifier beats an unmasked ancestor.
        #expect(resolve(inherited: false, masked: true) == true)
        // Default mode ignores an inherited unmask but not an inherited mask.
        #expect(resolve(inherited: false, isDefault: true) == nil)
        #expect(resolve(inherited: true, isDefault: true) == true)
        // No ancestor state and no rules: nothing explicit.
        #expect(resolve(inherited: nil) == nil)
    }

    // A child that adds an image mask keeps it under an unmasked UIKit ancestor or an unmask identifier.
    @Test func `An image mask under an unmask is not cleared`() {
        func resolve(inherited: Bool? = nil, unmasked: Bool = false, images: Bool?) -> Bool? {
            ViewDetails.resolveIdentifierOverride(inMaskedList: false, inUnmaskedList: unmasked,
                                                  inheritedState: inherited, isDefaultMode: false,
                                                  maskApplicationText: nil, maskUserInputText: nil,
                                                  maskAllImages: images)
        }
        #expect(resolve(inherited: false, images: true) == nil)
        #expect(resolve(unmasked: true, images: true) == nil)
        #expect(resolve(inherited: false, images: false) == false)
        #expect(resolve(inherited: false, images: nil) == false)
        // A masked ancestor still masks regardless.
        #expect(resolve(inherited: true, images: false) == true)
    }

    // MARK: - Hierarchy composition (parent > child > grandchild)

    private enum Mechanism: CaseIterable {
        // property sets maskApplicationText and maskUserInputText together; the other two set one.
        case none, tag, identifierList, classList, property, textProperty, inputProperty
    }

    private struct Level: CustomStringConvertible {
        var mechanism: Mechanism
        var masked: Bool
        var description: String { mechanism == .none ? "none" : "\(mechanism)-\(masked ? "M" : "U")" }
    }

    // Every mechanism. `coreLevels` leaves out the single-property mechanisms to keep the deepest
    // chains (and the captor test built on them) a manageable size.
    private var allLevels: [Level] { levels(for: Mechanism.allCases) }
    private var coreLevels: [Level] { levels(for: [.none, .tag, .identifierList, .classList, .property]) }

    private func levels(for mechanisms: [Mechanism]) -> [Level] {
        var levels = [Level(mechanism: .none, masked: false)]
        for mechanism in mechanisms where mechanism != .none {
            levels.append(Level(mechanism: mechanism, masked: true))
            levels.append(Level(mechanism: mechanism, masked: false))
        }
        return levels
    }

    // What the leaf's captor receives from the capture pipeline.
    private struct LeafResolution {
        var decision: Bool?
        var kind = ViewDetails.MaskKind.text
        var maskApplicationText: Bool?
        var maskUserInputText: Bool?
        var maskAllImages: Bool?
    }

    // Mirrors ViewDetails.init(view:) for a chain of nested views: direct properties are
    // resolved and assigned first, then the mask decision runs, and its result is stored
    // as the view's mask state for descendants.
    // Ancestors are containers; the leaf is a view of `kind`.
    private func leafResolution(chain: [Level], isDefaultMode: Bool, kind: ViewDetails.MaskKind = .text) -> LeafResolution {
        var parent: UIView?
        var result = LeafResolution()
        for (index, level) in chain.enumerated() {
            let view = UIView()
            var inputs = ViewDetails.MaskInputs(isDefaultMode: isDefaultMode)
            inputs.kind = index == chain.count - 1 ? kind : .other
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
            case .textProperty:
                view.maskApplicationText = level.masked
            case .inputProperty:
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
                                    kind: kind,
                                    maskApplicationText: overrides.maskApplicationText,
                                    maskUserInputText: overrides.maskUserInputText,
                                    maskAllImages: overrides.maskAllImages)
            parent = view
        }
        return result
    }

    // The override the leaf's captor reads for its kind.
    private func kindOverride(_ resolution: LeafResolution) -> Bool? {
        switch resolution.kind {
        case .text: return resolution.maskApplicationText
        case .input: return resolution.maskUserInputText
        case .image: return resolution.maskAllImages
        case .other: return nil
        }
    }

    // What the leaf's captor sees: the decision, else the override for its kind.
    private func leafOutcome(chain: [Level], isDefaultMode: Bool, kind: ViewDetails.MaskKind = .text) -> Bool? {
        let resolution = leafResolution(chain: chain, isDefaultMode: isDefaultMode, kind: kind)
        return resolution.decision ?? kindOverride(resolution)
    }

    // Whether a level affects a leaf of this kind: tags and lists affect every kind, a property
    // only the kinds it governs. No level sets maskAllImages.
    private func affects(_ level: Level, kind: ViewDetails.MaskKind) -> Bool {
        switch level.mechanism {
        case .none: return false
        case .tag, .identifierList, .classList: return true
        case .property: return kind == .text || kind == .input
        case .textProperty: return kind == .text
        case .inputProperty: return kind == .input
        }
    }

    // Under Custom: any masking level that affects the leaf masks it, otherwise any unmasking
    // level that affects it unmasks it, otherwise the global default applies. Under Default only
    // a direct property mask is honored (it only adds masking); everything else defers to the
    // global default, which masks.
    private func expectedLeaf(chain: [Level], isDefaultMode: Bool, kind: ViewDetails.MaskKind = .text) -> Bool? {
        let active = chain.filter { affects($0, kind: kind) }
        if isDefaultMode {
            let propertyMask = active.contains { $0.mechanism != .tag && $0.mechanism != .identifierList
                && $0.mechanism != .classList && $0.masked }
            return propertyMask ? true : nil
        }
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
                    for kind in [ViewDetails.MaskKind.text, .input, .image] {
                        count += 1
                        let actual = leafOutcome(chain: chain, isDefaultMode: isDefault, kind: kind)
                        let wanted = expectedLeaf(chain: chain, isDefaultMode: isDefault, kind: kind)
                        if actual != wanted {
                            failures.append("default=\(isDefault) \(kind) \(chain) actual=\(String(describing: actual)) expected=\(String(describing: wanted))")
                        }
                    }
                }
            }
        }
        #expect(count == 2 * 3 * (13 + 169 + 2197))
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

    // maskApplicationText masks text but not text inputs, and maskUserInputText the reverse.
    @Test func `Application text and user input masks stay in their own lane`() {
        let textM = Level(mechanism: .textProperty, masked: true)
        let inputM = Level(mechanism: .inputProperty, masked: true)
        let listU = Level(mechanism: .identifierList, masked: false)
        // maskApplicationText: true, maskUserInputText: false on the parent.
        let textMInputU = [textM, Level(mechanism: .inputProperty, masked: false)]
        #expect(leafOutcome(chain: textMInputU, isDefaultMode: false, kind: .text) == true)
        #expect(leafOutcome(chain: textMInputU, isDefaultMode: false, kind: .input) == false)
        // The reverse.
        let inputMTextU = [inputM, Level(mechanism: .textProperty, masked: false)]
        #expect(leafOutcome(chain: inputMTextU, isDefaultMode: false, kind: .text) == false)
        #expect(leafOutcome(chain: inputMTextU, isDefaultMode: false, kind: .input) == true)
        // One property set and the other left alone: the other kind falls to the global default.
        #expect(leafOutcome(chain: [textM], isDefaultMode: false, kind: .input) == nil)
        #expect(leafOutcome(chain: [inputM], isDefaultMode: false, kind: .text) == nil)
        // A masked property parent still beats an unmask rule on a child of its own kind...
        #expect(leafOutcome(chain: [textM, listU], isDefaultMode: false, kind: .text) == true)
        #expect(leafOutcome(chain: [inputM, listU], isDefaultMode: false, kind: .input) == true)
        // ...while a child of the other kind is unmasked by its own rule.
        #expect(leafOutcome(chain: [textM, listU], isDefaultMode: false, kind: .input) == false)
        #expect(leafOutcome(chain: [inputM, listU], isDefaultMode: false, kind: .text) == false)
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

    // Expected masking of each captor type, written from the documented rules: the leaf's own
    // outcome for its kind (see expectedLeaf), else the config default for that type.
    private func expectedCaptors(chain: [Level], isDefaultMode: Bool, defaults: ConfigDefaults)
        -> (label: Bool, field: Bool, image: Bool) {
        return (expectedLeaf(chain: chain, isDefaultMode: isDefaultMode, kind: .text) ?? defaults.maskApplicationText,
                expectedLeaf(chain: chain, isDefaultMode: isDefaultMode, kind: .input) ?? defaults.maskUserInputText,
                expectedLeaf(chain: chain, isDefaultMode: isDefaultMode, kind: .image) ?? defaults.maskAllImages)
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

                // Every mechanism up to two levels deep, the core mechanisms three levels deep.
                var chains: [[Level]] = []
                for depth in 1...3 {
                    let levelSet = depth == 3 ? coreLevels : allLevels
                    var level: [[Level]] = [[]]
                    for _ in 0..<depth {
                        level = level.flatMap { chain in levelSet.map { chain + [$0] } }
                    }
                    chains += level
                }
                for chain in chains {
                    count += 1
                    let text = makeDetails(leafResolution(chain: chain, isDefaultMode: isDefault, kind: .text), isDefaultMode: isDefault)
                    let input = makeDetails(leafResolution(chain: chain, isDefaultMode: isDefault, kind: .input), isDefaultMode: isDefault)
                    let image = makeDetails(leafResolution(chain: chain, isDefaultMode: isDefault, kind: .image), isDefaultMode: isDefault)
                    let actual = (UILabelThingy(view: UILabel(), viewDetails: text).isMasked,
                                  UITextFieldThingy(view: UITextField(), viewDetails: input).isMasked,
                                  ViewDetails.resolveImageIsMasked(image))
                    let wanted = expectedCaptors(chain: chain, isDefaultMode: isDefault, defaults: defaults)
                    // The text view and custom text captors call the same shared function.
                    if ViewDetails.resolveTextInputIsMasked(input, isSecureTextEntry: false) != actual.1 {
                        failures.append("shared text-input rule disagrees with text field: \(chain)")
                    }
                    // The date picker is user input and follows the text-field rule too.
                    if UIDatePickerThingy(view: UIDatePicker(), viewDetails: input).isMasked != actual.1 {
                        failures.append("date picker disagrees with text field: \(chain)")
                    }
                    if actual != wanted {
                        failures.append("default=\(isDefault) cfg=\(defaults) \(chain) actual=\(actual) expected=\(wanted)")
                    }
                }
            }
        }
        #expect(count == 2 * 8 * (13 + 169 + 729))
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

    // A TextField's own label (UITextFieldLabel) is a text input: the user-input rule governs it,
    // not maskApplicationText. A real UILabel is static text and ignores a user-input mask request,
    // while SwiftUI text, which can't be told from an input, still honors one.
    @Test func `Labels follow the rule for what they render`() {
        let configuration = NRMAMaskingTestConfiguration.install()
        defer { NRMAMaskingTestConfiguration.uninstall() }
        configuration.session_replay_mode = SessionReplayMaskingMode.custom
        configuration.session_replay_maskApplicationText = false
        configuration.session_replay_maskUserInputText = false

        let textOnly = makeDetails(LeafResolution(maskApplicationText: true, maskUserInputText: false), isDefaultMode: false)
        let inputOnly = makeDetails(LeafResolution(maskApplicationText: false, maskUserInputText: true), isDefaultMode: false)

        // Real UILabel: only maskApplicationText.
        #expect(UILabelThingy(view: UILabel(), viewDetails: textOnly).isMasked)
        #expect(!UILabelThingy(view: UILabel(), viewDetails: inputOnly).isMasked)
        // SwiftUI text: either request masks it.
        #expect(UILabelThingy.resolveIsMasked(textOnly))
        #expect(UILabelThingy.resolveIsMasked(inputOnly))
        // A TextField's label: only maskUserInputText.
        #expect(!UILabelThingy.resolveIsMasked(textOnly, isInputControlLabel: true, userInputRequestMasks: false))
        #expect(UILabelThingy.resolveIsMasked(inputOnly, isInputControlLabel: true, userInputRequestMasks: false))
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
