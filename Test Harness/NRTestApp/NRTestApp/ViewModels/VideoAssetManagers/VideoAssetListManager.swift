//
//  VideoAssetListManager.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import AVKit

class VideoAssetListManager {
        
    static let shared: VideoAssetListManager = VideoAssetListManager()
    
    var assets = [VideoAsset(name: "Basic Video", urlAsset: AVURLAsset(url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!)), VideoAsset(name: "Advanced Video", urlAsset: AVURLAsset(url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!))]
    
    private var assetDictionary = [String: VideoAsset]()
        
    private init() {
        
        for asset in assets {
            assetDictionary[asset.name] = asset
        }
    }
    
    func asset(withName name: String) -> VideoAsset {
        guard let asset = assetDictionary[name] else {
            fatalError("Could not find `VideoAsset` with name: \(name)")
        }
        
        return asset
    }
}
