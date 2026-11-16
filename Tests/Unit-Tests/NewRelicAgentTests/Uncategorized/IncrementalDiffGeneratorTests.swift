import Foundation
import Testing
import UIKit

@MainActor
struct IncrementalDiffGeneratorTests {
    func makeViewDetails(blockView: Bool?) -> ViewDetails {
        var details = ViewDetails(
            frame: .zero,
            clip: .zero,
            backgroundColor: .clear,
            alpha: 1.0,
            isHidden: false,
            viewName: "UILabel",
            parentId: 3,
            cornerRadius: 0,
            borderWidth: 0,
            borderColor: nil,
            viewId: 7,
            view: nil,
            maskApplicationText: false,
            maskUserInputText: nil,
            maskAllImages: nil,
            maskAllUserTouches: nil,
            blockView: blockView,
            sessionReplayIdentifier: nil,
            isDefaultMaskingMode: false
        )
        details.isMasked = false
        return details
    }

    func labelThingy(_ text: String) -> UILabelThingy {
        let label = UILabel()
        label.text = text
        return UILabelThingy(view: label, viewDetails: makeViewDetails(blockView: nil))
    }

    @Test func `View whose recorder type changes is replaced`() {
        // A label that becomes blocked is recorded as a plain view on the next frame.
        let old: [any SessionReplayViewThingy] = [labelThingy("secret")]
        let new: [any SessionReplayViewThingy] = [UIViewThingy(viewDetails: makeViewDetails(blockView: true))]

        let operations = generateDiff(old: old, new: new)

        guard operations.count == 2,
              case .Remove(let removal) = operations[0],
              case .Add(let addition) = operations[1] else {
            Issue.record("Expected a remove followed by an add, got \(operations)")
            return
        }
        #expect(removal.id == 7)
        #expect(addition.id == 7)
        #expect(addition.node is UIViewThingy)
    }

    @Test func `View with the same recorder type is updated in place`() {
        let operations = generateDiff(old: [labelThingy("before")], new: [labelThingy("after")])

        guard operations.count == 1, case .Update = operations[0] else {
            Issue.record("Expected a single update, got \(operations)")
            return
        }
    }
}
