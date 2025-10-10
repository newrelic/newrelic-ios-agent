//
//  ViewBodyTracker.swift
//  NRTestApp
//
//  Created by Chris Dillard on 10/9/25.
//

import Foundation
import ObjectiveC
import SwiftUI

@available(iOS 13.0, tvOS 13.0, *)
public class ViewBodyTracker {
    static let shared = ViewBodyTracker()
    
    private(set) var bodyCallsByView: [String: BodyCallInfo] = [:]
    
    public struct BodyCallInfo {
        let viewType: String
        let timestamp: Date
        let callStack: [String]
        let changed: Bool
        let viewMirror: any View
    }
    
    private init() {}
    
    public static func track<V: View>( _ view: V) {
        
        Task{
            await MainActor.run {
                let viewBody = view.body
                let fullyQualifiedNameOne = String(reflecting: type(of: view))

                let fullyQualifiedName = String(reflecting: type(of: viewBody))
                let stack = Thread.callStackSymbols
                let changed = stack.contains { $0.contains("changed")  || $0.contains("run10resultType4body")}
                
                    let info = BodyCallInfo(
                        viewType: fullyQualifiedName,
                        timestamp: Date(),
                        callStack: Array(stack.prefix(10)),
                        changed: changed,
                        viewMirror: viewBody,
                    )
                    
                shared.bodyCallsByView[fullyQualifiedName] = (info)
                shared.bodyCallsByView[fullyQualifiedNameOne] = (info)
                
                //print("added fullyQualifiedName: \(fullyQualifiedName)")
            }
        }
    }

    
    func getCall(for viewType: String) -> BodyCallInfo? {
            bodyCallsByView[viewType]
    }
    
    func clear() {
            self.bodyCallsByView.removeAll()
    }
    
}
