//
//  VideoViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import AVKit

class VideoViewController: AVPlayerViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let player = AVPlayer(url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")!)
        self.player = player
        self.player?.play()
    }
}
