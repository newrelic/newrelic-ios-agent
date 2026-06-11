//
//  ApodURL.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import Foundation

struct ApodURL {
    
    let url: String
    
    init(date:String) {
        let fetchedKey = plistHelper.objectFor(key: "NASAAPIKey", plist: "NASAAPI-Info") as? String ?? ""
        let apiKey = fetchedKey.isEmpty ? "DEMO_KEY" : fetchedKey
        self.url = "https://api.nasa.gov/planetary/apod?api_key=\(apiKey)&date=\(date)"
    }
}

struct ApodURLBroke {

    let url: String

    init(date:String) {
        self.url = "https://api.nasa.gov/planetary/apod?date=\(date)"
    }
}
