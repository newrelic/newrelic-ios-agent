//
//  RandomString.swift
//  Agent
//
//  Created by Chris Dillard on 10/2/25.
//  Copyright © 2025 New Relic. All rights reserved.
//

func randomString() -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let name = String((0..<6).map{ _ in letters.randomElement()! })
    return name
}
