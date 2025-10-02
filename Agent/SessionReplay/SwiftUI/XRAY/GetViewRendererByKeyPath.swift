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
        return next
    }
}
