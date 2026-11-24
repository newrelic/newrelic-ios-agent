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

    func viewThingy(id: Int, parentId: Int?) -> UIViewThingy {
        UIViewThingy(viewDetails: ViewDetails(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            clip: CGRect(x: 0, y: 0, width: 400, height: 800),
            backgroundColor: .white,
            alpha: 1.0,
            isHidden: false,
            viewName: "UIView",
            parentId: parentId ?? 0,
            cornerRadius: 0,
            borderWidth: 0,
            viewId: id,
            maskApplicationText: nil,
            maskUserInputText: nil,
            maskAllImages: nil,
            maskAllUserTouches: nil,
            blockView: nil,
            sessionReplayIdentifier: nil,
            isDefaultMaskingMode: false
        ))
    }

    func removedIds(_ operations: [Operation]) -> [Int] {
        operations.compactMap { if case .Remove(let r) = $0 { return r.id } else { return nil } }
    }

    func addedIds(_ operations: [Operation]) -> [Int] {
        operations.compactMap { if case .Add(let a) = $0 { return a.id } else { return nil } }
    }

    @Test func `Unchanged tree produces no operations`() {
        let tree: [any SessionReplayViewThingy] = [viewThingy(id: 1, parentId: nil), viewThingy(id: 2, parentId: 1), viewThingy(id: 3, parentId: 2)]

        #expect(generateDiff(old: tree, new: tree).isEmpty)
    }

    // A navigation push: UIKit animates the incoming screen (5) inside a transition
    // container (4), then moves it straight under the wrapper (2) and drops the container.
    // The screen keeps its id and its position in the flattened tree.
    @Test func `View moved out of a removed container is re-added with its subtree`() {
        let old: [any SessionReplayViewThingy] = [
            viewThingy(id: 1, parentId: nil),
            viewThingy(id: 2, parentId: 1),
            viewThingy(id: 4, parentId: 2),
            viewThingy(id: 5, parentId: 4),
            viewThingy(id: 6, parentId: 5),
            viewThingy(id: 7, parentId: 6),
        ]
        let new: [any SessionReplayViewThingy] = [
            viewThingy(id: 1, parentId: nil),
            viewThingy(id: 2, parentId: 1),
            viewThingy(id: 5, parentId: 2),
            viewThingy(id: 6, parentId: 5),
            viewThingy(id: 7, parentId: 6),
        ]

        let operations = generateDiff(old: old, new: new)

        // Removing 4 takes 5's whole subtree out of the replay, so 5, 6 and 7 all come back.
        #expect(removedIds(operations) == [4])
        #expect(addedIds(operations) == [5, 6, 7])
        guard case .Add(let screen) = operations.first(where: { if case .Add = $0 { return true } else { return false } }) else {
            Issue.record("Expected an add, got \(operations)")
            return
        }
        #expect(screen.parentId == 2)
    }

    // React Native Fabric recycles a view (3) from one container into another between frames.
    @Test func `View reparented to a surviving container is moved`() {
        let old: [any SessionReplayViewThingy] = [
            viewThingy(id: 1, parentId: nil),
            viewThingy(id: 2, parentId: 1),
            viewThingy(id: 3, parentId: 2),
            viewThingy(id: 8, parentId: 1),
        ]
        let new: [any SessionReplayViewThingy] = [
            viewThingy(id: 1, parentId: nil),
            viewThingy(id: 2, parentId: 1),
            viewThingy(id: 3, parentId: 8),
            viewThingy(id: 8, parentId: 1),
        ]

        let operations = generateDiff(old: old, new: new)

        // 2 stays in the replay, so 3 has to be taken out of it before it is added under 8.
        guard operations.count == 2,
              case .Remove(let removal) = operations[0],
              case .Add(let addition) = operations[1] else {
            Issue.record("Expected a remove followed by an add, got \(operations)")
            return
        }
        #expect(removal.id == 3)
        #expect(removal.parentId == 2)
        #expect(addition.id == 3)
        #expect(addition.parentId == 8)
    }

    // MARK: Stylesheet-only CSS

    func borderedThingy(x: CGFloat, bitmap: Int) -> UIViewThingy {
        var details = viewThingy(id: 2, parentId: 1).viewDetails
        details.frame.origin.x = x
        let image = ReactNativeBorderStyle.BorderImage(dataURL: "data:image/png;base64,bitmap\(bitmap)", fingerprint: bitmap,
                                                       slice: [3, 3, 3, 3], widths: [1, 1, 1, 1], isResizable: true)
        details.reactNativeBorder = ReactNativeBorderStyle(borderImage: image)
        return UIViewThingy(viewDetails: details)
    }

    @Test func `Border bitmap is sent in a stylesheet rule only when it changes`() throws {
        let processor = SessionReplayFrameProcessor()
        func json(x: CGFloat, bitmap: Int, at seconds: TimeInterval) throws -> String {
            let root = viewThingy(id: 1, parentId: nil)
            root.subviews = [borderedThingy(x: x, bitmap: bitmap)]
            let frame = SessionReplayFrame(date: Date(timeIntervalSince1970: seconds), views: root, rootViewControllerId: nil,
                                           rootSwiftUIViewId: nil, size: CGSize(width: 400, height: 800),
                                           layoutContainerViewCount: 0, navigationStackDepth: 0)
            let event = try #require(processor.processFrame(frame))
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            return String(decoding: try encoder.encode(event), as: UTF8.self)
        }

        let fullSnapshot = try json(x: 0, bitmap: 1, at: 1)
        let moved = try json(x: 10, bitmap: 1, at: 2)
        let redrawn = try json(x: 10, bitmap: 2, at: 3)

        #expect(fullSnapshot.contains("#UIView-2 { border-image: url('data:image/png;base64,bitmap1')"))
        #expect(moved.contains("left: 10.00px"))
        #expect(!moved.contains("bitmap1"))
        #expect(redrawn.contains("#UIView-2 { border-image: url('data:image/png;base64,bitmap2')"))
    }
}
