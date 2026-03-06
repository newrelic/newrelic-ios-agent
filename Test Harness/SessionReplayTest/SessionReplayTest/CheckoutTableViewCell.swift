//
//  CheckoutTableViewCell.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 11/21/24.
//

import UIKit

class CheckoutTableViewCell: UITableViewCell {
    static let reuseID = "checkoutItem"

    @IBOutlet weak var dogNameLabel: UILabel!
    @IBOutlet weak var cartQuantityLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func set(dog: DogModel) {
        dogNameLabel.text = dog.title
        cartQuantityLabel.text = "1"
        priceLabel.text = dog.price
    }

}
