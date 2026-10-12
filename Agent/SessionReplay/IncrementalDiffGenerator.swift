//
//  IncrementalDiffGenerator.swift
//  Agent_iOS
//
//  Created by Steve Malsam on 4/14/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

import Foundation

// This generates a diff of the thingy tree based on Heckel's Algorithm

class Symbol {
    var inNew: Bool
    var indexInOld: Int?
    
    init(inNew: Bool, indexInOld: Int? = nil) {
        self.inNew = inNew
        self.indexInOld = indexInOld
    }
}

enum Entry {
    case symbol(Symbol)
    case index(Int)
}

protocol Diffable {
    var id: Int { get }
    func hasChanged(from other: Self) -> Bool
}

enum Operation {
    case Add(AddChange)
    case Remove(RemoveChange)
    case Update(UpdateChange)
    
    struct RemoveChange {
        let parentId: Int
        let id: Int
    }

    struct UpdateChange {
        let oldElement: any SessionReplayViewThingy
        let newElement: any SessionReplayViewThingy
    }

    struct AddChange {
        let parentId: Int
        let id: Int?
        let node: any SessionReplayViewThingy
    }
}

func generateDiff(old:[any SessionReplayViewThingy], new:[any SessionReplayViewThingy]) -> [Operation] {
    var table: [Int: Symbol] = [:]
    
    // Go through the arrays according to Heckel's Algorithm.
    var newArrayEntries = [Entry]()
    var oldArrayEntries = [Entry]()
    
    // Pass One: Each element of the New array is gone through, and an entry in the table made for each
    for item in new {
        let entry = Symbol(inNew: true)
        table[item.viewDetails.viewId] = entry
        newArrayEntries.append(.symbol(entry))
    }
    
    // Pass Two: Each element of the Old array is gone through, and an entry in the table made for each
    for (index, item) in old.enumerated() {
        var entry: Symbol?
        if table[item.viewDetails.viewId] == nil {
            entry = Symbol(inNew: false, indexInOld: index)
            table[item.viewDetails.viewId] = entry
        }
        else {
            table[item.viewDetails.viewId]?.indexInOld = index
            entry = table[item.viewDetails.viewId]
        }
        
        if let entry = entry {
            oldArrayEntries.append(.symbol(entry))
        }
    }
    
    // Pass Three: Use the first observation of the algorithm's paper. If any entry occurs only onece
    // in the list, then it must be the same entry, although it could have been moved. Cross reference
    // the two
    for (index, item) in newArrayEntries.enumerated() {
        if case let .symbol(entry) = item {
            if entry.inNew, let indexInOld = entry.indexInOld {
                newArrayEntries[index] = .index(indexInOld)
                oldArrayEntries[indexInOld] = .index(index)
            }
        }
    }
    
    // Pass Four: Use the second observation of the algorithm's paper. If NewArray[i] points to OldArray[j],
    // and NewArray[i+1] and OldArray[j+1] contain identical symbol table entries, then OldArray[j+1] is
    // set to line i+1 and NewArray[i+1] is set to line j+1
    
    if newArrayEntries.count > 1 {
        for i in (0 ..< (newArrayEntries.count - 1)) {
            if case let .index(j) = newArrayEntries[i],
               j + 1 < oldArrayEntries.count,
               case let .symbol(newEntry) = newArrayEntries[i + 1],
               case let .symbol(oldEntry) = oldArrayEntries[j + 1],
               newEntry === oldEntry {
                newArrayEntries[i + 1] = .index(j + 1)
                oldArrayEntries[j + 1] = .index(i + 1)
            }
        }
    }
    
    // Pass Five: Same as pass 4, but in reverse!
    if newArrayEntries.count > 1 {
        for i in (1 ..< newArrayEntries.count).reversed() {
            if case let .index(j) = newArrayEntries[i],
               j - 1 >= 0,
               case let .symbol(newEntry) = newArrayEntries[i - 1],
               case let .symbol(oldEntry) = oldArrayEntries[j - 1],
               newEntry === oldEntry {
                newArrayEntries[i - 1] = .index(j - 1)
                oldArrayEntries[j - 1] = .index(i - 1)
            }
        }
    }
    
    // Lets get those changes
    var changes = [Operation]()
    
    // Removals
    for(index, entry) in oldArrayEntries.enumerated() {
        if case .symbol = entry {
            changes.append(.Remove(Operation.RemoveChange(parentId: old[index].viewDetails.parentId ?? 0, id: old[index].viewDetails.viewId)))
        }
    }
    
    let matches: [Int?] = newArrayEntries.map {
        if case .index(let indexInOld) = $0 { return indexInOld }
        return nil
    }
    let moved = movedElements(old: old.map(DiffNode.init), new: new.map(DiffNode.init), matches: matches)
    
    // Additions and Alterations
    for(index, entry) in newArrayEntries.enumerated() {
        switch entry {
        case .symbol:
            changes.append(.Add(Operation.AddChange(parentId: new[index].viewDetails.parentId ?? 0, id: new[index].viewDetails.viewId, node: new[index])))
            
        case .index(let indexInOld):
            let newElement = new[index]
            let oldElement = old[indexInOld]
            
            if moved.contains(index) {
                changes.append(.Remove(Operation.RemoveChange(parentId: oldElement.viewDetails.parentId ?? 0, id: newElement.viewDetails.viewId)))
                changes.append(.Add(Operation.AddChange(parentId: newElement.viewDetails.parentId ?? 0, id: newElement.viewDetails.viewId, node: newElement)))
            } else if type(of: newElement) == type(of: oldElement) {
                if newElement.hashValue != oldElement.hashValue {
                    changes.append(.Update(Operation.UpdateChange(oldElement: oldElement, newElement: newElement)))
                }
            }
        }
    }
    
    return changes
}

