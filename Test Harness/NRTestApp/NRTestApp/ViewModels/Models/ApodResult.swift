//
//  ApodResult.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import Foundation

class ApodResult : Decodable {
    var date: String
    var title: String
    var explanation: String
    var url: String
    var media_type: String

}
