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
    
    struct BodyCallInfo {
        let viewType: String
        let timestamp: Date
        let callStack: [String]
        let changed: Bool
        let viewMirror: any View  // Mirror of the view itself
    }
    
    private(set) var bodyCalls: [BodyCallInfo] = []
    private let queue = DispatchQueue(label: "com.viewbodytracker")
    
    public static func track<V: View>( _ view: V) {
        let stack = Thread.callStackSymbols
        let changed = stack.contains { $0.contains("changed") }
        
       // print("Tracking body call for \(type(of: view)), changed: \(changed)")
        
        shared.bodyCalls.append(BodyCallInfo(
            viewType: String(describing: type(of: view)),
            timestamp: Date(),
            callStack: Array(stack.prefix(10)),
            changed: changed,
            viewMirror: view.body,
        ))
        
        for bodyCall in shared.bodyCalls {
            //print("- \(bodyCall.viewType) at \(bodyCall.timestamp)")
            //print("  - Call stack:")
            //bodyCall.callStack.forEach { print("    - \($0)") }
            //print("  - Changed: \(bodyCall.changed)")
            
            let mods = DeepReflector.analyze(view: bodyCall.viewMirror)
           // print(mods)
        }
    }



    
}