/// What moving an element costs on top of re-adding it: re-adding a WebView's `<iframe>` throws away
/// the page document attached to it in the replay, which then has to be attached again.
let webViewMoveCost = 10_000

/// What the move rule needs to know about one element of a flattened tree.
struct DiffNode {
    let id: Int
    let parentId: Int
    let isWebView: Bool
}

extension DiffNode {
    init(_ element: any SessionReplayViewThingy) {
        #if os(iOS)
        let isWebView = element is WKWebViewThingy
        #else
        let isWebView = false
        #endif
        self.init(id: element.viewDetails.viewId, parentId: element.viewDetails.parentId ?? 0, isWebView: isWebView)
    }
}

/// Indices into `new` of the matched elements that have to be removed and re-added.
///
/// An element has moved if its parent changed, or if its order among the siblings it kept changed.
/// Comparing positions in the flattened tree instead marks every element between a moved one's old
/// and new position as moved too -- and each of those is re-added with its whole subtree, including
/// any WebView, whose replayed page then has to be attached again.
///
/// Among siblings that kept their parent, the ones that stay put are the heaviest run still in their
/// old order, weighted by what moving each would cost (its subtree, plus `webViewMoveCost` for each
/// WebView in it). So when a WebView and a sibling trade places, the sibling is the one that moves.
///
/// A re-added element comes back without its children (adds carry no child nodes), so everything under
/// a moved element is re-added with it.
///
/// - Parameters:
///   - old, new: the flattened trees, in pre-order (a parent before everything under it)
///   - matches: for each element of `new`, the index of the same element in `old`, or nil if it is new
func movedElements(old: [DiffNode], new: [DiffNode], matches: [Int?]) -> Set<Int> {
    var newIndexById = [Int: Int](minimumCapacity: new.count)
    for (index, element) in new.enumerated() where newIndexById[element.id] == nil {
        newIndexById[element.id] = index
    }
    func parentIndex(of index: Int) -> Int? {
        guard let parent = newIndexById[new[index].parentId], parent < index else {
            return nil
        }
        return parent
    }

    var cost = Array(repeating: 1, count: new.count)
    for index in new.indices.reversed() {
        if new[index].isWebView {
            cost[index] += webViewMoveCost
        }
        if let parent = parentIndex(of: index) {
            cost[parent] += cost[index]
        }
    }

    var moved = Set<Int>()
    var keptSiblings = [Int: [(newIndex: Int, oldIndex: Int)]]()
    for (index, match) in matches.enumerated() {
        guard let indexInOld = match else { continue }
        if new[index].parentId != old[indexInOld].parentId {
            moved.insert(index)
        } else {
            keptSiblings[new[index].parentId, default: []].append((index, indexInOld))
        }
    }
    for siblings in keptSiblings.values where siblings.count > 1 {
        let staying = heaviestIncreasingSubsequence(siblings.map { $0.oldIndex }, weights: siblings.map { cost[$0.newIndex] })
        for (position, sibling) in siblings.enumerated() where !staying.contains(position) {
            moved.insert(sibling.newIndex)
        }
    }

    for index in new.indices where matches[index] != nil && !moved.contains(index) {
        if let parent = parentIndex(of: index), moved.contains(parent) {
            moved.insert(index)
        }
    }
    return moved
}

