//
//  DogInfoCellTableViewCell.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 7/26/24.
//

import UIKit

class DogInfoCellTableViewCell: UITableViewCell {
    static let reuseID = "DogInfoCell"

    
    @IBOutlet weak var borderView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var shortDescLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var dogImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func set(dog: DogModel) {
        nameLabel.text = dog.title
        shortDescLabel.text = dog.shortDescription
        priceLabel.text = dog.price
        dogImage.image = dog.image
    }

}
