//
//  DogModel.swift
//  SessionReplayTest
//
//  Created by Steve Malsam on 7/24/24.
//

import UIKit
import Foundation


struct DogModel {
    let title : String
    let shortDescription : String
    let price: String
    let image : UIImage?
}


func getMardiGrasDog() -> DogModel {
    return DogModel(title: "Mardi Gras Dog", shortDescription: "This dog is always up for a party", price: "$1 million dollars", image: UIImage(named: "mardi gras dog"))
}

func getEeyoreDog() -> DogModel{
    return DogModel(title: "Eeyore Style Dog", shortDescription: "This dog will always give you puppy dog eyes", price: "Free to a good home", image: UIImage(named: "eeyore dog"))
}

func generateDogList() -> [DogModel] {
    return [getMardiGrasDog(), getEeyoreDog()]
}
