class WebViewReplayTests: XCTestCase {
        XCTAssertEqual(array.map { $0["type"] as? Int }, [4, 2, 3])
    }

    func testMergeWithoutWebViewEventsMatchesNativeMerge() {
        let manager = makeManager()
        let frames = [makeMetaAnyRRWebEvent(timestamp: 1000), makeFullSnapshotAnyRRWebEvent(timestamp: 1000)]
        let touches = [makeTouchAnyRRWebEvent(timestamp: 999)]

        let chunk = manager.mergeReplayChunk(frames: frames, touches: touches, webViewEvents: [])
        let native = manager.mergeAndSortReplayEvents(frames: frames, touches: touches)

        XCTAssertEqual(chunk.map { $0.timestamp }, native.map { $0.base.timestamp })
    }
}

/// Moves in the native diff: a WebView's `<iframe>` re-added by a mutation loses the page document
/// attached to it in the replay, so the diff must not re-add it when it did not actually move.
class NativeDiffMoveTests: XCTestCase {

    private func node(_ id: Int, parent: Int, webView: Bool = false) -> DiffNode {
        return DiffNode(id: id, parentId: parent, isWebView: webView)
    }

    /// What Heckel's matching yields for unique IDs: each new element's index in `old`, if present.
    private func matches(_ old: [DiffNode], _ new: [DiffNode]) -> [Int?] {
        var indexById = [Int: Int]()
        for (index, element) in old.enumerated() { indexById[element.id] = index }
        return new.map { indexById[$0.id] }
    }

    private func movedIds(_ old: [DiffNode], _ new: [DiffNode]) -> Set<Int> {
        return Set(movedElements(old: old, new: new, matches: matches(old, new)).map { new[$0].id })
    }