/// Positions of the heaviest strictly increasing subsequence of `values`. Exact for typical sibling
/// counts; past `exactLimit` it falls back to the longest one, ignoring weights, to stay O(n log n).
func heaviestIncreasingSubsequence(_ values: [Int], weights: [Int], exactLimit: Int = 256) -> Set<Int> {
    let count = values.count
    guard count > 1 else { return Set(0..<count) }
    guard count <= exactLimit else { return longestIncreasingSubsequence(values) }
    
    var best = weights
    var previous = Array(repeating: -1, count: count)
    for i in 1..<count {
        for j in 0..<i where values[j] < values[i] && best[j] + weights[i] > best[i] {
            best[i] = best[j] + weights[i]
            previous[i] = j
        }
    }
    var index = 0
    for i in 1..<count where best[i] > best[index] {
        index = i
    }
    var staying = Set<Int>()
    while index >= 0 {
        staying.insert(index)
        index = previous[index]
    }
    return staying
}

/// Positions of a longest strictly increasing subsequence of `values` (patience sorting).
func longestIncreasingSubsequence(_ values: [Int]) -> Set<Int> {
    var tails = [Int]()
    var previous = Array(repeating: -1, count: values.count)
    for i in values.indices {
        var low = 0
        var high = tails.count
        while low < high {
            let mid = (low + high) / 2
            if values[tails[mid]] < values[i] { low = mid + 1 } else { high = mid }
        }
        if low > 0 {
            previous[i] = tails[low - 1]
        }
        if low == tails.count { tails.append(i) } else { tails[low] = i }
    }
    var staying = Set<Int>()
    var index = tails.last ?? -1
    while index >= 0 {
        staying.insert(index)
        index = previous[index]
    }
    return staying
}
    
//         For nodes that have not been added/removed, we should get the difference they've got as a dictionary (that can be turned into JSON
//           {
//        "type": 3,
//        "data": {
//          "source": 0,
//          "texts": [],
//          "attributes": [
//            {
//              "id": 16,
//              "attributes": {
//                "style": {
//                  "background-color": "blue",
//                  "left": "0.00px",
//                  "top": "200px"
//                }
//              }
//            }
//          ],
//          "removes": [],
//          "adds": []
//        },
//        "timestamp": 1744394410366.966
//      },
    
    // We can record changes in the Thingies, that are not complete replacements, as attribute changes. There is also a TextUpdate, which can be used just for text changes.
    // We could have each Thingy return an array of changes. If it's just a visual change, it would be a one thing array. If it's thing like a UILabel, and it could have both visual
    // and text changes, it could return two: an attribute change, and a text change.
    
//        {
//            "parentId": 66,
//            "nextId": 70,
//            "node": {
//                "type": 2,
//                "tagName": "div",
//                "attributes": {
//                    "role": "separator",
//                    "aria-orientation": "horizontal",
//                    "class": "-mx-1 my-1 h-px bg-muted"
//                },
//                "childNodes": [],
//                "id": 71
//            }
//        },
    
    // Adds are a list of nodes to insert. It doesn't appear as if any of the inserted nodes have any child nodes, however, nodes listed after can say they are a parent node of
    // one listed here. It is a regular node like is presented in the full snapshot. However, it should have the id of it's parent. This is something that should be added
    // to the Thingy, or the ViewDetails.
    
//        "removes": [
//            {
//                "parentId": 100,
//                "id": 173
//            },
//            {
//                "parentId": 100,
//                "id": 171
//            },
//            {
//                "parentId": 100,
//                "id": 172
//            },
//            {
//                "parentId": 79,
//                "id": 169
//            }
//        ]
    
    // Removes are a very simple list of the node to be removed, and it's parent.
    
//        "texts": [
//            {
//                "id": 146,
//                "value": "🛑 Stop recording"
//            }
//        ]
    
    // Texts are the id of the text node, and the content to change it to.
