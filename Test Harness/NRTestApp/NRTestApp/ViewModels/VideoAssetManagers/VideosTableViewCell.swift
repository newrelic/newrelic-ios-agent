//
//  VideosTableViewCell.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import UIKit

class VideosTableViewCell: UITableViewCell {
    
    static let reuseIdentifier = "VideosTableViewCellIdentifier"

    var asset: VideoAsset? {
        didSet {
            if let asset = asset {
                self.textLabel?.text = asset.name
            }
        }
    }
}
