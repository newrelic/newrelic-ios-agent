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
        self.url = "https://api.nasa.gov/planetary/apod?api_key=L9fVBfet3ldADKiogWO5EZyOOOHczSE45du4FhXT&date=\(date)"
    }
}
