//
//  Variable.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import Foundation

class Variable<Value> {
    var value: Value {
        didSet {
            DispatchQueue.main.async {
                self.onUpdate?(self.value)
            }
        }
    }
    
    var onUpdate: ((Value) -> Void)?
    
    init(_ value: Value, onUpdate: ((Value) -> Void)? = nil) {
        self.value = value
        self.onUpdate = onUpdate
    }
}
