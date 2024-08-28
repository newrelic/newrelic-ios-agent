//
//  SomeObservable.swift
//  NRTestApp
//
//  Created by Chris Dillard on 8/27/24.
//

import Foundation

@available(iOS 17.0, *)
@Observable class SomeObservable {
  var someProperty: Bool

  init(someProperty: Bool) {
    self.someProperty = someProperty
  }
}
