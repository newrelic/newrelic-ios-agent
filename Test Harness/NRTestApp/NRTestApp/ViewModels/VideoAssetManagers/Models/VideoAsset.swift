//
//  VideoAsset.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import AVFoundation

class VideoAsset {
    
    let name: String
    var urlAsset: AVURLAsset
    
    
    init(name: String, urlAsset: AVURLAsset) {
        self.name = name
        self.urlAsset = urlAsset
    }

    enum DownloadState: String {
        case notDownloaded
        case downloading
        case downloaded
    }
}
