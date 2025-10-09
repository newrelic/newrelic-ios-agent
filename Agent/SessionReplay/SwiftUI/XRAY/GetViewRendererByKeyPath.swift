//
//  GetViewRendererByKeyPath.swift
//  Agent
//
//  Created by Chris Dillard on 9/26/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

func getViewRenderer(from subject: AnyObject, keyPath: [String]) -> AnyObject? {
    keyPath.reduce(Optional(subject) as AnyObject?) { current, key in
        guard let object = current,
              let ivar = key.withCString({ class_getInstanceVariable(type(of: object), $0) }),
              let next = object_getIvar(object, ivar) as AnyObject? else {
            return nil
        }
        
        
        /*
         object    SwiftUI._UIHostingView<NRTestApp.SwiftUIContentView>    0x0000000117105260

         
         First time we hit <SwiftUI._UIHostingView<NRTestApp.SwiftUIContentView>
         Then we hit       <UIKit.UIHostingViewBase: 0x101d34830>
         
         /
         Printing description of some.viewGraph:
         <ViewGraphHost: 0x600003550160>
         /
         <SwiftUI.GraphHost>
         
         */
        
        // if type of next is viewController    SwiftUI.UIHostingController<NRTestApp.SwiftUIContentView>?    0x000000010401c000 lets take a deeper look
        return next
    }
}