    func testViewMovingAcrossWebViewDoesNotReaddIt() {
        // Root 1 with children A(2), W(3), B(4); B moves to the front.
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true), node(4, parent: 1)]
        let new = [old[0], old[3], old[1], old[2]]

        XCTAssertEqual(movedIds(old, new), [4], "Only the view that moved is re-added")
        XCTAssertEqual(Set(legacyMovedElements(oldCount: old.count, matches: matches(old, new)).map { new[$0].id }), [4, 2, 3],
                       "The position check re-added everything it passed, the WebView included")
    }

    func testWebViewStaysWhenItTradesPlacesWithASibling() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true)]
        let new = [old[0], old[2], old[1]]

        XCTAssertEqual(movedIds(old, new), [2])
    }

    func testReparentedViewIsReaddedWithItsSubtree() {
        // B(3) with child B1(4) moves under A(2).
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1), node(4, parent: 3)]
        let new = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 2), node(4, parent: 3)]

        XCTAssertEqual(movedIds(old, new), [3, 4], "B1 kept its parent but comes back only if re-added")
    }

    func testWebViewUnderAMovedParentIsReadded() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1), node(4, parent: 3, webView: true)]
        let new = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 2), node(4, parent: 3, webView: true)]

        XCTAssertEqual(movedIds(old, new), [3, 4])
    }

    func testInsertionsAndRemovalsAloneProduceNoMoves() {
        let old = [node(1, parent: 0), node(2, parent: 1), node(3, parent: 1, webView: true), node(4, parent: 1)]
        // A new sibling ahead of the WebView, one removed after it: positions shift, order does not.
        let new = [old[0], node(5, parent: 1), old[1], old[2]]

        XCTAssertTrue(movedIds(old, new).isEmpty)
    }

    func testHeaviestIncreasingSubsequenceKeepsTheExpensiveElement() {
        // Old positions in new order: [2, 0, 1]. The longest run is {0, 1}, but position 0 is heavy.
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [100, 1, 1]), [0])
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [1, 1, 1]), [1, 2])
        XCTAssertEqual(longestIncreasingSubsequence([3, 1, 2, 0, 4]).count, 3)
        XCTAssertEqual(heaviestIncreasingSubsequence([2, 0, 1], weights: [100, 1, 1], exactLimit: 2), [1, 2],
                       "Past the limit, the longest run")
    }

    /// Replays a session of random sibling reorders, insertions and removals on a ~300-view screen
    /// with one WebView through both move rules, and reports how often each re-adds the WebView.
    func testReorderSessionReaddsWebViewLessOften() {
        var seed: UInt64 = 0x5EED
        func random(_ n: Int) -> Int {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            return Int(seed % UInt64(max(n, 1)))
        }

        var nextId = 1
        var children = [Int: [Int]]()
        var parentOf = [Int: Int]()
        func make(parent: Int?) -> Int {
            let id = nextId; nextId += 1
            children[id] = []
            if let parent = parent { children[parent]!.append(id); parentOf[id] = parent }
            return id
        }
        let root = make(parent: nil)
        let containers = (0..<3).map { _ in make(parent: root) }
        for container in containers {
            for _ in 0..<30 {
                let child = make(parent: container)
                for _ in 0..<random(5) { _ = make(parent: child) }
            }
        }
        let webViewId = make(parent: containers[1])
        children[containers[1]]!.removeLast()
        children[containers[1]]!.insert(webViewId, at: 15)

        // Same traversal as SessionReplayFrameProcessor.flattenTree: a stack, so the last subview first.
        func flatten() -> [DiffNode] {
            var out = [DiffNode]()
            var stack = [root]
            while let id = stack.popLast() {
                out.append(node(id, parent: parentOf[id] ?? 0, webView: id == webViewId))
                stack.append(contentsOf: children[id]!)
            }
            return out
        }

        var legacyWebView = 0, fixedWebView = 0, legacyViews = 0, fixedViews = 0
        var legacyTime = 0.0, fixedTime = 0.0
        let frames = 600
        var previous = flatten()
        for _ in 0..<frames {
            // One change per frame: a reorder within a container (bring to front, reshuffle) twice as
            // often as a view added or removed. Reorders never pick the WebView itself.
            let container = containers[random(containers.count)]
            var siblings = children[container]!
            if random(3) < 2 {
                let candidates = siblings.indices.filter { siblings[$0] != webViewId }
                let moving = siblings.remove(at: candidates[random(candidates.count)])
                siblings.insert(moving, at: random(siblings.count + 1))
            } else if random(2) == 0 {
                let id = nextId; nextId += 1
                children[id] = []; parentOf[id] = container
                siblings.insert(id, at: random(siblings.count + 1))
            } else {
                let leaves = siblings.filter { $0 != webViewId && children[$0]!.isEmpty }
                if !leaves.isEmpty {
                    let gone = leaves[random(leaves.count)]
                    siblings.removeAll { $0 == gone }
                }
            }
            children[container] = siblings
            let current = flatten()
            let matched = matches(previous, current)

            var start = Date()
            let legacy = legacyMovedElements(oldCount: previous.count, matches: matched)
            legacyTime += Date().timeIntervalSince(start)
            start = Date()
            let fixed = movedElements(old: previous, new: current, matches: matched)
            fixedTime += Date().timeIntervalSince(start)

            legacyViews += legacy.count
            fixedViews += fixed.count
            if legacy.contains(where: { current[$0].id == webViewId }) { legacyWebView += 1 }
            if fixed.contains(where: { current[$0].id == webViewId }) { fixedWebView += 1 }
            previous = current
        }

        print("[NR-DIFF] \(frames) frames, \(previous.count) views: frames re-adding the WebView legacy=\(legacyWebView) fixed=\(fixedWebView); " +
              "views re-added legacy=\(legacyViews) fixed=\(fixedViews); " +
              String(format: "move rule ms/frame legacy=%.3f fixed=%.3f", legacyTime * 1000 / Double(frames), fixedTime * 1000 / Double(frames)))
        XCTAssertEqual(fixedWebView, 0, "Reorders around the WebView never move it")
        XCTAssertLessThan(fixedViews, legacyViews)
    }
}

/// The move rule as it was: an element moved if its position in the flattened tree, corrected for
/// insertions and removals ahead of it, changed. Verbatim from the pre-fix generateDiff.
private func legacyMovedElements(oldCount: Int, matches: [Int?]) -> Set<Int> {
    var oldMatched = Array(repeating: false, count: oldCount)
    for case let indexInOld? in matches { oldMatched[indexInOld] = true }
    var deleteOffsets = Array(repeating: 0, count: oldCount)
    var runningOffset = 0
    for index in 0..<oldCount {
        deleteOffsets[index] = runningOffset
        if !oldMatched[index] { runningOffset += 1 }
    }
    runningOffset = 0
    var moved = Set<Int>()
    for (index, match) in matches.enumerated() {
        guard let indexInOld = match else {
            runningOffset += 1
            continue
        }
        if (indexInOld - deleteOffsets[indexInOld] + runningOffset) != index {
            moved.insert(index)
        }
    }
    return moved
}
